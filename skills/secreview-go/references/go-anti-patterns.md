# Go 安全反模式

代码审查中需要关注的 Go 特有安全反模式。

## 错误处理反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `err != nil` 后继续使用返回值 | 使用零值/损坏数据 | 检查 err 立即 return |
| `panic` 在库代码中 | 调用方无法恢复 | 返回 error |
| `recover()` 吞掉所有 panic | 隐藏严重错误 | 仅恢复已知类型 |
| `log.Fatal` 在库代码中 | 进程退出无法处理 | 返回 error |

## 并发反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| goroutine 无退出机制 | goroutine 泄漏 | context.Context / done channel |
| channel 未关闭导致死锁 | 发送方永远阻塞 | 明确关闭责任 |
| `sync.Mutex` 值复制 | 锁失效 | 通过指针传递 |
| `sync.WaitGroup.Add()` 在 goroutine 内 | 竞态条件 | Add 在 goroutine 外 |
| `map` 并发读写 | fatal error: concurrent map writes | `sync.Map` 或加锁 |

## 接口/类型反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `interface{}` 过度使用 | 丢失类型安全 | 使用泛型或明确接口 |
| 类型断言不检查 ok | panic | `v, ok := x.(T)` |
| `reflect` 包非必要使用 | 绕过类型系统 | 代码生成或接口 |
| `unsafe` 包使用 | 内存安全破坏 | 绝对必要且有充分测试才用 |

## 网络/HTTP 反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| DefaultServeMux 全局使用 | 任何包可注册路由 | 自定义 ServeMux |
| `http.ListenAndServe(":8080", nil)` | 同上 | 非 nil handler |
| pprof 路由生产暴露 | 性能信息泄露 | 仅内网/开发环境启用 |
| ResponseWriter 在 goroutine 中使用 | 不安全的并发写 | goroutine 完成后再返回 |
