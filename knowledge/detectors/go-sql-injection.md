---
detector: go-sql-injection
severity: critical
cwe: CWE-89
language: [go]
tags: [web, injection, database]
---

# Go SQL 注入检测

## 检测概要

检查 Go 代码中是否将不可信数据拼接到 SQL 查询字符串中。

## 检测逻辑

### Step 1: 搜索危险模式

```go
// BAD: database/sql + fmt.Sprintf 拼接
query := fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username)
rows, err := db.Query(query)

// BAD: database/sql Exec 拼接
db.Exec(fmt.Sprintf("DELETE FROM users WHERE id = %s", userID))

// BAD: GORM Raw() + 拼接
db.Raw(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username)).Scan(&users)

// BAD: sqlx 拼接
db.Queryx(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username))

// BAD: GORM Order/Group 动态字段
db.Order(userSuppliedField).Find(&users)
db.Group(userSuppliedGroupBy).Find(&users)

// BAD: sqlx.In 动态列名
query, args, _ := sqlx.In("SELECT * FROM users WHERE name IN (?)", names)
db.Select(&users, query, args...)
```

### Step 2: 安全模式

```go
// GOOD: 参数化查询
rows, err := db.Query("SELECT * FROM users WHERE name = $1", username)
db.Exec("DELETE FROM users WHERE id = $1", userID)

// GOOD: GORM 链式调用
db.Where("name = ?", username).Find(&users)

// GOOD: GORM 结构体查询
db.Where(&User{Name: username}).Find(&users)

// GOOD: sqlx 命名参数
db.NamedExec("SELECT * FROM users WHERE name = :name", map[string]interface{}{"name": username})

// GOOD: ORDER BY 白名单
var allowedColumns = map[string]bool{"id": true, "name": true, "created_at": true}
if !allowedColumns[orderBy] {
    return errors.New("invalid column")
}
db.Order(orderBy).Find(&users)
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `db.Query(query, args...)` 占位符 | 参数化安全 |
| GORM `Where("name = ?", name)` | 参数化安全 |
| sqlx `NamedExec` / `NamedQuery` | 命名参数安全 |
| ORDER BY 白名单校验 | 已验证 |
| 静态 SQL 无外部输入 | 无注入路径 |

## 检测模式汇总

```
# fmt.Sprintf 拼接到 SQL
fmt\.Sprintf.*SELECT|INSERT|DELETE|UPDATE
→ db\.Query|db\.Exec|db\.Raw (同一调用链)

# GORM Raw/Exec 拼接
db\.Raw\(fmt\.Sprintf|db\.Exec\(fmt\.Sprintf

# ORDER BY 无白名单
db\.Order\(
→ 参数来自外部 (request/param/input)
→ 无 allowedColumns|whitelist 校验

# 字符串拼接后传给 SQL
query\s*:?=.*\+.*user|input|param
→ db\.Query(query)|db\.Exec(query)
```
