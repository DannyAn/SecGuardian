---
detector: buffer-overflow
severity: critical
cwe: CWE-120
language: [c, cpp]
tags: [memory, stack, heap, exploitation]
---

# 缓冲区溢出 (Buffer Overflow)

## 检测概要

检查向固定大小缓冲区写入数据时是否可能超出其容量，覆盖相邻内存。

## 检测逻辑

### Step 1: 不安全的字符串操作

检查以下函数的调用，并验证目标缓冲区大小是否足够：

| 危险函数 | 风险 | 检查点 |
|---------|------|--------|
| `strcpy(dst, src)` | 无大小限制 | src 长度是否超过 dst |
| `strcat(dst, src)` | 累计写入无限制 | 已有内容 + src 是否超过 dst |
| `sprintf(buf, fmt, ...)` | 无大小限制 | 格式化结果是否超过 buf |
| `gets(buf)` | 完全无法安全使用 | 任何使用都是高危 |
| `scanf("%s", buf)` | 无宽度限制 | 是否指定了 `%Ns` |
| `vsprintf(buf, fmt, ap)` | 无大小限制 | 同 sprintf |

### Step 2: 内存拷贝操作

| 操作 | 检查点 |
|------|--------|
| `memcpy(dst, src, n)` | n 是否 ≤ dst 分配大小 |
| `memmove(dst, src, n)` | 同上 |
| `bcopy(src, dst, n)` | 同上 |
| `strncpy(dst, src, n)` | n 是否正确（注意 strncpy 不保证 null 终止） |

关键检查：n 值来源
- 硬编码常量 → 检查是否超过 dst 大小
- 外部输入 → 高危，必须验证
- `sizeof(src)` → 错误用法（指针的 sizeof 是 4/8 字节，不是缓冲区大小）

### Step 3: 循环写入

```c
// BAD: 循环边界由外部输入控制
for (int i = 0; i < user_length; i++) {
    buf[i] = data[i];         // 如果 user_length > sizeof(buf) 则溢出
}

// BAD: 使用 sizeof(src) 而非 sizeof(dst)
char dst[64];
memcpy(dst, src, sizeof(src)); // src 是指针时 sizeof 错误!
```

### Step 4: snprintf 特殊检查

```c
// BAD: snprintf 返回值是"本应写入的字符数"，可能超过 n
int written = snprintf(buf, sizeof(buf), "%s", user);
buf[written] = 'x';           // 危险——written 可能 >= sizeof(buf)

// GOOD: 检查返回值
int written = snprintf(buf, sizeof(buf), "%s", user);
if (written >= sizeof(buf)) { /* truncated, handle error */ }
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `strncpy(dst, src, sizeof(dst))` | 边界正确 |
| `snprintf(buf, sizeof(buf), ...)` | 边界正确 |
| `strcpy_s(dst, sizeof(dst), src)` | C11 Annex K 安全函数，运行时约束强制 |
| `strncpy_s(dst, sizeof(dst), src, n)` | C11 Annex K |
| `sprintf_s(buf, sizeof(buf), fmt, ...)` | C11 Annex K |
| `memcpy_s(dst, sizeof(dst), src, n)` | C11 Annex K |
| `strcat_s(dst, sizeof(dst), src)` | C11 Annex K |
| `scanf_s("%s", buf, sizeof(buf))` | C11 Annex K — `%s`/`%c`/`%[` 必须跟大小参数 |
| `gets_s(buf, sizeof(buf))` | C11 Annex K — 安全替代 gets |
| 静态分配 + 编译期已知大小 | 编译器可能优化掉风险 |
| C++ `std::string::copy()` | 超过 n 时抛出 `out_of_range` |
| C++ `std::vector::at()` | 越界时抛出异常 |

### `_s` 函数检测原则

1. 如果代码使用了 `xxx_s(dst, dsize, ...)` 且 `dsize` = `sizeof(dst)` → **Safe，不报告**
2. 如果 `dsize` 来自 `_TRUNCATE` 宏 → 检查是否验证了截断返回值，未验证则报告
3. 混用 `_s` 和原始函数（部分处用了 `strcpy_s`，部分处仍用 `strcpy`）→ 仍报告原始函数处

## 检测模式汇总

```
# 无边界字符串函数
strcpy|strcat|sprintf|gets|scanf.*%s
→ 排除 _s 版本 (strcpy_s|strcat_s|sprintf_s|gets_s|scanf_s)
→ 检查是否有前面的长度验证

# memcpy 大小由外部输入
memcpy|memmove|bcopy
→ 排除 _s 版本 (memcpy_s|memmove_s)
→ 第三个参数来自用户输入|外部数据|网络数据

```
# 无边界字符串函数
strcpy|strcat|sprintf|gets|scanf.*%s
→ 检查是否有前面的长度验证

# memcpy 大小由外部输入
memcpy|memmove|bcopy
→ 第三个参数来自用户输入|外部数据|网络数据

# sizeof(src) 在 memcpy 中（指针陷阱）
memcpy.*sizeof.*src     # src 可能是指针

# 循环中数组写入边界由输入控制
for.*<.*user|input|external
→ buf[i]|arr[i]|ptr[i] 赋值
```
