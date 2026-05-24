---
category: concept
threat_type: injection
severity: critical
cwe: CWE-89
owasp: A03:2021 - Injection
---

# SQL 注入 (SQL Injection)

攻击者通过构造恶意输入拼接 SQL 语句，导致数据库执行非预期的查询，获取、篡改或删除数据。

## 检测策略

### 核心原则
**任何用户输入不得直接拼接到 SQL 语句中。** 检测时关注以下高危模式：

1. **字符串拼接构造 SQL**
   - 搜索 SQL 关键字（SELECT/INSERT/UPDATE/DELETE）配合字符串拼接操作
   - 关注格式化字符串 + SQL 的组合

2. **动态 SQL 构建**
   - ORM 原生 SQL 接口的非参数化调用
   - 动态表名/列名/ORDER BY 未做白名单校验

3. **存储过程中的动态 SQL**
   - 存储过程内部 EXEC / EXECUTE IMMEDIATE 拼接用户输入

### 误报排除
- 参数化查询（占位符 `?` 或命名参数 `:id`）
- ORM 的安全 API（非原生 SQL 接口）
- 白名单校验后的动态表名/列名

## 修复指引

1. **首选**：使用参数化查询（PreparedStatement）
2. **次选**：ORM 安全 API
3. **不得已时**：输入校验 + 白名单过滤 + 存储过程
