# CGo Memory — 跨函数追踪 (Go)

适用于 `go.memory.cgo` skill（CWE-120/CWE-415/CWE-416）。max depth 1。

## 场景一: CString 分配 — 跨函数释放

```go
func processRequest(data string) {
    cs := C.CString(data)           // Alloc: C 内存分配
    deferFree(cs)                     // 传给它函数释放
    // BUG: deferFree 在 processRequest 返回前释放了 cs
    // 但此时还可能被其他 goroutine 使用
    useLater(cs)                      // Use-After-Free!
}

func deferFree(s *C.char) {
    defer C.free(unsafe.Pointer(s))   // 在 processRequest 返回前就释放
}
```

## 场景二: C 内存作为函数返回值

```go
func parseString(input string) *C.char {
    cs := C.CString(input)            // Alloc
    return cs                         // 所有权转移到调用者
}

func caller() {
    result := parseString(userInput)  // 接收 C 字符串
    // BUG: 忘记调用 C.free — 内存泄漏
    C.free(unsafe.Pointer(result))    // 正确做法
}
```

## 场景三: CBytes 跨函数

```go
func serialize(data []byte) unsafe.Pointer {
    return C.CBytes(data)             // Alloc: C 内存
}

func handler(data []byte) {
    ptr := serialize(data)
    processInC(ptr)
    // BUG: 未释放
    C.free(ptr)                        // 正确做法
}
```

## 场景四: goroutine + cgo 内存

```go
func asyncProcess(data string) {
    cs := C.CString(data)             // Alloc
    go func() {
        defer C.free(unsafe.Pointer(cs))
        C.process(cs)                 // 在 goroutine 中释放
    }()
    // OK: cs 在 goroutine 中释放
}
```

## 场景五: cgo.Handle 传递

```go
func setCallback(obj interface{}) {
    handle := cgo.NewHandle(obj)        // Alloc
    C.registerCallback(C.uintptr_t(handle))
    // BUG: handle 未释放 — C 库回调中未调用 handle.Delete()
    handle.Delete()                     // 正确做法
}
```

## 深度限制

- max depth 1: 追踪 C 内存分配到释放的一层调用链
- 跨 goroutine 的 cgo 内存传递会追踪，但 goroutine 的异步执行时机不可确定
- `C.CString`/`C.CBytes`/`cgo.NewHandle` 为 Alloc 入口
- `C.free`/`handle.Delete()` 为 Free 出口
