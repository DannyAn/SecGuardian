---
name: secguard-java-sql-injection
description: "检测 Java SQL 注入漏洞 — Statement.execute / MyBatis ${} / JPA nativeQuery 拼接用户输入"
language: java
topic: [web, injection, database]
skill_id: java.sql-injection.dynamic
signal_source: call_sites[cat="sql"]
severity: critical
cwe: CWE-89
trigger_functions: [executeQuery, executeUpdate, createStatement, prepareStatement, createNativeQuery, Select, setString]
---

# sql_injection 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.sql-injection.dynamic` | `call_sites[cat="sql"]` | `executeQuery`, `executeUpdate`, `createStatement`, `prepareStatement`, `createNativeQuery` | Critical | CWE-89 |

## Scenario 1: SQL 拼接注入

### 威胁定义
攻击者通过构造恶意输入拼接 SQL 语句。Java 生态中 Spring JDBC 的 `Statement`、MyBatis 的 `${}` 替换、JPA/Hibernate 的 `createNativeQuery` 拼接均会产生注入。ORDER BY / GROUP BY 等标识符子句无法参数化。

### 检测逻辑
```java
// BAD: Statement + 字符串拼接
String sql = "SELECT * FROM users WHERE name = '" + username + "'";
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery(sql);

// BAD: PreparedStatement SQL 模板拼接
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = '" + username + "'");

// BAD: JPA nativeQuery 拼接
Query q = entityManager.createNativeQuery("SELECT * FROM users WHERE name = '" + username + "'");

// BAD: MyBatis ${}
@Select("SELECT * FROM users WHERE name = '${username}'")
User findUser(String username);

// GOOD: PreparedStatement 参数化
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = ?");
ps.setString(1, username);

// GOOD: MyBatis #{}
@Select("SELECT * FROM users WHERE name = #{username}")
User findUser(String username);
```

### 检测模式
**MATCH**: `createStatement` + `executeQuery`/`executeUpdate` 且 SQL 含 `+` 或 `String.format`；`prepareStatement("...` + 变量拼接；`createNativeQuery("...` + 拼接；MyBatis `${` 非 `#{`

**EXCLUDE**: `PreparedStatement.setString|setInt` 所有变量通过 setXxx 绑定；MyBatis `#{}`；ORDER BY 有白名单校验（`Set.of()` 或 `ALLOWED.contains`）

### 修复指引
1. 首选：PreparedStatement + `?` 占位符 + `setXxx` 参数化绑定
2. 次选：MyBatis `#{}` / JPA Criteria API / Spring Data JPA `@Query` with `?1`
3. ORDER BY / 动态表名：白名单校验 + 内部枚举映射

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | SQL 字符串构造路径和执行 API 的完整代码 |
| judgment_rationale | MUST | 拼接路径分析和参数化绑定状态 |
| data_flow_path | SHOULD | 用户输入到 SQL 执行的完整路径 |
| sanitizer_analysis | SHOULD | ORM 安全 API / 白名单校验存在性 |

## 输出格式
`[Critical][CWE-89] {file}:{line} — SQL 注入（{framework}）`
