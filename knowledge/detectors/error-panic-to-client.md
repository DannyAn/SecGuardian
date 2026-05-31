---
detector: error-panic-to-client
severity: medium
cwe: CWE-248
language: [go]
tags: [error, go, panic, recover, http]
---

# Go panic 返回客户端 (Panic Recovery Leak)

## 威胁定义

Go 中 panic recover 处理不当，将内部 panic 详情（数组越界、nil 指针、堆栈 trace）直接返回给 HTTP 客户端，泄露内部实现细节、文件路径和数据结构。

**核心原则：`recover()` 返回的信息必须仅写入内部日志，HTTP 响应返回通用 "500 Internal Server Error"。**

## 检测逻辑

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

## 修复指引

1. 使用 `gin.Default()` 自带的 Recovery 中间件（返回通用 500 错误）
2. 自定义 recover: 只写 `log.Printf("PANIC: %v", err)` 到日志，HTTP 返回通用错误
3. gRPC interceptor: 返回 `codes.Internal` + 通用消息，panic 详情只记日志

## 误报排除

| 场景 | 原因 |
|------|------|
| `gin.Default()` / `gin.Recovery()` 默认中间件 | 框架已安全处理 |
| panic 仅写入本地日志文件 | 非对外暴露 |
| `log.Fatal` 退出程序 | 非 API 返回 |
| 测试代码 | 非生产 |
| 内部调试端口非对外服务 | 内部使用 |

## 检测模式汇总

```
# recover 直接写 HTTP 响应
recover.*fmt\.Fprintf.*w\b|recover.*w\.Write
recover.*json\.NewEncoder\(w\)\.Encode.*err\|r\b
recover.*w\.Write\(debug\.Stack\(\)
recover.*http\.Error\(w,\s*.*\.Error\(\)

# Gin recover 自定义泄露
CustomRecovery.*gin\.H\{.error.*err\}
CustomRecovery.*c\.AbortWithStatusJSON.*err

# gRPC interceptor 泄露
recover.*status\.Errorf.*panic.*%v
```
