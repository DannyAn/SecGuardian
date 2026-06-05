---
detector: mismatched-free
severity: high
cwe: CWE-762
language: [c, cpp]
tags: [memory, heap, api-misuse]
---

# 释放函数不匹配 (Mismatched Free)

## 威胁定义

分配和释放函数不配对（`malloc`→`delete` 或 `new`→`free`），导致未定义行为。不同分配体系使用不同的内部数据结构，混用必然导致堆损坏。C/C++ 混合代码和自定义分配器是高发场景。

**核心原则：`malloc`↔`free`、`new`↔`delete`、`new[]`↔`delete[]`、`xxx_alloc`↔`xxx_free` 严格配对。**

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

大厂项目几乎不使用裸 `malloc`/`free`，而是通过自定义包装器管理内存（参考 `knowledge/languages/cpp.md`）。

检查是否存在自定义分配/释放配对，并验证它们被正确匹配：

**常见自定义分配器命名模式：**

| 分配端 | 释放端 | 示例项目 |
|--------|--------|---------|
| `xxx_malloc(s)` | `xxx_free(p)` | 内核、嵌入式 |
| `xxx_alloc(s)` | `xxx_free(p)` / `xxx_dealloc(p)` | 游戏引擎 |
| `xxx_new(...)` | `xxx_delete(p)` / `xxx_destroy(p)` | C 风格 OOP |
| `xxx_create(...)` | `xxx_destroy(p)` / `xxx_release(p)` | 资源管理器 |
| `ALLOC_xxx(s)` | `FREE_xxx(p)` | 宏包装 |
| `pool_alloc(s)` | `pool_free(p)` | 内存池 |
| `zone_alloc(z, s)` | `zone_free_all(z)` | Arena/Zoned allocator |

**危险混用模式：**
```c
// BAD: 用 free() 释放自定义分配器返回的内存
void *p = my_alloc(100);
free(p);                         // 堆损坏！

// BAD: 用 A 的分配器和 B 的释放器
void *p = zone_alloc(zone_a, 100);
pool_free(pool_b, p);            // 跨分配器释放

// BAD: 自定义释放器释放标准 malloc 的内存
void *p = malloc(100);
my_free(p);                      // my_free 可能期望 pool header
```

**检测规则：**
1. 识别项目中所有 `*_alloc`/`*_malloc`/`*_new`/`*_create`/`ALLOC_*` 函数
2. 找到每个分配函数对应的释放函数（通常命名成对）
3. 检查每个分配/释放调用：是否来自同一"家族"
4. `free()` 只应释放 `malloc`/`calloc`/`realloc` 返回的指针，不能释放自定义分配器的内存

## 修复指引

1. **严格配对**：`malloc`→`free`、`new`→`delete`、`new[]`→`delete[]`
2. **C++ 首选**：使用 `std::unique_ptr`/`std::make_unique` 自动管理
3. **自定义分配器**：提供配对宏 `#define SAFE_FREE(ptr) xxx_free(ptr); ptr = NULL`
4. **代码审查**：C/C++ 混合代码中特别关注分配/释放配对

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
