# Concurrency Safety — 误报抑制策略 (Go)

适用于 `go.concurrency.safety` skill（CWE-366/CWE-833）。

## 策略 1: 锁范围确认

**检查清单:**
- [ ] map/slice 操作是否在 `Lock()/Unlock()` 之间？
- [ ] RWMutex 的 `RLock()/RUnlock()` 是否对称？
- [ ] 锁是否保护了所有访问路径（读和写）？
- [ ] 是否误锁了不同级别的资源导致锁无效？

```go
var mu sync.Mutex
var users map[string]User

func saveUser(u User) {
    mu.Lock()
    users[u.ID] = u           // ✅ 在锁保护内
    mu.Unlock()
}
```

## 策略 2: atomic 操作确认

检查是否可以使用 `sync/atomic` 替代锁。对于简单计数器、标志位，atomic 更高效且安全。

```go
// 误报可能: 简单的 int64 操作可能误判为需要锁
var counter atomic.Int64     // ✅ atomic 足够
counter.Add(1)
```

**检查清单:**
- [ ] 是简单类型（int64, uint64, bool, pointer）？
- [ ] 操作是原子操作（Add, CompareAndSwap, Load, Store）？
- [ ] 不需要保护多个相关字段的一致性？→ 用锁

## 策略 3: 初始化后只读

```go
// 初始化后只读的全局变量
var config map[string]string

func init() {
    config = loadConfig()  // 初始化，单 goroutine
}

func getConfig(key string) string {
    return config[key]     // 初始化后只读，安全
}
```

## 策略 4: channel 通信

```go
// 通过 channel 传递所有权
ch := make(chan map[string]int)

go func() {
    m := <-ch              // 接收所有权
    m["key"] = 42          // 此时只有此 goroutine 访问
}()

ch <- make(map[string]int) // 移交所有权
```

## 策略 5: 单 goroutine 确认

```go
func main() {
    // main goroutine 唯一访问 — 无需锁
    counter := 0
    for i := 0; i < 10; i++ {
        counter++           // 不存在并发，误报
    }
}
```

## 策略 6: sync.Map 替代

```go
// ✅ sync.Map 安全
var cache sync.Map
cache.Store("key", "value")
```

## 策略 7: 测试文件

`_test.go` 完全抑制 — 测试中的竞态条件由 `go test -race` 捕获，非本工具职责。

## 策略 8: hashicorp/golang-lru 等并发安全库

第三方并发安全容器（LRU 缓存、分片 map）不报告。
