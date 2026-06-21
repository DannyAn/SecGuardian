---
detector: error-panic-to-client
severity: medium
cwe: CWE-248
language: [go]
tags: [error, go, panic, recover, http]
precision: very-high
confidence: dynamic
---

# Go panic 返回客户端 (Panic Recovery Leak)

## 威胁定义 (Threat Definition)

Go 中 panic recover 处理不当，将内部 panic 详情（数组越界、nil 指针、堆栈 trace）直接返回给 HTTP 客户端，泄露内部实现细节、文件路径和数据结构。

**核心原则：`recover()` 返回的信息必须仅写入内部日志，HTTP 响应返回通用 "500 Internal Server Error"。**

## 检测逻辑 (Detection Logic)

### Step 1: recover 直接写 HTTP 响应

```go
// BAD: recover 后直接写响应
http.HandleFunc("/api", func(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if err := recover(); err != nil {
            fmt.Fprintf(w, "Panic: %v", err)  // panic 信息泄露!
        }
    }()
    // ...
})

// BAD: recover 后 JSON 返回 panic
defer func() {
    if r := recover(); r != nil {
        json.NewEncoder(w).Encode(map[string]interface{}{
            "error": r,  // 可能包含数组越界、nil 指针等内部信息
        })
    }
}()

// BAD: panic 堆栈直接返回
defer func() {
    if err := recover(); err != nil {
        w.Write(debug.Stack())  // 完整堆栈泄露!
    }
}()
```

**Go 安全模式:**
```go
// GOOD: 内部日志 + 通用返回
defer func() {
    if err := recover(); err != nil {
        log.Printf("PANIC: %v\nStack: %s", err, debug.Stack())
        http.Error(w, "Internal server error", http.StatusInternalServerError)
    }
}()
```

### Step 2: Gin/Echo 中间件不当

```go
// BAD: Gin 自定义 recovery 泄露
r := gin.New()
r.Use(gin.CustomRecovery(func(c *gin.Context, err interface{}) {
    c.AbortWithStatusJSON(500, gin.H{"error": err})  // 泄露!
}))

// BAD: Echo 错误处理器
e.HTTPErrorHandler = func(err error, c echo.Context) {
    c.JSON(500, map[string]interface{}{"error": err.Error()})  // 可能泄露
}
```

**Gin 安全模式:**
```go
// GOOD: Gin Recovery 中间件（默认安全）
r := gin.Default()  // 自动包含 Recovery 中间件，返回通用 500
```

### Step 3: gRPC/微服务间 panic 传播

```go
// BAD: gRPC interceptor 返回 panic 详情
func PanicInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp interface{}, err error) {
    defer func() {
        if r := recover(); r != nil {
            err = status.Errorf(codes.Internal, "panic: %v", r)  // 跨服务泄露
        }
    }()
    return handler(ctx, req)
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：panic recover 代码块的完整内容，包含 defer/recover 匿名函数、HTTP ResponseWriter 写入操作（fmt.Fprintf(w, ...)/w.Write(...)/json.NewEncoder(w)）、以及 recover 返回值被写入响应体的具体行号
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析 recover 后 panic 信息是否被写入 HTTP 响应体——判断响应的内容是否为通用 "500 Internal Server Error"，还是包含了 recover() 返回值、debug.Stack() 输出、或具体 panic 错误消息
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：panic 发生点 → recover() 捕获 → 日志写入 vs HTTP 响应写入的分叉路径，标注信息泄露的分支
      → findings.evidence.data_flow_path
- [ ] **call_stack**：HTTP Handler → defer 函数 → recover 调用 → 响应写入的完整调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：recover() 返回值的类型和内容、是否使用了 debug.Stack()、日志写入目标（stderr/文件/远程）、HTTP 响应状态码
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了框架默认 Recovery 中间件（gin.Default/gonic.Recovery）、是否配置了全局 HTTP 错误处理器统一返回通用错误
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 使用 `gin.Default()` 自带的 Recovery 中间件（返回通用 500 错误）
2. 自定义 recover: 只写 `log.Printf("PANIC: %v", err)` 到日志，HTTP 返回通用错误
3. gRPC interceptor: 返回 `codes.Internal` + 通用消息，panic 详情只记日志

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `gin.Default()` / `gin.Recovery()` 默认中间件 | 框架已安全处理 | 确认使用 gin.Default() 或 gin.Recovery() 中间件，非 gin.CustomRecovery() 自定义 |
| panic 仅写入本地日志文件 | 非对外暴露 | 确认 recover 返回值仅通过 log.Printf/log.Println 写入，无任何 HTTP ResponseWriter 写入操作 |
| `log.Fatal` 退出程序 | 非 API 返回 | 确认使用 log.Fatal/os.Exit，程序直接终止，不返回任何响应 |
| 测试代码 | 非生产 | 确认文件路径包含 _test.go 或在测试函数中（func TestXxx） |
| 内部调试端口非对外服务 | 内部使用 | 确认调试端口绑定 127.0.0.1 且防火墙禁止外部访问 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# recover 直接写 HTTP 响应
recover.*fmt\.Fprintf.*w\b|recover.*w\.Write
                                                       # → MUST: code_context (defer/recover+响应写入)
recover.*json\.NewEncoder\(w\)\.Encode.*err\|r\b
recover.*w\.Write\(debug\.Stack\(\)
recover.*http\.Error\(w,\s*.*\.Error\(\)
                                                       # → MUST: judgment_rationale (panic信息泄露到响应体分析)

# Gin recover 自定义泄露
CustomRecovery.*gin\.H\{.error.*err\}
CustomRecovery.*c\.AbortWithStatusJSON.*err

# gRPC interceptor 泄露
recover.*status\.Errorf.*panic.*%v

# === EXCLUDE (不报告) ===
→ gin\.Default\(\)|gin\.Recovery\(\)               # Gin 默认 Recovery
→ log\.Printf.*PANIC|log\.Println.*panic            # 仅写日志
→ http\.Error\(w,\s*"Internal server error"         # 通用错误消息
→ codes\.Internal,\s*"internal error"               # gRPC 通用错误
→ _test\.go                                          # 测试文件
→ log\.Fatal|os\.Exit                                 # 程序退出
```
