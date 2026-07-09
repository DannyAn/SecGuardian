# Info Leak — 跨函数追踪 (Go)

适用于 `go.error.info-leak` skill（CWE-248/CWE-209/CWE-532）。max depth 1。

## 场景一: panic → recover → HTTP 响应

```go
func handler(w http.ResponseWriter, r *http.Request) {
    defer handlePanic(w)            // recover 包装
    processRequest(w, r)
}

func handlePanic(w http.ResponseWriter) {
    if r := recover(); r != nil {
        // Sink: panic 详情写入 HTTP 响应
        fmt.Fprintf(w, "panic: %v", r)
        // 应改为: http.Error(w, "Internal Server Error", 500)
    }
}
```

## 场景二: 错误堆栈 → 浏览器

```go
func processHandler(w http.ResponseWriter, r *http.Request) {
    data, err := processRequest(r)
    if err != nil {
        debugHandler(w, err)        // 泄露堆栈
    }
}

func debugHandler(w http.ResponseWriter, err error) {
    // Sink: 堆栈信息写入 HTTP 响应
    fmt.Fprintf(w, "Error: %+v\n", err)
    debug.PrintStack()
    fmt.Fprintf(w, "Stack: %s", debug.Stack())
}
```

## 场景三: 日志中的敏感数据

```go
func saveCreditCard(w http.ResponseWriter, r *http.Request) {
    cc := r.FormValue("credit_card")
    err := saveCard(cc)
    if err != nil {
        log.Printf("save failed for card %s: %v", cc, err)  // Sink: 信用卡号入日志
    }
}
```

## 场景四: 环境变量泄露

```go
func debugInfo(w http.ResponseWriter, r *http.Request) {
    if r.URL.Query().Get("debug") == "1" {
        fmt.Fprintf(w, "DB_PASS=%s", os.Getenv("DB_PASS"))   // Sink: 环境变量泄露
    }
}
```

## 深度限制

- 追踪 panic recover 中是否将内部状态写入 HTTP ResponseWriter
- 追踪 log.Printf/slog 中是否包含敏感数据 (password, secret, token, credit_card, SSN)
- 仅跨一层的调用链追踪（handler → callback, handler → log func）
