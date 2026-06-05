---
detector: null-dereference
severity: high
cwe: CWE-476
language: [c, cpp]
tags: [memory, pointer, crash]
---

# 空指针解引用 (Null Dereference)

## 威胁定义

程序对值为 NULL 的指针进行解引用操作，导致段错误崩溃或（在特定条件下）可被利用的未定义行为。C/C++ 中 malloc/fopen/getenv 等函数可能返回 NULL，如果未检查直接使用就是高危。

**核心原则：任何可能返回 NULL 的函数调用后，返回值必须在使用前检查。** 但需区分"直接检查"和"通过调用链保证"——调用者已检查的场景不重复报告。

## 检测逻辑

### Step 1: 搜索可能返回 NULL 的调用

| 函数类别 | 示例 | 检测条件 |
|---------|------|---------|
| 内存分配 | `malloc`/`calloc`/`realloc` | 返回值被解引用且无 NULL 检查 |
| 文件操作 | `fopen`/`opendir` | 同上 |
| 环境变量 | `getenv` | 同上 |
| 字符串查找 | `strchr`/`strstr`/`strtok` | 同上 |
| 自定义分配器 | `xxx_malloc`/`xxx_alloc`/`xxx_new` | 同上，需匹配命名约定 |
| C++ new (std::nothrow) | `new(std::nothrow) T` | 返回 nullptr |
| C++ dynamic_cast (指针) | `dynamic_cast<T*>(ptr)` | 失败返回 nullptr |

### Step 2: 确认"检查"存在

有效检查模式（**不报告**）：
```c
if (ptr == NULL) return ERROR;       // 显式检查
if (!ptr) goto cleanup;              // 逻辑非检查
if (ptr) { use(ptr); }               // 条件使用
```

**报告**模式：
```c
ptr = malloc(n);
ptr->field = value;                  // 无中间检查 ← 报告

// assert 不算检查（release 构建中 NDEBUG 定义后 assert 为空操作）
ptr = malloc(n);
assert(ptr != NULL);                 // 这不是真正的检查 ← 报告
ptr->field = value;
```

### Step 3: 调用链保证

```c
// 场景：调用者已检查
void process(char *buf) {
    buf[0] = 'x';  // 调用者保证 buf 非 NULL → 不报告
}

void caller() {
    char *buf = malloc(100);
    if (!buf) return;
    process(buf);   // 已检查后传入
}
```

## 修复指引

1. **分配后立即检查**：`if (!ptr) return ERR_NOMEM;`
2. **C++ 优先使用 throw 版本**：`new T` 失败抛 `std::bad_alloc`，无需手动 NULL 检查
3. **使用 RAII 包装**：`std::unique_ptr<T>` 自动管理生命周期
4. **禁止用 assert 做 NULL 检查**：release 构建中 assert 被移除

## 误报排除

| 场景 | 原因 |
|------|------|
| C++ `new T`（非 nothrow） | 失败抛异常，不返回 nullptr |
| 调用者已检查 NULL | 通过参数传递前已验证 |
| `alloca()` / 栈分配 | 非堆分配，无 NULL 返回 |
| `std::unique_ptr`/`std::shared_ptr` | RAII 保证有效 |
| `static`/全局 buffer | 编译期分配，地址确定 |
| GCC `__attribute__((returns_nonnull))` | 编译器标注函数不返回 NULL |
| `assert(ptr)` 且 `NDEBUG` 未定义 | 开发/调试构建 |

## 检测模式汇总

```
# === MUST REPORT ===

# malloc/calloc/realloc 后无 NULL 检查直接使用
(malloc|calloc|realloc)\(
→ 下一非空行不是 if\s*\(.*NULL|if\s*\(!|goto\s+cleanup|return.*NULL
→ 同作用域内指针被解引用 (->|[*\[\]])

# assert 作为唯一检查
(malloc|calloc)\([^)]*\)
→ assert\(.*!=.*NULL\)
→ 同作用域后使用指针

# getenv/fopen/strchr 返回值未检查
(getenv|fopen|strchr|strstr)\(
→ 返回值赋值
→ 无 if.*NULL 直接使用

# realloc 覆盖原始指针（泄漏 + 空指针双重风险）
\w+\s*=\s*realloc\(\1,

# === MUST NOT REPORT (白名单) ===

# C++ new (throw 版本) — 不返回 nullptr
new\s+(?!\(std::nothrow\))

# 调用者已检查的模式（通过上下文判断）
# — 指针变量在 if (!ptr) 之后的作用域内使用
# — 函数参数标注为 __attribute__((nonnull))

# GCC returns_nonnull 标注
__attribute__\(\(returns_nonnull\)\)
```
