# CHANGE-001: MyBatis XML Mapper SQL Injection Detection

> **Status**: Draft | **Priority**: P0 | **Estimate**: 1 session

## Problem

`EPIC-008` 的 OOP 索引提升让 Java call_site 信号基线从 0 提升到 68（生产项目），但覆盖到的全是 JDBC 直调模式（`conn.createStatement()`）。生产环境大量 Java 项目使用 **MyBatis**，SQL 写在 XML mapper 文件中，用 `${}` 做字符串替换时可导致 SQL 注入。现有索引器只扫描 `.java` 文件，完全忽略 `.xml`。

## Scope

**只做**：扫描 MyBatis XML mapper 文件（`*Mapper.xml`、`mybatis/*.xml` 等），发现 `${xxx}` 占位符，输出 `sql_injection` 信号。

**不做**：
- MyBatis `@Select` / `@SelectProvider` 注解扫描（Java 注解内 SQL 拼接——P1，后续 CHANGE）
- XML 语法校验或 SQL 解析（超出检测范围）
- MyBatis Plus 等衍生框架的特殊处理（本质同 ${} 模式）
- 跨文件追踪 Provider 类的 SQL 构建方法（P2）

## Design

### 关键信号

扫描 MyBatis XML mapper 文件，每个 `${xxx}` 实例产出一个 `sql_injection` 信号：

```json
{
  "file": "src/main/resources/mapper/UserMapper.xml",
  "line": 42,
  "pattern": "${orderBy}",
  "context": "<select id=\"findUsers\">",
  "detector": "mybatis-sql-injection"
}
```

### 索引器改动

**新增 `internal/parser/parser_xml.go`** — XML 文件扫描器：

```go
func ParseXMLMapper(filePath string) ([]XMLSignal, error)
```

检测逻辑：
1. 读取 XML 文件，定位到 MyBatis mapper namespace
2. 遍历所有 SQL 语句节点（`select`/`insert`/`update`/`delete`）
3. 在文本内容中匹配 `${...}` 模式
4. 区分 `${}`（危险）和 `#{}`（安全）
5. 对每个 `${}` 输出信号，附带所在 SQL 类型和 mapper 接口名

### 信号整合

`main.go` 中的索引管线：扫描完 Java 源码后，追加 XML mapper 扫描：

```
扫描 src/main/java/*.java       → index.json (现有流程)
扫描 src/main/resources/**/*.xml → 追加 sql_injection 信号 (新增)
```

信号被 `sql_injection` skill（已在 Java skill 集）获取，走现有 Worker 检视协议。

### 典型触发模式

```xml
<!-- ${} 在 WHERE 条件中 —— 高风险 -->
<select id="findUser">
  SELECT * FROM users WHERE username = ${username}
</select>

<!-- ${} 在 ORDER BY 中 —— 需白名单 -->
<select id="listUsers">
  SELECT * FROM users ORDER BY ${sortColumn}
</select>
```

## 验证

1. 创建 `examples/java-vuln-demo-no-answers/src/main/resources/mapper/*.xml` 测试文件
2. 索引器产出 `sql_injection` 信号数量符合预期
3. `verify-signals.sh --signal calls --lang java` 不退化
4. 生产项目（pkmhipster）扫描能发现 `${}` 使用点
