# SQL Injection — 例外规则 (Go)

适用于 `go.injection.sql` skill（CWE-89）。

## 例外 1: database/sql 参数化查询

Go 标准库 `database/sql` 支持 `$N` 和 `?` 占位符。使用参数化查询时不报告。

```go
// EXCEPTION: $1 占位符 — 参数化查询，安全
db.Query("SELECT * FROM users WHERE id = $1", userID)
db.Exec("UPDATE users SET name = $1 WHERE id = $2", name, id)
db.QueryRow("SELECT email FROM users WHERE id = $1 AND active = $2", id, true)
```

```go
// EXCEPTION: ? 占位符 (MySQL driver)
db.Query("SELECT * FROM users WHERE id = ?", userID)
db.Exec("INSERT INTO users(name, email) VALUES(?, ?)", name, email)
```

## 例外 2: ORM 方法的参数化调用

GORM、sqlx 等 ORM 使用 `?` 占位符绑定参数，安全。

```go
// EXCEPTION: GORM Where + 占位符
db.Where("name = ?", name).First(&user)
db.Where("id IN ?", ids).Find(&users)

// EXCEPTION: sqlx.In + 占位符
sqlx.In("SELECT * FROM users WHERE id IN (?)", ids)
sqlx.In("UPDATE users SET name = ? WHERE id = ?", name, id)

// EXCEPTION: GORM Raw + 占位符
db.Raw("SELECT * FROM users WHERE id = ?", id).Scan(&result)
```

## 例外 3: 编译期常量 SQL

SQL 查询为纯字符串常量，不包含用户输入插值。

```go
// EXCEPTION: 纯常量
const query = "SELECT 1"
const listAll = "SELECT * FROM users ORDER BY created_at DESC"
db.QueryRow(query)
db.Select(listAll)
```

## 例外 4: 查询中仅使用安全的动态标识符

动态表名/列名来自内部映射（非用户输入），且经过白名单校验。

```go
// EXCEPTION: 表名来自白名单
var allowedTables = map[string]bool{"users": true, "orders": true, "products": true}
func queryTable(table string) error {
    if !allowedTables[table] {
        return errors.New("invalid table")
    }
    query := fmt.Sprintf("SELECT * FROM %s WHERE id = $1", table)
    _, err := db.Query(query, id)
    return err
}
```

## 例外 5: 测试代码

`_test.go` 和 `*_test.go` 文件中的 SQL 查询不报告。测试代码使用内存数据库或容器化测试环境，不构成生产风险。

```go
// Test 文件 — 不报告
func TestUserQuery(t *testing.T) {
    db, _ := sql.Open("sqlite3", ":memory:")
    db.Exec("CREATE TABLE users (id INT, name TEXT)")
    db.Exec(fmt.Sprintf("INSERT INTO users VALUES(1, '%s')", "test")) // test only
}
```

## 例外 6: 日志/审计 SQL

用于日志记录的 SQL 构造（非执行）不报告。

```go
// EXCEPTION: 仅用于日志
log.Printf("would execute: SELECT * FROM users WHERE id = '%s'", userInput)
```
