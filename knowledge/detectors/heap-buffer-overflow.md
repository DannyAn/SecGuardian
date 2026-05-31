---
detector: heap-buffer-overflow
severity: critical
cwe: CWE-122
language: [c, cpp]
tags: [memory, heap, exploitation]
---

# 堆缓冲区溢出 (Heap Buffer Overflow)

## 威胁定义

堆上分配的缓冲区发生溢出，覆盖相邻堆块的元数据（malloc chunk header）。攻击者可利用堆风水（heap feng shui）技术实现代码执行。

**核心原则：堆上写入操作必须验证其大小不超过分配的堆块容量。关注 memcpy 第三个参数是否来自外部输入。**

## 检测逻辑

### Step 1: 搜索堆分配点

识别所有堆内存分配：
```c
ptr = malloc(size);
ptr = calloc(n, size);
ptr = realloc(old_ptr, size);
// C++
ptr = new T[n];
ptr = new T;
```

### Step 2: 检查写入操作是否越界

对每个分配点，检查后续写入：
- `memcpy(ptr, src, n)` — n > 分配大小？
- `strcpy(ptr, src)` — src 长度 > 分配大小？
- 循环写入 — 循环次数 > 分配大小 / 元素大小？
- `ptr[i] = val` — i 是外部控制变量？

### Step 3: 特有风险模式

**模式 1：大小计算错误**
```c
// BAD: 单位混淆
int *arr = malloc(n);              // 分配 n 字节，非 n 个 int
for (int i = 0; i < n; i++)
    arr[i] = i;                    // 溢出！需要 n * sizeof(int)

// GOOD: 正确的分配
int *arr = malloc(n * sizeof(int));
```

**模式 2：off-by-one**
```c
// BAD: 写入 len+1 个元素
char *buf = malloc(len);
strncpy(buf, src, len);
buf[len] = '\0';                   // 越界 1 字节！

// GOOD: 多分配 1 字节
char *buf = malloc(len + 1);
```

**模式 3：realloc 后使用旧大小**
```c
// BAD: realloc 后仍用旧大小
char *buf = malloc(64);
buf = realloc(buf, 128);
for (int i = 0; i < 64; i++)       // 只初始化一半，不溢出但浪费
    buf[i] = 0;
```

## 修复指引

1. **首选**：使用 C++ `std::vector`/`std::string` 替代 C 风格堆数组
2. **C 代码**：使用 `calloc`（清零+防止整数溢出）或显式验证大小
3. **编译器保护**：启用 `-ftrapv`（GCC/Clang 有符号溢出捕获）和 AddressSanitizer
4. **堆分配封装**：统一使用 `safe_malloc(size)` 包装函数内置大小校验

## 误报排除

| 场景 | 原因 |
|------|------|
| `calloc` + 边界常量 | 编译期可确定安全 |
| `std::vector::push_back` | 自动扩容 |
| `realloc` 为扩大缓冲区 | 旧数据合法 |
| `alloca` 栈分配 | 栈溢出由 CWE-121 覆盖 |

## 检测模式汇总

```
# 分配大小 < 写入大小
malloc|calloc (size_var)
→ memcpy.*> size_var
→ sizeof 使用了错误的对象

# 分配量与元素类型不匹配
malloc(n)                    # n 字节
→ array[i] 访问，i 循环到 n  # 少乘 sizeof(element)

# off-by-one 写入
malloc(n)
→ buf[n] = '\0'             # 需要 n+1 字节
```