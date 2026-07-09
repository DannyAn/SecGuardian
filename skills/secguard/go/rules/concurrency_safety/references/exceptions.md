# Concurrency Safety — 例外规则 (Go)

适用于 `go.concurrency.safety` skill（CWE-366/CWE-833）。

## 例外 1: sync.Map

使用 `sync.Map` 替代普通 `map` 的并发操作不报告。

```go
// EXCEPTION: sync.Map
var cache sync.Map
cache.Store("key", "value")
v, ok := cache.Load("key")
cache.Range(func(k, v interface{}) bool { ... })
```

## 例外 2: Mutex/RWMutex 保护

```go
// EXCEPTION: mutex 保护
var mu sync.Mutex
var counters map[string]int

func increment(key string) {
    mu.Lock()
    counters[key]++
    mu.Unlock()
}

func read(key string) int {
    mu.RLock()    // RWMutex
    defer mu.RUnlock()
    return counters[key]
}
```

## 例外 3: 原子操作

```go
// EXCEPTION: atomic 操作
var counter atomic.Int64
counter.Add(1)
val := counter.Load()
```

## 例外 4: 无竞争的单 goroutine 访问

在 `main()` 的同一 goroutine 中操作的共享变量，无并发 goroutine 访问。

## 例外 5: channel 通信

通过 channel 传递数据的所有权，不存在共享内存竞争。

```go
// EXCEPTION: channel 通信
ch := make(chan int)
go func() { ch <- 42 }()  // 通过 channel 传递，非共享
val := <-ch
```

## 例外 6: 测试代码
