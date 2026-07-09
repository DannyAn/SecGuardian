---
name: secguard-cpp-api_semantic_misuse
description: "API called with semantically wrong arguments — realloc(p,0), overlapping memmove, ignored snprintf return, wrong memset size, strncpy without null-termination, memcpy overlapping regions"
category: language-specific
language: cpp
topic: [memory]
skill_id: semantics.api
signal_filter: semantics.api*
signal_source: call_sites[cat="*"]
severity: high
cwe: [CWE-628]
---

# api_semantic_misuse 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | semantics.api |
| signal_filter | semantics.api* |
| signal_source | call_sites[cat="*"] |
| severity | high |
| cwe | CWE-628 |
| precision | high |
| confidence | dynamic |

## Scenario 1: 内存分配/初始化 API 语义误用

### 威胁定义

realloc(p, 0) 在 C 标准中的行为依赖于实现版本——C89 返回 NULL，C11 为实现定义，C23 明确等价于 free(p)。使用 realloc(p, 0) 作为释放手段可导致不可移植行为和分配器状态混淆。memset 的 size 参数若误传 sizeof(ptr) 而非 sizeof(\*ptr)，仅清零指针本身而非目标对象，留下未初始化数据，可被攻击者利用读取敏感信息。

**核心原则**：realloc 的 size 参数为 0 时意图应明确使用 free()。memset 的 size 参数必须指向实际对象大小而非指针大小。

### 检测逻辑

#### Step 1: 搜索 realloc(p, 0) 模式

定位所有 `realloc(ptr, 0)` 调用——其中第二个参数为字面量 0：

```c
// 脆弱: realloc(p, 0) — 行为不可移植
ptr = realloc(ptr, 0);  // C89 返回 NULL, C11 实现定义, C23 等价 free

// 安全: 使用 free + NULL 赋值
free(ptr);
ptr = NULL;
```

#### Step 2: 搜索 memset 大小错误

定位 `memset(ptr, 0, sizeof(ptr))` 调用——其中第一个参数为指针而非数组，sizeof 作用于指针：

```c
// 脆弱: sizeof 作用于指针而非数组
char buf[64];
memset(buf, 0, sizeof(buf));  // OK — buf 是数组
char *p = buf;
memset(p, 0, sizeof(p));      // BUG: 只清零 8 字节（指针大小）

// 安全: 显式传入数组大小
memset(p, 0, 64);

// 安全: 使用 sizeof(*ptr)
void clear(struct mytype *p) {
    memset(p, 0, sizeof(*p));
}
```

### 检测模式

```
# === MATCH (触发检测) ===

# realloc(p, 0) — 第二个参数为字面量 0
realloc\s*\(\s*\w+\s*,\s*0\s*\)
                                                       # → MUST: code_context (realloc 调用点)
                                                       # → MUST: judgment_rationale (标准版本 + 释放意图)

# memset(ptr, 0, sizeof(ptr)) — sizeof 作用于指针
memset\s*\(\s*(\w+)\s*,\s*0\s*,\s*sizeof\s*\(\s*\1\s*\)\s*\)
  → ptr 声明 char\s*\*\s*\w+|void\s*\*\s*\w+            # 确认是指针而非数组
                                                       # → MUST: code_context (memset 调用点)
                                                       # → MUST: judgment_rationale (sizeof 语义分析)

# === EXCLUDE (不报告) ===
→ //\s*NOLINT|//\s*secguard:ignore                     # 显式忽略
→ realloc\s*\(.*\)\s*;\s*free                           # 意图明确为释放
→ memset\s*\(\s*\w+\s*\[\s*\]                           # 数组声明
→ memset\s*\(.*\b\d+\b                                  # size 为数字字面量
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| realloc(p, 0) 用于 C11/C23 兼容代码 | C23 起明确等于 free(p) | 确认项目标准声明 `-std=c23` |
| realloc 宏封装（VEC_FREE 等） | 宏封装显示 free 意图 | 确认调用点在宏实现中且周围代码显示释放意图 |
| memset 的 sizeof(ptr) 恰等于 sizeof(\*ptr) | 结构体大小恰等于指针大小 | 确认 sizeof(ptr) == sizeof(\*ptr) 但标记低置信度 |
| memset 在 calloc 之后 | calloc 已归零，memset 冗余 | 确认 memset 前有 calloc 调用 |
| 参数来自 constexpr/宏 | 编译期可确定正确值 | 确认 size 在编译期被正确推导 |

### 修复指引

1. **realloc**：使用 `free(ptr); ptr = NULL;` 替代 `realloc(ptr, 0)`
2. **memset**：对指针使用 `sizeof(\*ptr)`，对数组使用 `sizeof(arr)`。数组作为函数参数退化为指针时由调用者传入大小
3. **编译器警告**：启用 `-Wsizeof-pointer-memaccess` (GCC) 检测 memset sizeof 误用

## Scenario 2: 字符串输出 API 语义误用

### 威胁定义

snprintf 返回值被忽略时，输出截断无法被调用方感知——截断后的数据可能含有不完整的安全相关标记、导致日志不完整掩盖入侵痕迹、或在后续处理中引入缓冲区溢出条件。strncpy 在源字符串长度达到或超过 n 时不自动追加 null 终止符，导致 buf 不是合法 C 字符串——CWE-170（不恰当的字符串终止），后续使用（strlen、printf、strcmp）读到未定义内存。

**核心原则**：snprintf 返回值必须被检查以确认完整输出。strncpy 调用后必须手动设置终止符或使用 C11 `_s` 变体。

### 检测逻辑

#### Step 1: 搜索 snprintf 返回值忽略

定位 `snprintf(buf, size, ...)` 调用——返回值未被赋值或检查：

```c
// 脆弱: 返回值被忽略 — 截断位置未知
snprintf(buf, sizeof(buf), "%s", input);

// 安全: 检查返回值确认无截断
int n = snprintf(buf, sizeof(buf), "%s", input);
if (n < 0 || (size_t)n >= sizeof(buf)) {
    buf[sizeof(buf) - 1] = '\0';
    return -1;
}
```

**变量长度场景**：
```c
int n = snprintf(buf, sizeof(buf), "%s %d", a, b);
// 即使格式固定，locale 设置也可能导致返回值 > sizeof(buf)
```

#### Step 2: 搜索 strncpy 未 null-terminate

定位 `strncpy(buf, src, n)` 调用——其中 n 为 sizeof(buf) 且下一行未显式设置 buf[n-1] = '\0'：

```c
// 脆弱: src 长度 ≥ n 时 buf 不以 '\0' 结尾
char buf[32];
strncpy(buf, source, sizeof(buf));
puts(buf);  // UAF-like: 读到栈上未定义字节

// 安全: 显式设置终止符
strncpy(buf, source, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';

// C11 替代
strncpy_s(buf, sizeof(buf), source, _TRUNCATE);
```

**特殊场景：snprintf(NULL, 0, ...) 查询长度**

```c
// 这是已知安全模式 — 标准用法获取所需缓冲区长度
int needed = snprintf(NULL, 0, "%s", data);
```

### 检测模式

```
# === MATCH (触发检测) ===

# snprintf 返回值被忽略
snprintf\s*\([^;]*\)\s*;                               # 返回值语句被当作表达式语句（未捕获）
  → \w+\s*=\s*snprintf                                  # 排除返回值被捕获的情况
                                                       # → MUST: code_context (snprintf 调用点 + 返回值处理)
                                                       # → MUST: judgment_rationale (截断后果分析)

# strncpy 未 null-terminate
strncpy\s*\(\s*(\w+)\s*,                                # 目标 buf
  → \1\[sizeof\s*\(\s*\1\s*\)\s*-\s*1\]\s*=\s*'\\0'    # 排除已手动终止
                                                       # → MUST: code_context (strncpy 调用点 + 后续行)
                                                       # → MUST: judgment_rationale (终止符检查)

# === EXCLUDE (不报告) ===
→ //\s*NOLINT|//\s*secguard:ignore                     # 显式忽略
→ int\s+\w+\s*=\s*snprintf                              # 返回值被捕获
→ snprintf\s*\(\s*NULL\s*,\s*0                          # 长度查询惯用语
→ \w+\[\s*sizeof\s*\(\s*\w+\s*\)\s*-\s*1\s*\]\s*=\s*'\\0'  # 已手动终止
→ strncpy\s*\([^,]+,\s*""                                # 清零惯用语
→ strncpy_s                                              # C11 安全变体
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| snprintf 格式固定且 buffer 足够大 | 不可能截断 | 确认 snprintf 的格式参数为字面量且估算输出长度 < sizeof(buf) |
| snprintf 仅用于调试日志（局部临时 buffer） | buffer 不暴露给外部 | 确认 buffer 是函数内局部变量且输入非用户可控 |
| strncpy 下一行立即 buf[n-1] = '\0' | 安全模式 | 确认 strncpy 后显式设置了终止符 |
| strncpy(dst, "", n) 清零惯用语 | 语义正确 | 确认 source 参数为 `""` |
| strncpy 的 n < sizeof(buf) 且 n >= strlen(src)+1 | 不会截断，自然终止 | 确认 n 明确小于 sizeof(buf) 且大于源串长度 |
| 工具链自动生成的 API 包装 | 标记为 GENERATED 或 NOLINT | 确认调用点有 GENERATED/NOLINT 注释 |

### 修复指引

1. **snprintf**：始终检查返回值：`int n = snprintf(...); if (n < 0 || (size_t)n >= sizeof(buf)) { /* handle */ }`
2. **strncpy**：调用后手动终止：`buf[sizeof(buf)-1] = '\0'`
3. **替代方案**：使用 `strlcpy`（BSD）、`strncpy_s`（C11）或 `snprintf(dst, sz, "%s", src)`（统一方案）
4. **编译器保护**：启用 `-Wformat-truncation` (GCC 7+) 检测 snprintf 截断

## Scenario 3: 内存拷贝 API 语义误用

### 威胁定义

memcpy 要求源和目标区域不重叠。当区域重叠时，行为是未定义的（undefined behavior），可导致数据损坏和可利用的内存状态。`_s` 变体函数（strcpy_s、memcpy_s、scanf_s）的签名与原始函数不同——参数顺序和约束规则变更——开发者常将参数按原始函数习惯传递导致运行时约束违规被静默处理。

**核心原则**：重叠区域必须使用 memmove 而非 memcpy。`_s` 变体的参数顺序必须遵照规范签名而非原始函数习惯。

### 检测逻辑

#### Step 1: 搜索 memcpy 重叠区域

定位 `memcpy(dst, src, n)` 调用——其中 dst 和 src 的指针算术显示可能重叠：

```c
// 脆弱: 源和目标在同一 buffer 且移动方向导致重叠
memcpy(&arr[1], &arr[0], n);
memcpy(buf + 1, buf, n);

// 安全: 使用 memmove — 保证重叠安全
memmove(&arr[1], &arr[0], n);
memmove(buf + 1, buf, n);
```

**例外说明**：当重叠方向已知且安全（dst < src 且从高地址向低地址移动）时，memcpy 可正确使用。但这种证明需要严格别名分析，超出简单检测范围——一律推荐 memmove。

#### Step 2: 搜索 `_s` 变体参数语义错误

`_s` 变体函数的参数顺序和约束规则与原始函数不同，常见误用：

```c
// 脆弱: 参数顺序错误 — size 位置在 src 参数位上
strcpy_s(dst, src, sizeof(dst));

// 安全: 标准签名 (dst, dst_size, src)
strcpy_s(dst, sizeof(dst), src);

// 脆弱: 传递 0 作为大小
strcpy_s(dst, 0, src);  // 运行时约束处理返回 EINVAL
```

`_s` 函数签名对比：

| 标准函数 | `_s` 替代 | 签名 |
|---------|----------|------|
| strcpy | strcpy_s | `strcpy_s(char *dest, rsize_t destsz, const char *src)` |
| memcpy | memcpy_s | `memcpy_s(void *dest, rsize_t destsz, const void *src, rsize_t count)` |
| scanf | scanf_s | `scanf_s(const char *format, ...)` — 缓冲区大小作为额外参数 |

### 检测模式

```
# === MATCH (触发检测) ===

# memcpy 重叠区域
memcpy\s*\(\s*(\w+\s*\+)\s*\d+\s*,\s*\1                 # 源和目标指针算术指向同一 buffer
                                                       # → MUST: code_context (memcpy 调用点)
                                                       # → MUST: judgment_rationale (重叠分析)

# memcpy 相邻数组元素
memcpy\s*\(\s*&\s*\w+\s*\[\s*\d+\s*\]\s*,\s*&\s*\w+\s*\[\s*\d+\s*\]  # 数组元素复制
  → \1\s*==\s*\2                                         # 同一数组 → 可能重叠
                                                       # → MUST: code_context (数组元素 memcpy)
                                                       # → MUST: judgment_rationale (重叠方向分析)

# _s 变体参数语义 — size 在 src 后
strcpy_s\s*\(\s*\w+\s*,\s*\w+[^,]+,\s*\w+\s*\)         # 三参数 form 但顺序可能有误
  → strcpy_s\s*\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\)
  → sizeof\s*\(\s*\2\s*\)                                # 如果第二个参数(应为 size)不是 sizeof → 可疑
                                                       # → SHOULD: data_flow_path (参数来源追踪)

# === EXCLUDE (不报告) ===
→ //\s*NOLINT|//\s*secguard:ignore                     # 显式忽略
→ memmove\s*\(                                           # 已使用 memmove
→ memcpy_s                                               # 安全变体
→ strcpy_s\s*\(\s*\w+\s*,\s*(sizeof|rsize_t)             # 正确使用 _s 签名
→ \(void\)memcpy                                        # 显式忽略返回值的惯用法
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| memcpy 源和目标通过 restrict 保证不重叠 | 严格别名保证 | 确认两个指针参数明确加上 restrict 限定且无混叠可能 |
| 结构体赋值编译生成的 memcpy | 编译器生成的拷贝行为 | 确认 memcpy 参数来自结构体赋值（a = b）而非用户代码 |
| memcpy 从固定偏移复制自身（a[i] = a[j]） | 同元素操作 | 确认是两个独立元素且索引不重叠 |
| `_s` 包装函数参数映射正确（但与原始函数签名不同） | 包装层做了正确映射 | 确认包装函数 caller 传参映射正确 |
| C++ std::copy / std::copy_n | 标准库实现使用 memmove | 确认使用 C++ 标准算法而非裸 memcpy |

### 修复指引

1. **memcpy**：怀疑重叠时用 `memmove` 替代。memmove 在处理重叠区域时行为定义
2. **`_s` 变体**：严格按照规范签名传递参数——`(dest, dest_size, src)` 顺序不变
3. **编译器保护**：启用 `-Wrestrict` (GCC) 检测 memcpy/memmove 重叠区域
4. **替代方案**：C++ 使用 `std::copy`/`std::copy_n`（内部使用 memmove），C 使用 memmove

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。




**realloc(p, 0)**:


**snprintf 返回值被忽略**:


**strncpy 未 null-terminate**:


**memcpy 重叠**:


**memset 大小错误**:



---

## 取证证据收集指引

### 必须收集 (MUST)
- [ ] **code_context**：API 调用点的完整代码行及其关键参数来源（字面量、sizeof 表达式、变量、宏），标注参数位置和期望语义 → findings.evidence.code_context
- [ ] **judgment_rationale**：参数语义一致性分析——传递的值是否符合 API 形参预期、(realloc zero) 是否意图释放、(memset sizeof) 是否作用于指针而非数组、(snprintf) 返回值是否被检查、(strncpy) 是否手动终止、(memcpy) 是否可能存在重叠 → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：参数从定义/来源到 API 调用点的传递路径——直接传递、sizeof 表达式、算术运算、宏展开 → findings.evidence.data_flow_path
- [ ] **call_stack**：如果 API 调用发生在包装函数中，记录 caller → callee 调用链（最大深度 1） → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：参数值在调用点的实际值——constexpr/宏展开值、sizeof 计算结果、字符串字面量长度 → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：编译选项（-D_FORTIFY_SOURCE、-Wformat-truncation、-Wsizeof-pointer-memaccess、-Wrestrict）、项目 C 语言标准版本（C89/C99/C11/C23） → findings.evidence.sanitizer_analysis
- [ ] **cross_signal_analysis**：当多信号归并分析发生时，记录归并依据和 cross_signal_analysis 标记 → findings.evidence.cross_signal_analysis

## 输出格式

每个 finding 遵循三段式证据链：

1. **问题定位**：API 调用点行号 + 参数语义偏离描述
2. **证据链**：code_context（API 调用点 + 参数来源） + judgment_rationale（语义一致性分析）
3. **分类分级**：severity（high）、CWE-628、scenario 归属

输出模板：
```json
{
  "rule": "api_semantic_misuse",
  "scenario": "内存分配/初始化 API 语义误用 | 字符串输出 API 语义误用 | 内存拷贝 API 语义误用",
  "severity": "high",
  "cwe": "CWE-628",
  "evidence": {
    "code_context": "<API 调用行及参数来源代码>",
    "judgment_rationale": "<参数语义一致性分析结论>",
    "data_flow_path": "<参数来源传递路径>",
    "call_stack": "<跨函数调用链>"
  }
}
```
