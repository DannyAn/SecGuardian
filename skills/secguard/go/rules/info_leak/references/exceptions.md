# Info Leak — 例外规则 (Go)

适用于 `go.error.info-leak` skill（CWE-248/CWE-209/CWE-532）。

## 例外 1: 日志记录输出（非 HTTP 响应）

```go
// EXCEPTION: 写入日志/标准错误
log.Printf("error processing request: %v", err)
log.Println("stack trace:", string(debug.Stack()))
fmt.Fprintf(os.Stderr, "debug: %v", val)
slog.Error("request failed", "error", err, "stack", debug.Stack())
```

## 例外 2: 通用错误消息

```go
// EXCEPTION: 通用错误消息
http.Error(w, "Internal Server Error", http.StatusInternalServerError)
http.Error(w, "Not Found", http.StatusNotFound)
w.WriteHeader(http.StatusForbidden)
```

## 例外 3: 受控的调试端点（非生产）

仅在开发模式或受认证的调试端点可用。

```go
// EXCEPTION: 开发模式标记
if !cfg.IsProduction {
    fmt.Fprintf(w, "debug: %+v", internalState)
}
```

## 例外 4: pprof 在认证后

```go
// EXCEPTION: pprof 需认证
mux.Handle("/debug/pprof/", authMiddleware(http.DefaultServeMux))
```

## 例外 5: 测试代码
