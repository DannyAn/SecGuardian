---
detector: memory-leak
severity: medium
cwe: CWE-401
language: [c, cpp]
tags: [memory, heap, resource-management]
---

# 内存泄漏 (Memory Leak)

## 检测概要

检查通过 `malloc`/`calloc`/`realloc`/`new` 分配的内存是否在所有执行路径上都被释放。

## 检测逻辑

### Step 1: 搜索分配点

识别所有堆分配，包括标准函数和自定义分配器：

```c
// 标准 C 库
ptr = malloc(size);
ptr = calloc(n, size);
ptr = realloc(ptr, new_size);

// C++
ptr = new T;
ptr = new T[n];

// 自定义分配器（大厂常见，参考 knowledge/languages/cpp.md）
ptr = xxx_malloc(size);       // 如 my_malloc, pool_alloc
ptr = xxx_alloc(size);        // 如 zone_alloc
ptr = xxx_new(...);           // 如 object_new
ptr = xxx_create(...);        // 如 resource_create
ptr = ALLOC_xxx(s);           // 宏分配
```

**自定义分配器释放配对**：`xxx_malloc` ↔ `xxx_free`、`xxx_alloc` ↔ `xxx_free`/`xxx_dealloc`、`xxx_new`/`xxx_create` ↔ `xxx_delete`/`xxx_destroy`。

### Step 2: 追踪释放路径

对每个分配点，收集从分配点到函数出口的所有路径，确认每条路径都有对应的释放：

**模式 1：提前返回未释放**
```c
// BAD: error 路径未释放
char *buf = malloc(100);
if (error_condition) {
    return -1;                   // 泄漏！
}
// ... 正常路径
free(buf);
return 0;
```

**模式 2：异常安全 (C++)**
```cpp
// BAD: 异常导致泄漏
char *buf = new char[100];
process_data();                  // 可能抛出异常
delete[] buf;                    // 异常时不会执行

// GOOD: RAII
std::vector<char> buf(100);
process_data();                  // 安全，析构自动清理
```

**模式 3：指针覆盖**
```c
// BAD: 覆盖后旧内存泄漏
char *buf = malloc(100);
buf = malloc(200);               // 第一次的 100 字节泄漏
```

**模式 4：循环中分配未释放**
```c
// BAD: 循环内重复分配
for (int i = 0; i < n; i++) {
    char *tmp = malloc(1024);    // 每次迭代泄漏
    process(tmp);
}
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动管理 |
| 全局生命周期指针 | 程序终止时 OS 回收 |
| 自定义内存池（arena/zone） | 批量 `pool_free_all()` 或结束时整体回收 |
| `atexit` 注册的清理 | 程序退出时回收 |
| `alloca` 栈分配 | 函数返回时自动回收 |
| `xxx_free(p)` 作为自定义释放 | 与 `xxx_malloc` 配对的自定义释放函数 |

## 检测模式汇总

```
# 分配后错误路径未释放（含自定义分配器）
malloc|calloc|new|xxx_malloc|xxx_alloc|xxx_new|ALLOC_*
→ if.*return.*-1|goto cleanup (goto 后未 free|xxx_free)
→ (同路径无 free|xxx_free)

# 指针覆盖（含自定义分配器）
ptr = malloc|xxx_malloc|xxx_alloc(N)
→ ptr = malloc|xxx_malloc|xxx_alloc(M)   # 旧指针覆盖前未释放

# 循环中分配（含自定义分配器）
for|while
→ malloc|calloc|new|xxx_malloc|xxx_alloc
→ (循环体内无 free|delete|xxx_free)
```