# Concurrency Safety — 跨函数追踪 (Go)

适用于 `go.concurrency.safety` skill（CWE-366/CWE-833）。max depth 1。

## 场景一: map 并发读写跨函数

```go
var cache = make(map[string]int)     // 未加锁的共享 map

func writer(key string, val int) {
    cache[key] = val                  // 写操作 — 无锁
}

func reader(key string) int {
    return cache[key]                 // 读操作 — 无锁，与 writer 并发
}

// main 中同时启动读和写 goroutine
func main() {
    go writer("a", 1)
    go reader("a")                     // 数据竞争!
}
```

## 场景二: slice 并发追加

```go
var results []string

func processItem(item string, wg *sync.WaitGroup) {
    defer wg.Done()
    results = append(results, item)    // 多个 goroutine 并发追加
}                                      // 数据竞争!

func main() {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go processItem(item, &wg)     // 启动多个 goroutine
    }
    wg.Wait()
}
```

## 场景三: 闭包捕获循环变量

```go
func main() {
    var wg sync.WaitGroup
    for i := 0; i < 10; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            fmt.Println(i)              // 数据竞争: 循环变量 i 被多个 goroutine 共享
        }()
    }
    wg.Wait()
}

// 修正: 参数传递
for i := 0; i < 10; i++ {
    go func(n int) {
        fmt.Println(n)                  // 安全: 参数副本
    }(i)
}
```

## 场景四: channel close + send 竞争

```go
var ch = make(chan int)

func sender() {
    for i := 0; i < 10; i++ {
        ch <- i
    }
}

func closer() {
    time.Sleep(time.Millisecond)
    close(ch)                           // 关闭 channel
}

func main() {
    go sender()
    go closer()
    // 可能出现: send on closed channel — panic!
}
```

## 深度限制

- max depth 1: 追踪共享变量访问到 goroutine 启动的一层调用链
- Go 的 `go` 关键字启动闭包 = 隐含的数据竞争风险（闭包捕获外部变量）
- `sync.WaitGroup` 和 `sync.Mutex` 的误用不会被检测到（需要更深的数据流分析）
