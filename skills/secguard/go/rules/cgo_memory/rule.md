---
name: secguard-go-cgo-memory
description: "Detect CGo memory safety violations — buffer overflows, double free, use-after-free in C interop code"
language: go
topic: [memory, cgo]
skill_id: go.memory.cgo
signal_filter: go.memory.cgo*
signal_source: call_sites[category="*"]
severity: critical
cwe: [CWE-120, CWE-415, CWE-416]
trigger_functions: [C.CString, C.free, C.malloc, C.CBytes, C.GoBytes, C.GoString, cgo.Incomplete, cgo.Handle]
---

# cgo_memory 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.memory.cgo` |
| signal_filter | `go.memory.cgo*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `C.CString`, `C.free`, `C.malloc`, `C.CBytes`, `C.GoBytes`, `cgo.Handle` |
| 默认严重度 | Critical |
| CWE | CWE-120 (Buffer Overflow), CWE-415 (Double Free), CWE-416 (Use-After-Free) |
| Guard-rule | `memory-buffer-overflow`, `memory-double-free`, `memory-use-after-free` |

## Scenario 1: C 缓冲区溢出

### 威胁定义

CGo 中 `C.CString` 将 Go 字符串转换为 C `char*`，但 C 端如果不检查边界直接操作缓冲区可能导致溢出。C 指针在 Go 中不受 GC 管理，需要显式释放。

### 检测逻辑

```go
// 脆弱 — C 函数未检查边界
s := C.CString(userInput)
defer C.free(unsafe.Pointer(s))
C.sprintf(s, "%s", moreData)  // 未检查目标缓冲区大小

// 脆弱 — C 端 memcpy 无长度校验
C.memcpy(buf, src, C.size_t(len(src)))  // buf 可能小于 src

// 安全 — 使用 Go 管理的缓冲区
buf := make([]byte, 256)
C.memcpy(unsafe.Pointer(&buf[0]), src, C.size_t(255))

// 安全 — 明确大小检查后传给 C
if len(input) < maxSize {
    cBuf := C.CString(input)
    defer C.free(unsafe.Pointer(cBuf))
    C.process(cBuf, C.int(len(input)))
}
```

### 检测模式

```
# MATCH（触发检测）
→ C.CString → 传递给 C 函数后无大小检查
→ C 函数调用中 memcpy/sprintf/strcpy 目标为 C.CString 分配的缓冲区
→ C.free 后仍持有 C 指针
→ unsafe.Pointer 在 GC 后传给 C 的长时间运行函数

# EXCLUDE（不报告）
→ C.CString 配合明确大小检查
→ 使用 cgo.Handle 指针传递（安全模式）
→ 传递给 C 的只读指针
```

### 修复指引

1. C 端函数必须检查缓冲区边界，或使用 `C.malloc` + 明确大小传入 C 端
2. `C.CString` 分配的 C 内存必须配对 `C.free`
3. 检查 C 端是否使用安全函数族（如 `snprintf` 替代 `sprintf`）

---

## Scenario 2: Double Free / Use-After-Free

### 威胁定义

C 内存（由 `C.malloc` / `C.CString` 分配）不受 Go GC 管理。`defer C.free` 在函数退出时释放，但如果 C 端同时也释放了同一指针，则发生 Double Free。如果在 `C.free` 后仍引用该指针，则发生 Use-After-Free。

### 检测逻辑

```go
// 脆弱 — 双重释放
buf := C.malloc(1024)
defer C.free(buf)  // Go 侧释放
C.free(buf)        // C 侧再次释放 → double free

// 脆弱 — 释放后使用
ptr := C.CString(data)
C.free(unsafe.Pointer(ptr))
C.logMessage(ptr)  // use-after-free

// 安全 — 单一所有权
buf := C.malloc(1024)
defer C.free(buf)  // 唯一释放点
```

### 检测模式

```
# MATCH（触发检测）
→ 同一 C 指针有多个 C.free 调用路径
→ C.free 之后同一指针被传给其他 C 函数
→ C 端内部分配 + C 端内部 free + Go 侧也 free 的模式

# EXCLUDE（不报告）
→ C.free 仅在 defer 中调用一次（单所有权）
→ 使用 cgo.Handle 所有权模式（Go 侧唯一管理）
```

### 修复指引

1. 坚持 C 内存单一所有权原则：要么 C 端管理，要么 Go 侧通过 defer 管理
2. 避免在同一个函数中同时使用 Go defer free + C 端 free 释放同一指针
3. free 后立即将指针置 nil 以捕获释放后使用

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | CGo 调用点的完整代码，含 C 函数签名和缓冲区操作 |
| judgment_rationale | MUST | C 端是否有边界检查；内存所有权归属是否明确 |
| data_flow_path | SHOULD | C 缓冲区的分配 → C 函数操作 → 释放的完整路径 |
| call_stack | MAY | Go → CGo bridge → C 函数调用的完整调用链 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
