---
detector: mismatched-free
severity: high
cwe: CWE-762
language: [c, cpp]
tags: [memory, heap, api-misuse]
---

# 释放函数不匹配 (Mismatched Free)

## 检测概要

检查分配函数与释放函数是否配对正确（如 `malloc`/`free`、`new`/`delete`、`new[]`/`delete[]`）。

## 检测逻辑

### Step 1: 分配/释放对分析

| 分配函数 | 正确释放函数 | 错误释放 |
|---------|-------------|----------|
| `malloc`/`calloc`/`realloc` | `free()` | `delete` / `delete[]` |
| `new` | `delete` | `free()` / `delete[]` |
| `new[]` | `delete[]` | `free()` / `delete` |
| `strdup`/`asprintf` (POSIX) | `free()` | `delete` |

### Step 2: 危险模式

```c
// BAD: malloc + delete
char *buf = (char*)malloc(100);
delete buf;                      // UB!

// BAD: new + free
int *arr = new int[10];
free(arr);                       // UB! 析构函数不会被调用

// BAD: new + delete[] / new[] + delete
MyClass *p = new MyClass;
delete[] p;                      // 类型不匹配
```

### Step 3: 自定义分配器

检查是否使用了自定义分配/释放函数：
```c
// 自定义分配器必须配对使用
void* my_alloc(size_t s) { return pool_alloc(s); }
void my_free(void* p) { pool_free(p); }

// BAD: 用 free() 释放自定义分配器返回的内存
void *p = my_alloc(100);
free(p);                         // 可能的堆损坏！
```

## 误报排除

| 场景 | 原因 |
|------|------|
| C 中 `operator new` placement 包装 | 底层仍是 `malloc`，可能故意用 `free` |
| 跨语言 FFI | Rust/Cgo 等边界处有显式配对约定 |
| `realloc(ptr, 0)` | 等同于 `free(ptr)` |

## 检测模式汇总

```
# malloc + delete
malloc|calloc|realloc
→ delete | delete[]

# new + free
new | new[]
→ free

# new/delete 数组标量混用
new T        → delete[] p
new T[n]     → delete p
```