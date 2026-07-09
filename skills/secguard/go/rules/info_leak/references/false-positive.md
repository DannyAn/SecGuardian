# Info Leak — 误报抑制策略 (Go)

适用于 `go.error.info-leak` skill（CWE-248/CWE-209/CWE-532）。

## 策略 1: 输出目标确认

**检查清单:**
- [ ] `fmt.Fprintf` 的 `w` 是 `http.ResponseWriter` 还是 `os.Stderr`/`bytes.Buffer`？
- [ ] 写入 `os.Stderr` 不构成信息泄露（终端日志）
- [ ] 写入 `bytes.Buffer` 或 `strings.Builder` 不直接泄露（内部处理）
- [ ] 写入 `log.Writer()` 不构成 HTTP 泄露（日志系统）

```go
// 以下不构成信息泄露:
fmt.Fprintf(os.Stderr, "error: %v", err)       // stderr，安全
log.Printf("error: %v", err)                     // 日志系统，安全
buf := &bytes.Buffer{}
fmt.Fprintf(buf, "debug: %v", internal)          // 内部 buffer，安全

// 以下构成信息泄露:
fmt.Fprintf(w, "error: %v", err)                 // ResponseWriter，泄露
```

## 策略 2: 错误内容检查

```go
// 安全: 通用错误消息
http.Error(w, "Internal Server Error", 500)
http.Error(w, "401 Unauthorized", 401)

// 不安全: 泄露内部细节
fmt.Fprintf(w, "error at %s:%d: %v", file, line, err)
fmt.Fprintf(w, "stack trace: %s", debug.Stack())
```

## 策略 3: 日志 vs HTTP 区分

如果敏感数据只写入日志系统（`log.Printf`, `slog`, `zap`），不写入 `http.ResponseWriter`，则不构成 HTTP 信息泄露。但根据 CWE-532（敏感信息入日志），需评估日志存储安全性。

## 策略 4: 开发/生产模式确认

```go
// 开发模式下的调试信息 — 需确保仅开发环境可用
if os.Getenv("DEBUG") == "1" || !cfg.IsProduction {
    fmt.Fprintf(w, "debug: %v", state)    // 仅在非生产模式
}
```

## 策略 5: 结构化日志字段过滤

```go
// 使用了字段过滤的结构化日志 — 安全
slog.Info("payment processed", "card_last4", cc[len(cc)-4:])  // 仅最后4位

// 完整信用卡号入日志 — 不安全
slog.Info("payment processed", "card_number", cc)             // 完整卡号
```

## 策略 6: 测试文件抑制

`_test.go` 完全抑制。
