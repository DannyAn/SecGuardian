---
detector: integer-overflow
severity: high
cwe: CWE-190
language: [c, cpp]
tags: [arithmetic, allocation, size-check-bypass]
precision: medium
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "memory.integer-overflow",
  "type": "guard-rule",
  "namespace": "memory",
  "severity": "High",
  "cwe": "CWE-190",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "medium",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "compute",
    "get_user_input",
    "malloc",
    "memcpy"
  ],
  "match_patterns": [],
  "exclude_patterns": [],
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

算术运算结果超出整数类型范围导致回绕（wrap-around）或未定义行为（有符号溢出）。攻击者常利用溢出绕过大小检查，导致后续缓冲区溢出。C/C++ 中无符号溢出按标准回绕（但仍可导致安全问题），有符号溢出是未定义行为。

**核心原则：影响分配大小或安全检查的算术运算必须做溢出防护。** 不涉及内存安全/边界检查的纯计算溢出不是本 detector 的范围。

## 检测逻辑 (Detection Logic)

### Step 1: 内存分配中的乘法溢出 — 报告

```c
// 必须报告：count * sizeof(T) 可能溢出
buf = malloc(count * sizeof(item_t));
// 正确：malloc(count * size) 前检查 if (count > SIZE_MAX / size)

// 不报告：编译期常量
buf = malloc(256 * sizeof(int));  // 256 为常量，可验证安全
```

### Step 2: 边界检查被绕过 — 报告

```c
// 报告：先溢出再检查
size_t total = count * size;    // 可能已回绕为极小值
if (total > MAX) return ERROR;  // 检查无效！
malloc(total);                   // 如果 total 溢出后 < MAX 则分配不足

// 不报告：先检查后计算
if (count > SIZE_MAX / size) return ERROR;
size_t total = count * size;    // 安全：已验证不会溢出
```

### Step 3: 类型转换陷阱 — 报告

```c
// 报告：有符号 → 无符号（负数变极大值）
int n = get_user_input();    // 可为负数
memcpy(dst, src, (size_t)n); // n = -1 → size_t = 18446744073709551615

// 报告：有符号溢出（UB）
int offset = compute();
if (offset + size > MAX) ... // offset + size 有符号溢出是 UB，编译器可删除检查

// 不报告：已验证在范围内
if (n < 0) return ERROR;
memcpy(dst, src, (size_t)n); // n 已确认为非负
```

### Step 4: 循环终止条件 — 报告

```c
// 报告：无符号永远 >= 0
for (size_t i = len; i >= 0; i--)  // 无限循环！

// 报告：可能永不满足终止条件
for (size_t i = 0; i <= SIZE_MAX; i++)  // 不会停止
```

## 修复指引 (Remediation)

1. **乘法前检查**：`if (a > SIZE_MAX / b) return ERR_OVERFLOW;`
2. **编译器内置**：`__builtin_mul_overflow(a, b, &result)` (GCC/Clang)
3. **C23 标准**：使用 `<stdckdint.h>` 中的 `ckd_mul`/`ckd_add`
4. **C++**：使用 Boost.SafeNumerics 或在关键路径上显式检查

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：存在算术运算的分配/边界检查代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：溢出是否影响内存安全边界
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：变量从赋值到用于分配/检查的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：算术运算→分配/检查的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：操作数值/类型/溢出检查结果
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用-fsanitize=integer或UBSan
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| 编译期常量运算 | 编译器可验证 `malloc(256 * sizeof(int))` | 确认乘法操作数均为编译期字面量或 `sizeof` 表达式，无运行时变量参与 |
| `__builtin_mul_overflow` 等 checked 函数 | 已做溢出检查 | 确认使用了 GCC/Clang builtin 溢出检查函数，且正确处理了返回值 |
| 已验证 `a <= SIZE_MAX / b` | 前置检查保证安全 | 确认在乘法/加法运算前存在显式的除法检查，且条件正确覆盖所有路径 |
| 非分配/非边界场景的纯计算溢出 | 不是本 detector 范围（可能影响业务逻辑但不影响内存安全） | 确认溢出结果不用于 malloc/new、数组索引、memcpy长度、边界比较等内存安全操作 |
| `size_t` + `size_t` 回绕不用于安全判定 | 不影响内存安全边界 | 确认回绕值仅用于日志/统计等非安全关键路径，不参与内存操作 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# malloc/calloc/new 的乘法参数无溢出检查 → evidence: code_context
(malloc|calloc|new)\s*\([^)]*\*\s*sizeof
→ 同作用域内无 (a > SIZE_MAX / b|__builtin_mul_overflow|ckd_mul)
→ evidence: judgment_rationale (记录缺失的检查类型)

# 先溢出后检查（检查顺序错误）→ evidence: variable_state
\w+\s*=\s*\w+\s*\*\s*\w+;\s*$          # 乘法结果赋值
→ if\s*\(.*>\s*MAX                     # 后续检查（但溢出已发生）
→ evidence: data_flow_path (记录从乘法到检查的代码顺序)

# 有符号值直接转为 size_t 用于 memcpy/malloc → evidence: code_context
int\s+\w+\s*=\s*(?!.*if.*< 0).*          # 有符号变量
→ memcpy\([^)]*\(\s*size_t\s*\)\1|malloc\(\1  # 转为无符号用于大小
→ evidence: variable_state (记录有符号变量的可能取值范围)
```

### 排除模式 (EXCLUDE)

```
# 编译期常量 → evidence: code_context
malloc\(256\s*\*\s*sizeof\(|malloc\(1024\s*\*\s*sizeof\(

# checked 函数 → evidence: sanitizer_analysis
__builtin_mul_overflow|__builtin_add_overflow|ckd_mul|ckd_add

# 前置溢出检查 → evidence: judgment_rationale
if\s*\(.*>\s*SIZE_MAX\s*/\s*.*\).*\n.*malloc|calloc

# 纯计算溢出不涉及内存安全 → evidence: judgment_rationale
# 溢出结果仅用于非安全路径（日志/统计/显示）
```
