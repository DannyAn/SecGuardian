---
name: secguard-go-sql-injection
description: "Detect SQL injection via db.Query/Exec with fmt.Sprintf or string concatenation — parameterized queries bypassed"
language: go
topic: [web, database]
skill_id: go.injection.sql
signal_filter: go.injection.sql*
signal_source: call_sites[category="*"]
severity: critical
cwe: [CWE-89]
trigger_functions: [db.Query, db.Exec, db.QueryRow, sqlx.In, GORM.Raw, GORM.Exec]
---

# sql_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.injection.sql` |
| trigger_functions | `db.Query`, `db.Exec`, `db.QueryRow`, `sqlx.In`, GORM `Raw()`, GORM `Exec()` |
| 默认严重度 | Critical |
| CWE | CWE-89 (SQL Injection) |
| Guard-rule | `web-sql-injection` |

## Scenario 1: fmt.Sprintf / 字符串拼接构造 SQL

### 威胁定义

Go database/sql 标准库支持参数化查询（`$1`, `$2` 占位符），但如果使用 `fmt.Sprintf` 或字符串拼接将用户输入直接嵌入 SQL 语句，攻击者可通过输入 `' OR '1'='1` 等注入字符串逃逸查询结构，导致数据泄露、篡改或删除。

**核心原则：永远使用参数化查询，不使用字符串拼接构建 SQL。**

### 检测逻辑

```go
// 脆弱 — fmt.Sprintf 拼接 SQL
rows, err := db.Query(fmt.Sprintf("SELECT * FROM users WHERE id='%s'", userInput))

// 脆弱 — 字符串拼接
query := "SELECT * FROM users WHERE email=" + userInput
rows, err := db.Query(query)

// 安全 — 参数化查询
rows, err := db.Query("SELECT * FROM users WHERE id=$1", userInput)

// 安全 — sqlx 命名参数
rows, err := db.NamedQuery("SELECT * FROM users WHERE id=:id", map[string]interface{}{"id": userInput})
```

### 检测模式

```
# MATCH（触发检测）
→ db.Query/Exec/QueryRow 参数中包含 fmt.Sprintf 或 + 拼接
→ db.Query("SELECT ... " + var) — 字符串拼接
→ GORM.Raw(fmt.Sprintf(...)) / GORM.Exec(fmt.Sprintf(...))
→ sqlx.In 中使用了动态列名（非白名单）

# EXCLUDE（不报告）
→ db.Query(query, args...) — 标准参数化查询
→ GORM 链式调用（Where, Find, First 等）
→ db.Exec("INSERT INTO t VALUES($1, $2)", v1, v2)
```

### 修复指引

1. 始终使用 `db.Query(query, args...)` 占位符语法
2. 动态 ORDER BY、列名必须通过白名单校验
3. GORM 中优先使用链式调用而非 Raw SQL

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | db.Query/Exec 调用点及参数构造过程 |
| judgment_rationale | MUST | 用户输入是否经过转义；是否使用参数化 |
| data_flow_path | SHOULD | 用户输入 → SQL 语句的完整路径 |
