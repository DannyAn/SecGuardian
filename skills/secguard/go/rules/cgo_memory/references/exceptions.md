# CGo Memory — 例外规则 (Go)

适用于 `go.memory.cgo` skill（CWE-120/CWE-415/CWE-416）。

## 例外 1: defer C.free

```go
// EXCEPTION: defer 确保释放
cs := C.CString(input)
defer C.free(unsafe.Pointer(cs))    // 函数退出时自动释放
C.someCFunction(cs)
```

## 例外 2: 立即配对释放

```go
// EXCEPTION: 使用后立即释放
cs := C.CString(input)
result := C.processString(cs)
C.free(unsafe.Pointer(cs))           // 同一函数内释放
return result
```

## 例外 3: cgo.Handle（Go 1.17+）

```go
// EXCEPTION: cgo.Handle 自动管理生命周期
handle := cgo.NewHandle(someGoObject)
defer handle.Delete()
C.passHandle(C.uintptr_t(handle))
```

## 例外 4: C.CBytes + 配对释放

```go
// EXCEPTION: CBytes 配对释放
cb := C.CBytes(data)
defer C.free(cb)
C.processBuffer(cb, C.int(len(data)))
```

## 例外 5: Go 管理的 C 内存（不释放）

由 C 库负责生命周期的内存块，Go 侧不释放。

```go
// EXCEPTION: C 库管理生命周期
result := C.someCFunction()  // 返回值由 C 库管理，不调用 C.free
```

## 例外 6: 测试代码
