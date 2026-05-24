---
detector: integer-overflow
severity: high
cwe: CWE-190
language: [c, cpp]
tags: [arithmetic, allocation, size-check-bypass]
---

# 整数溢出 (Integer Overflow)

## 检测概要

检查算术运算是否可能产生溢出，特别是影响内存分配大小或安全检查的溢出。

## 检测逻辑

### Step 1: 搜索内存分配的大小计算

```c
// BAD: 乘法溢出——如果 count 和 size 都很大
void *buf = malloc(count * size);

// BAD: 加法溢出——如果 offset + len 回绕
memcpy(dst + offset, src, len);

// BAD: 宽度扩展问题
size_t total = width * height;    // 如果 width 和 height 是较小的类型
malloc(total);
```

### Step 2: 溢出检查模式

**危险模式（无检查或错误检查）：**
```c
// BAD: 无检查直接计算
void *buf = malloc(count * sizeof(item_t));

// BAD: 错误的检查顺序（先乘再判断）
size_t total = count * size;
if (total > MAX) return ERROR;    // 溢出已经发生，total 可能很小
malloc(total);
```

**安全模式：**
```c
// GOOD: 乘法前检查
if (count > SIZE_MAX / size) return ERROR;
void *buf = malloc(count * size);

// GOOD: 使用 checked 算术
if (__builtin_mul_overflow(count, size, &total)) return ERROR;
void *buf = malloc(total);
```

### Step 3: 符号转换问题

```c
// BAD: 有符号 → 无符号隐式转换
int user_size = get_user_input();   // 可为负数
if (user_size < 0) return ERROR;
// ... 
memcpy(dst, src, user_size);        // user_size 被转换为 size_t，如果为负则变成极大值

// BAD: size_t 与负数的比较
size_t len = get_length();
if (len < 0) return ERROR;           // size_t 是无符号，永远不会 < 0!

// BAD: 有符号溢出是 UB，编译器可优化掉检查
int offset = compute_offset();
if (offset + size > MAX) return;    // offset + size 有符号溢出是 UB
```

### Step 4: 循环计数器溢出

```c
// BAD: 循环计数器溢出
for (size_t i = 0; i <= len; i++) { // 如果 len == SIZE_MAX，死循环
    buf[i] = ...;                    // 最后一次 i == SIZE_MAX → 溢出
}

// BAD: 递减计数器溢出
for (size_t i = len; i >= 0; i--) {  // i 是无符号，永远 >= 0
    process(buf[i]);                 // 无限循环
}
```

### Step 5: C++ 标准库

```c++
// BAD: std::vector 大小计算溢出
std::vector<char> buf(user_count * item_size);  // 乘法可能溢出

// BAD: 迭代器运算溢出
auto end = begin + offset;           // 如果 offset 导致指针回绕
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 编译期常量运算 | 编译器可在编译期检测 |
| `__builtin_mul_overflow` 等 checked 函数 | 已做溢出检查 |
| 立即数相乘且结果在类型范围内 | 如 `malloc(256 * sizeof(int))` |
| C++ `std::vector::at()` | 越界有异常保护 |
| 已知大小范围（通过前置条件保证） | 小于某个 MAX 值的验证 |

## 检测模式汇总

```
# 乘法分配
malloc|calloc|new.*\*.*sizeof
→ 检查是否有溢出检查（比较 SIZE_MAX / count）

# 加法偏移
ptr + offset|dst + offset
→ offset 来自外部输入且无上界检查

# 符号混用
int.*= .*     # 有符号变量接收可能为负的值
→ size_t.*=.*int    # 有符号值赋值给无符号

# 循环陷阱
for.*size_t.*<= .*
→ 检查终止条件是否可能永不满足（SIZE_MAX 边界）
for.*size_t.*>= 0
→ 无符号 >= 0 永远为真
```
