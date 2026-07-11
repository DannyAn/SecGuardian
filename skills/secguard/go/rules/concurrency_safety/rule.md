---
name: secguard-go-concurrency-safety
description: "Detect dangerous concurrency patterns — map concurrent read-write panic, goroutine leaks, mutex copy, channel deadlock"
language: go
topic: [concurrency]
skill_id: go.concurrency.safety
signal_filter: go.concurrency.safety*
signal_source: call_sites[category="*"]
severity: medium
cwe: [CWE-366, CWE-833]
trigger_functions: [go, sync.Mutex, sync.RWMutex, sync.WaitGroup, sync.Map, sync.Once, make(chan), close]
---

# concurrency_safety 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.concurrency.safety` |
| signal_filter | `go.concurrency.safety*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `go` goroutine 创建, `sync.Mutex`, `sync.RWMutex`, `sync.WaitGroup`, `sync.Map`, `sync.Once`, `make(chan)`, `close()` |
| 默认严重度 | Medium |
| CWE | CWE-366 (Race Condition), CWE-833 (Deadlock) |
| Guard-rule | `concurrency-data-race`, `concurrency-deadlock` |

## Scenario 1: Map 并发读写 / 数据竞争

### 威胁定义

Go 的 `map` 不是并发安全的。多个 goroutine 同时对同一个 map 进行读写会导致 `fatal error: concurrent map read and map write`（运行时 panic）。使用 `sync.Mutex` 或 `sync.Map` 解决。

### 检测逻辑

```go
// 脆弱 — map 并发无保护
var cache map[string]int
go func() { cache["key"] = 1 }()
go func() { _ = cache["key"] }()  // 数据竞争 → panic

// 脆弱 — 仅读无锁（写有一个锁保护但读没有）
var mu sync.Mutex
mu.Lock()
cache[key] = val
mu.Unlock()
// 另一函数: _ = cache[key]  // 读未加锁!

// 脆弱 — Mutex 值复制（锁失效）
type SafeMap struct {
    mu sync.Mutex
    data map[string]int
}
func (s SafeMap) Set(k string, v int) {  // 值接收者 → 复制了 mutex!
    s.mu.Lock()
    s.data[k] = v
    s.mu.Unlock()
}

// 安全 — sync.Map
var cache sync.Map
cache.Store("key", 1)
cache.Load("key")

// 安全 — 读写均有锁保护
func (s *SafeMap) Get(k string) int {
    s.mu.Lock()
    defer s.mu.Unlock()
    return s.data[k]
}
```

### 检测模式

```
# MATCH（触发检测）
→ map 类型变量在 go 语句或 goroutine 中被读写，且无 sync.Mutex / sync.Map 保护
→ sync.Mutex 或 sync.RWMutex 作为值接收者的结构体字段（被复制）
→ sync.WaitGroup.Add 放在 go func 内部（可能先 Wait 后 Add）

# EXCLUDE（不报告）
→ sync.Map 并发操作
→ 读写锁 + 读锁均正确使用的 map
→ channel 通信替代共享内存
→ 只在单 goroutine 中访问的 map
```

### 修复指引

1. Map 并发访问：使用 `sync.Map` 或 `sync.Mutex` + `sync.RWMutex` 保护
2. Mutex 必须为指针接收者：`func (s *SafeMap) Set(...)`，禁用值接收者
3. `sync.WaitGroup.Add` 必须在 go 语句之前调用

---

## Scenario 2: Goroutine 泄漏

### 威胁定义

启动的 goroutine 没有退出机制（无限循环、无关闭 channel、无 context 取消），导致内存持续增长和服务性能下降。

### 检测逻辑

```go
// 脆弱 — goroutine 无退出机制
go func() {
    for {
        process(data)  // 永远不会退出
    }
}()

// 脆弱 — channel 未关闭导致阻塞
ch := make(chan int)
go func() {
    ch <- 1   // 如果无接收者，goroutine 阻塞泄露
}()

// 安全 — context 取消
ctx, cancel := context.WithCancel(context.Background())
go func() {
    for {
        select {
        case <-ctx.Done():
            return
        case item := <-ch:
            process(item)
        }
    }
}()
// cancel() 可安全退出 goroutine
```

### 检测模式

```
# MATCH（触发检测）
→ go func() 中 for 循环无 select + ctx.Done / channel close 退出条件
→ go func() 中的 channel 发送可能阻塞（无缓冲 chan、无接收者）
→ sync.WaitGroup.Wait 但 Add 数量不足

# EXCLUDE（不报告）
→ goroutine 有 context 取消机制
→ goroutine 有 done channel 信号
→ goroutine 使用 time.Ticker 且 defer ticker.Stop
```

### 修复指引

1. 每个 goroutine 应有明确的退出路径（context 取消 / channel close / done signal）
2. 使用 `context.WithCancel` / `WithTimeout` 管理 goroutine 生命周期
3. 配置 `go vet` 检测不可达 channel 操作

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | goroutine 创建及共享变量/锁的完整上下文 |
| judgment_rationale | MUST | 是否缺少同步机制；goroutine 是否有退出路径 |
| data_flow_path | SHOULD | 多线程对共享变量的读写路径 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
