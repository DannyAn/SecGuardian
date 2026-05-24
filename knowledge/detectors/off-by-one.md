---
detector: off-by-one
severity: high
cwe: CWE-193
language: [c, cpp]
tags: [memory, boundary, logic-error]
---

# Off-by-One 错误

## 检测概要

检查循环边界或数组索引是否因 `<=` / `>=` 使用错误导致越界 1 个元素。

## 检测逻辑

### Step 1: 循环边界检查

```c
// BAD: <= 导致越界
char buf[64];
for (int i = 0; i <= 64; i++)    // 应该是 i < 64
    buf[i] = 0;                   // 最后一次迭代 buf[64] 越界

// BAD: 倒序循环
for (int i = n; i >= 0; i--)      // 应该是 i > 0 或 i >= 1
    arr[i] = arr[i-1];
```

### Step 2: 字符串操作

```c
// BAD: strlen 不包含 '\0'
char *src = "hello";              // strlen=5
char dst[5];                      // 需要 6 字节 (5 + null)
strcpy(dst, src);                 // 溢出 1 字节！

// GOOD:
char dst[6];
strcpy(dst, src);
```

### Step 3: memcpy/memset 大小

```c
// BAD: sizeof 指针 vs 数组
char buf[32];
memset(buf, 0, sizeof(buf));      // GOOD: 32
char *ptr = buf;
memset(ptr, 0, sizeof(ptr));      // BAD: 8 (指针大小)

// BAD: 遗漏 null 终止符
strncpy(dst, src, sizeof(dst));
// 如果 src >= sizeof(dst)，不会写 '\0'
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `strncpy` + 手动 null 终止 | 已处理边界情况 |
| 循环边界为 `sizeof(array)/sizeof(array[0])` | 编译期正确 |
| sentinel 标记结尾 | 显式的终止符处理 |

## 检测模式汇总

```
# <= 代替 <
for.*<=.*sizeof|for.*<=.*len|for.*<=.*count
→ 数组写入

# sizeof 指针陷阱
char \*ptr = ...
→ sizeof(ptr)         # 8 字节，不是数组大小

# strlen + 边界
strlen(src) + 分配大小
→ 少分配 1 字节（没用 +1）
```