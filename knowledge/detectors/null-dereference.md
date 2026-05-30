---
detector: null-dereference
severity: high
cwe: CWE-476
language: [c, cpp]
tags: [memory, pointer, crash]
---

# 空指针解引用 (Null Dereference)

## 检测概要

检查指针在使用前是否经过 NULL 检查，或在分配失败后是否被直接使用。

## 检测逻辑

### Step 1: 搜索内存分配函数调用

在代码中搜索以下分配函数，检查返回值是否被验证：

**标准函数：**
- `malloc(size)` / `calloc(n, size)` / `realloc(ptr, size)`
- C++: `new` / `new[]` (nothrow 版本返回 nullptr)

**自定义分配器（大厂常见模式，参考 `knowledge/languages/cpp.md`）：**

搜索以下命名模式的所有函数：
```c
// 命名约定：*_malloc, *_alloc, *_new, *_create, ALLOC_*, pool_alloc, zone_alloc
void* my_malloc(size_t size);
MyObj* object_new(Manager* mgr);
void* ALLOC(size_t s);

// 这些函数都可能返回 NULL，必须检查
```

**检测规则**：对任何匹配 `*_malloc`、`*_alloc`、`*_new`、`*_create`、`ALLOC_*`、`*_Alloc` 的函数调用，如果返回值被直接解引用而未先检查 NULL，则报告 null-dereference。

### Step 2: 检查返回值检查

对于每个分配调用，检查是否存在以下模式：

**危险模式（直接使用，无检查）：**
```c
// BAD: malloc 后直接使用
char *buf = malloc(size);
buf[0] = 'x';                    // 如果 malloc 返回 NULL 则崩溃

// BAD: 仅 assert 检查（release 构建会被优化掉）
char *buf = malloc(size);
assert(buf != NULL);             // NDEBUG 定义时 assert 为空操作
buf[0] = 'x';
```

**安全模式：**
```c
// GOOD: 检查后使用
char *buf = malloc(size);
if (buf == NULL) { return ERROR; }
buf[0] = 'x';

// GOOD: 通过 goto 统一处理
char *buf = malloc(size);
if (!buf) { goto cleanup; }
```

### Step 3: 检查函数返回值

非分配函数返回指针也可能为 NULL：
- `fopen()` 返回 NULL
- `getenv()` 返回 NULL
- `strchr()`/`strstr()` 返回 NULL
- `realloc()` 返回 NULL（注意：原内存不会释放）

```c
// BAD: getenv 未检查
char *home = getenv("HOME");
strcpy(path, home);              // 如果 HOME 未设置则崩溃
```

### Step 4: 路径分析

对于每个未检查的使用点，追踪指针是否能到达该路径：
1. 函数内直接路径：分配 → 使用（中间无分支检查）
2. 跨函数路径：指针作为参数传递，在调用者中检查，被调用者中未检查
3. 条件检查覆盖不全：只在一个分支中检查，另一个分支未检查

## 误报排除

| 场景 | 原因 |
|------|------|
| `new` (默认版本) | 标准 C++ `new` 抛出 `std::bad_alloc` 而非返回 nullptr |
| 已通过上层函数保证 | 调用者已检查，被调用者不需要再检查 |
| `alloca()` | 栈上分配，失败直接 undefined behavior |
| GCC `__attribute__((malloc))` 标注 | 编译器可优化 NULL 检查，但函数仍可能返回 NULL |
| 静态/全局缓冲区 | 分配在编译期确定 |

## 检测模式汇总

```
# 高危 API 后缺少 NULL 检查
malloc|calloc|realloc|fopen|getenv|strdup|mmap
→ 下一行不是 if.*NULL|if.*nullptr|if.*!

# assert 作为唯一的 NULL 检查
malloc|calloc
→ assert(ptr|buf|mem
→ 直接使用 ptr|buf|mem

# realloc 存储在同一个变量中
ptr = realloc(ptr, size)    # 泄漏风险（失败时返回 NULL 且原内存未释放）
```
