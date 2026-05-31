---
detector: buffer-overflow
severity: critical
cwe: CWE-120
language: [c, cpp]
tags: [memory, stack, heap, exploitation]
---

# 缓冲区溢出 (Buffer Overflow)

## 威胁定义

程序向缓冲区写入超出其容量的数据，覆盖相邻内存，可能导致代码执行或程序崩溃。主要影响 C/C++，其他语言通过 FFI/cgo 间接影响。

**核心原则：内存操作必须边界检查。** 检测时必须区分"无边界保护的写入"和"已验证边界的写入"——仅报告前者。

## 检测逻辑

### Step 1: 不安全的字符串操作

检查以下函数的调用，并验证目标缓冲区大小是否足够：

| 危险函数 | 风险 | 何时报告 | 何时不报告 |
|---------|------|---------|-----------|
| `strcpy(dst, src)` | 无大小限制 | src 来自外部输入/无长度验证 | src 是已知固定长度的内部字面量 |
| `strcat(dst, src)` | 累计写入无限制 | dst 已包含内容 + src 外部输入 | src 长度 + dst 已有长度 < dst 分配大小（已验证） |
| `sprintf(buf, fmt, ...)` | 无大小限制 | fmt 参数含 `%s` 且来自外部输入 | 仅含 `%d`/`%u`/`%c` 等固定宽度格式 |
| `gets(buf)` | 完全无法安全使用 | **任何使用都是高危** | 无例外 |

### Step 2: 内存拷贝操作

| 操作 | 何时报告 | 何时不报告 |
|------|---------|-----------|
| `memcpy(dst, src, n)` | n 来自外部输入 或 n > sizeof(dst) | n ≤ sizeof(dst) 且 n 为编译期常量 |
| `strncpy(dst, src, n)` | n < sizeof(dst) 且不保证 null 终止 | `n == sizeof(dst)-1` 且手动置 `dst[n]='\0'` |

### Step 3: 安全函数白名单（不报告）

以下模式为已防护代码，**绝不报告**：

```
# C11 Annex K (运行时约束强制)
strcpy_s(dst, sizeof(dst), src)
strcat_s(dst, sizeof(dst), src)  
sprintf_s(buf, sizeof(buf), fmt, ...)
scanf_s("%s", buf, sizeof(buf))
gets_s(buf, sizeof(buf))
memcpy_s(dst, sizeof(dst), src, n)

# C 标准库正确使用
snprintf(buf, sizeof(buf), fmt, ...) 且返回值被检查
strncpy(dst, src, sizeof(dst)-1) 且 dst[sizeof(dst)-1] = '\0'
```

**关键判断**：`xxx_s(dst, dsize, ...)` 且 `dsize == sizeof(dst)` → 不报告。

### Step 4: 需要报告的边缘场景

```
# _s 函数的 dsize 非 sizeof —— 检查是否有效
strcpy_s(dst, n, src)  # n 来自外部输入 ← 报告

# snprintf 返回值未检查
int w = snprintf(buf, sizeof(buf), "%s", user);
buf[w] = 'x';  # w 可能 >= sizeof(buf) ← 报告

# 指针 sizeof 陷阱
memcpy(dst, src, sizeof(src))  # src 是指针，sizeof 为 4/8 ← 报告
```

## 修复指引

1. **C11 代码**：使用 `strcpy_s(dst, sizeof(dst), src)` 等 Annex K 函数
2. **非 Annex K 平台**：`snprintf(buf, sizeof(buf), "%s", src)` 并检查返回值
3. **C++ 代码**：使用 `std::string` / `std::vector` 替代 C 风格数组
4. **memcpy/memmove**：确保第三个参数 ≤ `sizeof(dst)`

## 误报排除

| 场景 | 原因 |
|------|------|
| `strcpy_s(dst, sizeof(dst), src)` | C11 Annex K，运行时约束强制 |
| `snprintf(buf, sizeof(buf), ...)` + 返回值检查 | 边界正确且截断被处理 |
| `strncpy(dst, src, sizeof(dst)-1); dst[sizeof(dst)-1]='\0'` | 手动保证 null 终止 |
| `memcpy_s(dst, sizeof(dst), src, n)` | C11 Annex K |
| C++ `std::string` / `std::vector::at()` | 内置边界检查 |
| 分配大小与拷贝大小均为同一编译期常量 | 编译器可验证 |
| `sizeof(src)` 且 src 为数组（非指针参数） | 编译器可确定大小 |

## 检测模式汇总

```
# === MUST REPORT (高危) ===

# gets 任何使用
\bgets\(

# strcpy/strcat 且目标为栈缓冲区
(strcpy|strcat)\(dst,  → dst 为 char dst[N] 且 src 来自外部

# sprintf 含 %s 且参数来自外部
sprintf\([^)]*%s[^)]*user|input|argv|getenv

# memcpy 第三个参数来自外部输入
memcpy\([^)]*, [^)]*, (?!sizeof\(dst\))  → n 来自变量/外部

# sizeof(src) 陷阱——src 是函数参数(已退化为指针)
memcpy\(dst,\s*src,\s*sizeof\(src\)\)  # 在函数体内且 src 为参数

# === MUST NOT REPORT (白名单) ===

# Annex K _s 函数 + sizeof(dst)
strcpy_s\(dst,\s*sizeof\(dst\)
strcat_s\(dst,\s*sizeof\(dst\)
sprintf_s\(buf,\s*sizeof\(buf\)
memcpy_s\(dst,\s*sizeof\(dst\)
scanf_s\([^)]*%s[^)]*sizeof\(
gets_s\([^)]*sizeof\(

# snprintf + sizeof + 返回值检查
snprintf\([^)]*sizeof\([^)]*\).*\n.*if\s*\(.*written.*>=

# C++ 安全容器
std::string|std::vector|std::array.*push_back|\.append|\.assign
```
