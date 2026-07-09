# CGo Memory — 误报抑制策略 (Go)

适用于 `go.memory.cgo` skill（CWE-120/CWE-415/CWE-416）。

## 策略 1: defer free 确认

**检查清单:**
- [ ] `C.CString` 后是否有 `defer C.free(unsafe.Pointer(...))`？
- [ ] defer 的位置是否在分配后立即声明？
- [ ] 所有退出路径都有释放？

```go
// ✅ 安全: defer 确保释放
cs := C.CString(input)
defer C.free(unsafe.Pointer(cs))

// ❌ 危险: 中间有 return 跳过释放
cs := C.CString(input)
if cs == nil { return }     // 尚未 defer
defer C.free(unsafe.Pointer(cs))
```

## 策略 2: 立即配对确认

```go
// ✅ 配对: 分配和释放在同一函数
cs := C.CString(input)
result := C.processString(cs)
C.free(unsafe.Pointer(cs))
return result

// ✅ 配对: 使用后即刻释放
cb := C.CBytes(data)
C.processBuffer(cb, C.int(len(data)))
C.free(cb)
```

## 策略 3: cgo.Handle 生命周期

Go 1.17+ 的 `cgo.Handle` 是安全传递 Go 对象的首选方式。

```go
// ✅ 安全: handle 在 defer 中释放
handle := cgo.NewHandle(obj)
defer handle.Delete()

// ❌ 危险: handle 被 C 侧持有但未释放
handle := cgo.NewHandle(obj)
C.registerHandle(C.uintptr_t(handle))  // C 侧需调用 handle.Delete()
```

## 策略 4: C.CBytes 安全模式

```go
// ✅ 安全: 配对分配释放
data := []byte("hello")
cData := C.CBytes(data)
defer C.free(cData)

// ❌ 危险: CBytes 未释放 (内存泄漏)
cData := C.CBytes(data)
C.printData(cData)
// 未调用 C.free(cData)
```

## 策略 5: C 库生命周期管理

当 C 库负责内存生命周期时，Go 侧不应释放。

```go
// C 库管理生命周期 — 不释放
result := C.someCFunction()  // 返回值由 C 库 free
// Go 侧不调用 C.free(result)
```

## 策略 6: 测试文件抑制

`_test.go` 完全抑制。

## 策略 7: 字符串长度验证（CWE-120）

使用 `C.CString` 前，检查 Go 字符串长度，避免缓冲区溢出。

```go
// 长度验证
if len(input) > 1024 {
    return errors.New("input too long")
}
cs := C.CString(input[:1024])  // 截断到安全长度
defer C.free(unsafe.Pointer(cs))
```
