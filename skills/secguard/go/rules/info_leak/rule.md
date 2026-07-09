---
name: secguard-go-info-leak
description: "Detect information leakage via panic details returned to client, stack traces exposed, or debug/pprof exposed in production"
language: go
topic: [error, web]
skill_id: go.error.info-leak
signal_filter: go.error.info-leak*
signal_source: call_sites[category="*"]
severity: medium
cwe: [CWE-248, CWE-209, CWE-532]
trigger_functions: [recover, debug.Stack, debug.PrintStack, pprof, http.ListenAndServe]
---

# info_leak 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.error.info-leak` |
| signal_filter | `go.error.info-leak*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `recover()`, `debug.Stack()`, `debug.PrintStack()`, `net/http/pprof`, `fmt.Fprintf()` 写入 HTTP ResponseWriter |
| 默认严重度 | Medium |
| CWE | CWE-248 (Uncaught Exception), CWE-209 (Information Exposure Through an Error Message), CWE-532 (Insertion of Sensitive Information into Log File) |
| Guard-rule | `error-panic-to-client`, `error-stack-trace-leak`, `error-log-sensitive-data` |

## Scenario 1: Panic 信息返回客户端

### 威胁定义

Go 中 `recover()` 捕获的 panic 值（数组越界、nil 指针 dereference）如果直接写入 HTTP 响应体，会泄露内部实现细节（文件名、行号、数据结构）。

**核心原则：`recover()` 捕获的信息仅写入内部日志，HTTP 响应统一返回 "500 Internal Server Error"。**

### 检测逻辑

```go
// 脆弱 — panic 信息直接返回
defer func() {
    if err := recover(); err != nil {
        fmt.Fprintf(w, "Panic: %v", err)       // 泄露!
    }
}()

// 脆弱 — 堆栈直接返回
defer func() {
    if err := recover(); err != nil {
        w.Write(debug.Stack())                  // 堆栈泄露!
    }
}()

// 安全 — 内部日志 + 通用返回
defer func() {
    if err := recover(); err != nil {
        log.Printf("PANIC: %v\n%s", err, debug.Stack())
        http.Error(w, "Internal server error", http.StatusInternalServerError)
    }
}()
```

### 检测模式

```
# MATCH（触发检测）
→ recover() 返回值通过 fmt.Fprintf(w, ...) 写入 HTTP 响应
→ recover() 返回值通过 json.NewEncoder(w).Encode 写入响应体
→ debug.Stack() / debug.PrintStack() 写入 HTTP ResponseWriter
→ http.Error(w, err.Error(), ...) 返回具体错误消息
→ gin.CustomRecovery 自定义处理泄露 panic 信息

# EXCLUDE（不报告）
→ recover 返回值仅写入内部日志（log.Printf, log.Println）
→ http.Error(w, "Internal server error", 500) 通用错误返回
→ gin.Default() / gin.Recovery() 默认中间件
```

### 修复指引

1. 使用 `gin.Default()` 自带的 Recovery 中间件（返回通用 500）
2. 自定义 recover：panic 详情写入日志，HTTP 返回通用错误消息
3. 统一错误响应格式，只返回错误码和通用消息

---

## Scenario 2: 敏感数据日志泄露

### 威胁定义

密码、Token、API Key、PII 等敏感数据被记录到日志中。Go 中常见的错误模式是 `log.Printf("User: %+v", user)` — 结构体 `%+v` 序列化可能暴露所有字段，包括 `Password` 等敏感字段。

### 检测逻辑

```go
// 脆弱 — 敏感数据记录
log.Printf("password: %s", password)
log.Printf("Token: %s", token)

// 脆弱 — 完整结构体 dump
log.Printf("User: %+v", user)  // 包含 Password 字段

// 脆弱 — 敏感字段在日志字符串中
logger.Info("request", zap.Any("body", body))  // body 可能含密码

// 安全 — 结构化日志 + 敏感字段过滤
logger.Info("user_login", zap.String("username", user.Username))

// 安全 — 结构体自定义 String() 脱敏
func (u User) String() string {
    return fmt.Sprintf("User{Username: %s}", u.Username)
}
```

### 检测模式

```
# MATCH（触发检测）
→ log.Printf / log.Println / log.Fatalf 参数含敏感字段名（password, token, secret, key）
→ %+v / %#v 格式化完整结构体，且结构体含敏感字段
→ zap.Any / logrus.WithField 记录可能含敏感字段的完整对象

# EXCLUDE（不报告）
→ 日志已使用结构化日志 + 字段级别脱敏
→ 自定义 String() 方法已排除敏感字段
→ 日志框架配置了敏感字段 RegexFilter
```

### 修复指引

1. 使用结构化日志，仅记录必要字段，不记录完整结构体
2. 敏感字段实现自定义 `String()` 方法脱敏
3. 日志配置脱敏中间件过滤 password/token/secret 字段

---

## Scenario 3: debug/pprof 生产环境暴露

### 威胁定义

导入 `net/http/pprof` 会在默认 ServeMux 上注册调试端点（`/debug/pprof/`），暴露堆栈、CPU profile、内存 profile 等内部信息。

### 检测逻辑

```go
// 脆弱 — 生产环境导入 pprof
import _ "net/http/pprof"
http.ListenAndServe(":8080", nil)  // /debug/pprof 可访问

// 安全 — pprof 仅绑定内部端口
import _ "net/http/pprof"
go http.ListenAndServe("127.0.0.1:6060", nil)  // 仅本地可访问
```

### 检测模式

```
# MATCH（触发检测）
→ import _ "net/http/pprof" 在 main 包中，且监听非 localhost 地址
→ import "net/http/pprof" 在生产构建中

# EXCLUDE（不报告）
→ pprof 绑定 127.0.0.1 仅本地访问
→ pprof 在 build tag 条件编译中仅调试构建
```

### 修复指引

1. pprof 端点仅绑定 `127.0.0.1` 内部端口
2. 使用 build tags 区分开发/生产构建
3. 生产环境不要导入 `net/http/pprof`

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | defer/recover 块、日志语句或 pprof import 的完整上下文 |
| judgment_rationale | MUST | panic 信息是否泄露给客户端；日志是否包含敏感数据 |
| data_flow_path | SHOULD | 异常发生 → 捕获 → 响应/日志的数据流 |

## 输出格式

遵循 `commands/claude/secguard.md` 定义的四段式输出。
