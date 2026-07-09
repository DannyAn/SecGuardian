# SQL Injection — 误报抑制策略 (Go)

适用于 `go.injection.sql` skill（CWE-89）。

## 策略 1: 确认参数化查询

确认 `db.Query`/`db.Exec` 是否使用 `$N` 或 `?` 占位符。

**检查清单:**
- [ ] SQL 字符串包含 `$1`, `$2` 或 `?` 占位符
- [ ] 用户输入作为 `query` 后的 variadic 参数传入（非嵌入字符串）
- [ ] 不是 `fmt.Sprintf` 结果传入 `db.Query` 的组合

```go
// 误报可能: db.Query 调用本身看起来危险，但实际使用了占位符
db.Query("SELECT * FROM users WHERE id = $1", userID)     // ✅ 安全，参数化
db.Query("SELECT * FROM users WHERE id = ?", userID)       // ✅ 安全，参数化
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)) // ❌ 真注入
```

## 策略 2: 测试文件抑制

所有 `*_test.go` 文件中的 SQL 相关 finding 自动抑制。

## 策略 3: ORM 误报

GORM 等 ORM 的链式调用中，如果最终执行使用参数绑定，不应报告。

```go
// GORM 链式调用，Where 内字符串不是最终 SQL
db.Where("name = ?", name).First(&user)     // ✅ 安全，参数绑定
db.Where("name = '" + name + "'").First(&user) // ❌ 真注入
```

## 策略 4: 数值类型参数

如果用户输入经过 `strconv.Atoi`/`strconv.ParseInt` 等数值转换后嵌入 SQL，由于数值类型天然防注入（无法注入引号/分号），可抑制。

```go
id, err := strconv.Atoi(userInput)
if err != nil { return }
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = %d", id))  // 数值类型，低风险
```

注意：仅适用于 `%d`/`%f` 等数值格式。`%s` 格式即使输入是数字也危险（可传入 `1;DROP TABLE`）。

## 策略 5: 指数回退

同一 `file:line` 在多次扫描中重复报告但确认为误报后，按以下规则降级：

| 重复次数 | 操作 |
|---------|------|
| 第 1 次 | 正常报告 |
| 第 2 次 | 降级为 medium |
| 第 3 次+ | 加入 skip list |
