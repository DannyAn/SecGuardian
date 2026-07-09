# SQL Injection — 跨函数追踪 (Go)

适用于 `go.injection.sql` skill（CWE-89）。max depth 1。

## 场景一: 用户输入经 fmt.Sprintf 构造 SQL

最常见的 Go SQL 注入模式 — 用户输入通过多层函数传递，最终到达 `fmt.Sprintf` 构造 SQL 字符串。

```go
func handler(w http.ResponseWriter, r *http.Request) {
    id := r.URL.Query().Get("id")       // Source: HTTP 参数
    rows, err := getUserByID(id)          // 传入构建函数
    // ...
}

func getUserByID(userID string) ([]User, error) {
    query := fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", userID)  // Sink: SQL 拼接
    return db.Query(query)
}
```

**追踪检查点:**
1. Source 到 Sink 的调用链是否在一层内？
2. 中间函数是否对用户输入做任何校验？
3. Sink 函数是否使用参数化查询？

## 场景二: 字符串拼接跨函数

```go
func searchUsers(w http.ResponseWriter, req *http.Request) {
    name := req.URL.Query().Get("name")    // Source
    buildAndQuery(name, "email")              // 参数传给拼接函数
}

func buildAndQuery(field, value string) string {
    return "SELECT * FROM users WHERE " + field + " = '" + value + "'"  // Sink: 字符串拼接
}
```

## 场景三: GORM Raw 调用跨函数

```go
func apiHandler(w http.ResponseWriter, r *http.Request) {
    condition := r.URL.Query().Get("q")   // Source
    rawQuery(condition)
}

func rawQuery(cond string) {
    db.Raw("SELECT * FROM users WHERE " + cond).Scan(&result)  // Sink: Raw SQL
}
```

## 场景四: strings.Builder 构造 SQL

```go
func buildQuery(filters map[string]string) string {
    var b strings.Builder
    b.WriteString("SELECT * FROM users WHERE 1=1")
    for k, v := range filters {
        fmt.Fprintf(&b, " AND %s = '%s'", k, v)  // Sink: Builder 拼接
    }
    return b.String()
}
```

## 深度限制

- 本追踪为 max depth 1，仅追踪从用户输入入口到 SQL 执行的一层调用链
- `fmt.Sprintf(format, userInput)` + `db.Query(result)` 即使不在同一函数也追踪
- 深度超过 1 的调用链降级为 `suspicious`（如 handler → A → B → db.Query 的 A→B 段不受限，但 handler→A 段丢失上下文）

## Go 特有的追踪难点

- **interface 动态分发**: `type DB interface { Query(string, ...interface{}) }` — 无法静态确定具体实现
- **goroutine 传递**: 用户输入通过 channel 传递到另一个 goroutine 后执行 SQL，跨 goroutine 追踪不可行
- **闭包捕获**: `func() { db.Query(fmt.Sprintf("...", capturedVar)) }` — capturedVar 的来源需要逃逸分析
