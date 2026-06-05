---
detector: memory-leak
severity: medium
cwe: CWE-401
language: [c, cpp]
tags: [memory, heap, resource-management]
---

# 内存泄漏 (Memory Leak)

## 威胁定义

通过 `malloc`/`calloc`/`new` 分配的堆内存未在合适的时机释放，导致进程内存持续增长，最终资源耗尽。C/C++ 无 GC，内存泄漏是常见但可防止的问题。

**检测时需区分"真泄漏"和"刻意不释放"**：
- **真泄漏**：每个请求/迭代中分配但不释放 → 内存持续增长
- **非泄漏**：全局缓冲区、Arena 分配器、main() 中单次分配的 exit-time 回收

## 检测逻辑

### Step 1: 识别分配点（含自定义分配器）

标准 C/C++ 和命名约定匹配的自定义分配器：
```
malloc / calloc / realloc / strdup
new / new[]
xxx_malloc / xxx_alloc / xxx_new / xxx_create / ALLOC_xxx
```

### Step 2: 追踪释放路径 — 报告条件

**报告以下模式**：

1. **错误路径未释放**（最常见）：
```c
buf = malloc(N);
if (error) return -1;  // 泄漏！
free(buf);
```

2. **循环中分配未释放**：
```c
for (i = 0; i < n; i++) {
    char *tmp = malloc(K);  // 每次迭代泄漏！
    process(tmp);
}  // 无 free(tmp)
```

3. **指针覆盖**：
```c
ptr = malloc(N);
ptr = malloc(M);  // 旧指针丢失，N 字节泄漏
```

### Step 3: 不报告（刻意不释放）

| 模式 | 原因 |
|------|------|
| `main()` 中单次分配直到程序退出 | OS 回收 |
| Arena/Zone 分配器 `pool_alloc` + 批量 `pool_free_all` | 整体管理 |
| `static` 变量初始化分配 | 生命周期 = 程序 |
| `atexit()` 注册的释放回调 | 程序退出时执行 |

## 修复指引

1. **C++ 首选**：`std::unique_ptr<T>` / `std::shared_ptr<T>` / RAII
2. **C 代码**：使用 `goto cleanup` 模式统一资源释放
3. **循环分配**：在循环内释放或复用缓冲区
4. **编译器辅助**：启用 `-fanalyzer` (GCC 10+) 或 clang static analyzer

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动释放 |
| 自定义 Arena/Pool：`pool_alloc` + `pool_free_all()` | 批量释放 |
| 全局/static 变量 | 整个程序生命周期 |
| `main()` 或单次入口分配且程序很快退出 | OS 回收 |
| `alloca()` 栈分配 | 函数返回自动回收 |
| `atexit(cleanup_func)` | 程序退出时执行 |
| 分配后赋值给带 `__attribute__((cleanup))` 的变量 | 自动清理 |

## 检测模式汇总

```
# === MUST REPORT ===

# 分配 + 中间 return 无释放
(malloc|calloc|new|ALLOC_|_alloc|_malloc)\(
→ (同一函数, 之后) return|goto.*(?!cleanup|error|fail)
→ (return 之前, 同路径) 无 free|delete|xxx_free|xxx_release

# 循环内分配无配对释放
(for|while)\s*\(
→ 循环体内 (malloc|calloc|new)
→ 循环体内无 free|delete
→ 且指针未保存到循环外的作用域

# 指针重新赋值前未释放旧值
\w+\s*=\s*(malloc|calloc|new)
→ 同变量再次 \w+\s*=\s*(malloc|calloc|new)
→ 两次之间无 free|delete

# === MUST NOT REPORT (白名单) ===

# RAII 包装
std::unique_ptr|std::shared_ptr|std::vector|std::string

# Arena/Zone 释放
pool_free_all|zone_destroy|arena_reset|ALL_FREE

# 全局/static
static\s+\w+\s*=\s*malloc|全局初始化

# atexit 注册
atexit\(.*free|atexit\(.*cleanup
```
