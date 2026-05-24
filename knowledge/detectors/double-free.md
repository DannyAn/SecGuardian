---
detector: double-free
severity: critical
cwe: CWE-415
language: [c, cpp]
tags: [memory, heap, crash, exploitation]
---

# 双重释放 (Double Free)

## 检测概要

检查同一指针在两次 `free()`/`delete` 之间是否被再次释放，或者同一内存地址是否被不同的指针别名释放。

## 检测逻辑

### Step 1: 搜索释放操作

搜索所有内存释放点：
```c
free(ptr);
delete ptr;          // C++ 单对象
delete[] ptr;        // C++ 数组
```

### Step 2: 控制流分析

对每个释放点，检查是否存在第二次释放同地址的路径：

**模式 1：同路径重复释放**
```c
// BAD: 同一个函数内两次 free
free(ptr);
// ... 一些代码 ...
free(ptr);                    // Double Free!
```

**模式 2：条件分支后重复释放**
```c
// BAD: 不同分支释放同一个指针
if (error) {
    free(ptr);
    return;
}
free(ptr);                    // 非 error 路径的释放
// ... 但 error 路径已经释放过了
```

**模式 3：指针别名**
```c
// BAD: 同一块内存被两个指针释放
char *a = malloc(100);
char *b = a;
free(a);
free(b);                      // Double Free! b 和 a 指向同一地址
```

**模式 4：跨函数释放**
```c
void cleanup(char *p) {
    free(p);
}
void process() {
    char *buf = malloc(100);
    cleanup(buf);
    free(buf);                // Double Free! cleanup 已经释放了
}
```

### Step 3: 指针赋值后释放检查

```c
// GOOD: free 后立即置 NULL，再次 free(NULL) 是安全的
free(ptr);
ptr = NULL;
// ...
free(ptr);                    // 安全——free(NULL) 是 no-op
```

检测时注意：只检查函数内可见的赋值，不追踪全局/堆上存储的指针。

## 误报排除

| 场景 | 原因 |
|------|------|
| free 后 ptr=NULL 置空 | 再次 free(NULL) 安全 |
| 不同的条件分支（互斥路径） | 只在一个路径执行 |
| `realloc(ptr, 0)` | 等同于 free，非 double free |
| `delete` 空指针 (C++) | `delete nullptr` 安全 |
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动管理生命周期 |
| 同一指针传给不同释放函数但分配不同地址 | 如 `realloc` 后地址变化 |

## 检测模式汇总

```
# 同一函数内两次 free/delete（排除中间有赋值）
free|delete
→ (中间无 ptr = NULL|ptr = nullptr)
→ free|delete (同一变量)

# 指针别名后释放
p2 = p1
→ free(p1)
→ free(p2)

# free 无后续 NULL 赋值
free(ptr)
→ (无 ptr = NULL)
→ 函数内后续代码仍使用 ptr 或再次 free(ptr)
```
