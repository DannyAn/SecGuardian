---
detector: buffer-overflow
severity: critical
cwe: CWE-120
language: [c, cpp]
tags: [memory, stack, heap, exploitation]
precision: very-high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "memory.buffer-overflow",
  "type": "guard-rule",
  "namespace": "memory",
  "severity": "Critical",
  "cwe": "CWE-120",
  "cvss": 9.8,
  "confidence": "dynamic",
  "precision": "very-high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "argv",
    "code_context",
    "getenv",
    "gets_s",
    "input",
    "judgment_rationale",
    "memcpy",
    "memcpy_s",
    "scanf_s",
    "snprintf",
    "sprintf_s",
    "strcat",
    "strcat_s",
    "strcpy",
    "strcpy_s",
    "strncpy",
    "user"
  ],
  "match_patterns": [
    "\\bgets\\(",
    "(strcpy|strcat)\\(dst,  → dst 为 char dst[N] 且 src 来自外部",
    "sprintf\\([^)]*%s[^)]*user|input|argv|getenv",
    "memcpy\\([^)]*, [^)]*, (?!sizeof\\(dst\\))  → n 来自变量/外部",
    "memcpy\\(dst,\\s*src,\\s*sizeof\\(src\\)\\)  # 在函数体内且 src 为参数"
  ],
  "exclude_patterns": [
    "strcpy_s\\(dst,\\s*sizeof\\(dst\\)",
    "strcat_s\\(dst,\\s*sizeof\\(dst\\)",
    "sprintf_s\\(buf,\\s*sizeof\\(buf\\)",
    "memcpy_s\\(dst,\\s*sizeof\\(dst\\)",
    "scanf_s\\([^)]*%s[^)]*sizeof\\(",
    "gets_s\\([^)]*sizeof\\(",
    "snprintf\\([^)]*sizeof\\([^)]*\\).*\\n.*if\\s*\\(.*written.*>=",
    "std::string|std::vector|std::array.*push_back|\\.append|\\.assign"
  ],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

程序向缓冲区写入超出其容量的数据，覆盖相邻内存，可能导致代码执行或程序崩溃。主要影响 C/C++，其他语言通过 FFI/cgo 间接影响。

**核心原则：内存操作必须边界检查。** 检测时必须区分"无边界保护的写入"和"已验证边界的写入"——仅报告前者。

## 检测逻辑 (Detection Logic)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：危险函数调用（strcpy/strcat/sprintf/gets/memcpy）的完整代码，包含目标缓冲区的声明/分配代码、源数据的来源、以及拷贝长度参数（如有）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析目标缓冲区大小与写入数据大小的关系——目标缓冲区是栈数组（char buf[N]）还是堆分配（malloc）；写入数据来源是外部输入（用户/网络/环境变量）还是已知字面量；是否存在 sizeof(dst) 验证或 Annex K _s 函数保护
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：源数据从外部输入 → 危险函数参数 → 目标缓冲区的完整数据流，标注每层的长度变化
      → findings.evidence.data_flow_path
- [ ] **call_stack**：调用函数 → 危险函数 → 缓冲区声明的完整调用链，确认 sizeof 在跨函数传递时是否退化为指针大小
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：目标缓冲区的声明大小/分配大小、源数据的实际长度或可能的最大长度、memcpy 的 count 参数值、sprintf 格式化参数的扩展长度
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：编译选项是否启用 FORTIFY_SOURCE（-D_FORTIFY_SOURCE=2）、Stack Protector（-fstack-protector-strong）、AddressSanitizer（-fsanitize=address）
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **C11 代码**：使用 `strcpy_s(dst, sizeof(dst), src)` 等 Annex K 函数
2. **非 Annex K 平台**：`snprintf(buf, sizeof(buf), "%s", src)` 并检查返回值
3. **C++ 代码**：使用 `std::string` / `std::vector` 替代 C 风格数组
4. **memcpy/memmove**：确保第三个参数 ≤ `sizeof(dst)`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `strcpy_s(dst, sizeof(dst), src)` | C11 Annex K，运行时约束强制 | 确认 dsize 参数为 sizeof(dst)，且 dst 为数组（非指针） |
| `snprintf(buf, sizeof(buf), ...)` + 返回值检查 | 边界正确且截断被处理 | 确认返回值被保存并检查 `if (written >= sizeof(buf))` 或 `if (written < 0)` |
| `strncpy(dst, src, sizeof(dst)-1); dst[sizeof(dst)-1]='\0'` | 手动保证 null 终止 | 确认 n 参数 = sizeof(dst)-1，且同作用域内有显式 null 终止赋值 |
| `memcpy_s(dst, sizeof(dst), src, n)` | C11 Annex K | 确认 dst 为数组，sizeof(dst) 为实际数组大小（非指针大小） |
| C++ `std::string` / `std::vector::at()` | 内置边界检查 | 确认使用 std::string/std::vector 管理缓冲区，非 C 风格数组 |
| 分配大小与拷贝大小均为同一编译期常量 | 编译器可验证 | 确认 sizeof(dst) 和 n 均为编译期常量且 n <= sizeof(dst) |
| `sizeof(src)` 且 src 为数组（非指针参数） | 编译器可确定大小 | 确认 src 在函数体内声明为数组，非函数参数（已退化为指针） |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# gets 任何使用
\bgets\(
                                                       # → MUST: code_context (危险函数调用+缓冲区声明)

# strcpy/strcat 且目标为栈缓冲区
(strcpy|strcat)\(dst,  → dst 为 char dst[N] 且 src 来自外部
                                                       # → MUST: judgment_rationale (缓冲区大小 vs 写入数据分析)

# sprintf 含 %s 且参数来自外部
sprintf\([^)]*%s[^)]*user|input|argv|getenv

# memcpy 第三个参数来自外部输入
memcpy\([^)]*, [^)]*, (?!sizeof\(dst\))  → n 来自变量/外部

# sizeof(src) 陷阱——src 是函数参数(已退化为指针)
memcpy\(dst,\s*src,\s*sizeof\(src\)\)  # 在函数体内且 src 为参数

# === EXCLUDE (不报告) ===

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
