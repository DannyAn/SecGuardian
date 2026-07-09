---
name: secguard-python-sql-injection
description: "检测 SQL 注入 — cursor.execute + 字符串拼接 / f-string / % 格式化"
language: python
topic: [web, database, injection]
skill_id: python.sql-injection.execute
signal_filter: python.sql-injection.execute*
signal_source: call_sites[category="database"]
severity: high
cwe: CWE-89
trigger_functions: [cursor.execute, execute_many, sqlalchemy.text, session.execute, django.db.connection.execute, raw, extra]
---

# SQL 注入检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.sql-injection.execute` | `call_sites[cat="database"]` | `cursor.execute`, `sqlalchemy.text`, `raw` | High | CWE-89 | — |

## Scenario 1: 字符串拼接 SQL 查询

### 威胁定义
将用户输入用 `%`、`f-string`、`+` 拼接进 SQL 查询字符串，攻击者可注入恶意 SQL 操作数据库。涉及框架: SQLAlchemy Core/ORM、Django ORM、psycopg2、mysql-connector。

### 检测逻辑
```python
# BAD: % 格式化
cursor.execute("SELECT * FROM users WHERE name = '%s'" % user_input)

# BAD: f-string
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# BAD: SQLAlchemy text + f-string
session.execute(text(f"DELETE FROM logs WHERE date < {user_date}"))

# BAD: Django raw() 拼接
MyModel.objects.raw(f"SELECT * FROM myapp_mymodel WHERE name = {name}")

# GOOD: 参数化查询
cursor.execute("SELECT * FROM users WHERE name = %s", (user_input,))

# GOOD: SQLAlchemy 绑定参数
session.execute(text("SELECT * FROM users WHERE id = :uid"), {"uid": user_id})

# GOOD: Django ORM
MyModel.objects.filter(name=user_input)
```

### 检测模式
- **MATCH**: `cursor\.execute\(.*[%f].*user\|input\|request\|form\|args` | `\.execute\(f"` | `text\(f"` | `raw\(f"`
- **EXCLUDE**: `execute\(.*%s.*,\s*\(`（参数化） | `text\(".*:\w+`（绑定参数） | ORM `filter\(`

### 修复指引
1. 始终使用参数化查询（`%s` 占位符 + 参数元组）
2. SQLAlchemy 使用绑定参数 `:param` 而非 `f-string`
3. Django ORM 使用 `filter()` / `annotate()` 避免 `raw()`
4. `ORDER BY`/`LIMIT` 等不可参数化字段使用白名单校验

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — execute 调用 + SQL 构造方式 |
| judgment_rationale | MUST — 是否参数化 vs 拼接 |
| data_flow_path | SHOULD — 用户输入到 SQL 的传递路径 |

## 输出格式

记录为 finding，标注 `severity: high`，`cwe: CWE-89`。
