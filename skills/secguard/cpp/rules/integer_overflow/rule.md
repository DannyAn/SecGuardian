---
name: secguard-cpp-integer_overflow
description: "Detect integer overflow/wraparound in allocation-size arithmetic and boundary checks"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.integer
signal_filter: memory.integer*
signal_source: call_sites[cat="memory"]
severity: critical
cwe: [CWE-190]
---

# integer_overflow 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.integer` |
| signal_filter | `memory.integer*`（供 `secguard ./src c memory.integer` 过滤匹配） |
| signal_source | `call_sites[cat="memory"]` |
| 默认严重度 | Critical |

---

## Scenario 1: 分配大小中的乘法/移位溢出（CWE-190）

### 威胁定义

算术运算结果超出整数类型范围导致回绕（wrap-around）或未定义行为（有符号溢出）。攻击者常利用乘法或移位运算的溢出，使内存分配结果远小于实际需求，导致后续缓冲区溢出。C/C++ 中无符号溢出按标准回绕（但仍可导致安全问题），有符号溢出是未定义行为。

**核心原则：影响分配大小或安全检查的算术运算必须做溢出防护。** 不涉及内存安全/边界检查的纯计算溢出不是本 Scenario 的范围。

### 检测逻辑

**Step 1: 识别分配调用中的乘法/移位**

```c
// 必须报告：count * sizeof(T) 可能溢出
item_t *arr = malloc(count * sizeof(item_t));

// 必须报告：width * height 可回绕为极小值
pixels = malloc(width * height * 3);

// 必须报告：n + 1 可回绕（n == SIZE_MAX）
char *copy = malloc(n + 1);

// 必须报告：大移位可溢出或 UB
bitmap = calloc(1, 1 << shift);        // shift >= 64 在 64 位上是 UB

// 不报告：编译期常量
buf = malloc(256 * sizeof(int));
```

**Step 2: 确认无溢出保护**

检查同作用域内是否存在前置保护：

```c
// 正确：if (a > SIZE_MAX / b) 前置检查
if (count > SIZE_MAX / sizeof(item_t)) return ERR_OVERFLOW;
item_t *arr = malloc(count * sizeof(item_t));

// 正确：__builtin_mul_overflow
size_t total;
if (__builtin_mul_overflow(count, sizeof(item_t), &total)) return ERR_OVERFLOW;
item_t *arr = malloc(total);

// 正确：C23 ckd_mul
if (ckd_mul(&total, count, sizeof(item_t))) return ERR_OVERFLOW;
item_t *arr = malloc(total);

// 正确：reallocarray 内部安全
item_t *arr = reallocarray(NULL, count, sizeof(item_t));
```

**Step 3: 移位溢出检查**

```c
// 正确：移位量检查 + 无符号类型
if (shift >= sizeof(size_t) * CHAR_BIT) return ERROR;
size_t size = (size_t)1 << shift;
```

### 检测模式

```
# MATCH（触发检测）
malloc/calloc/realloc 参数中包含 * 或 + 或 << 运算，且操作数中含有运行时变量
→ 同作用域内无 (a > SIZE_MAX / b | __builtin_mul_overflow | ckd_mul | __builtin_add_overflow)

# EXCLUDE（不报告）
编译期常量运算   → 所有操作数均为字面量或 sizeof 表达式
前置溢出检查     → 乘法前 10 行内存在 if (a > SIZE_MAX / b) 等效保护
checked 函数     → __builtin_mul_overflow / __builtin_add_overflow / ckd_mul / ckd_add
reallocarray     → 内部已安全处理溢出
calloc(n, size)  → 内部已安全处理溢出
```

### 修复指引

1. **乘法前检查**：`if (a > SIZE_MAX / b) return ERR_OVERFLOW;`
2. **编译器内置**：`__builtin_mul_overflow(a, b, &result)` (GCC/Clang)
3. **C23 标准**：`ckd_mul(&result, a, b)` / `ckd_add(&result, a, b)`（`<stdckdint.h>`）
4. **C++**：使用 Boost.SafeNumerics 或在关键路径上显式检查
5. **移位操作**：验证移位量 `< sizeof(type) * CHAR_BIT`，使用无符号类型

---

## Scenario 2: 加法/减法绕过边界检查（CWE-190）

### 威胁定义

边界检查中执行加法或减法运算时，如果操作数之和发生回绕，可能导致检查通过但实际内存操作越界。此模式尤其危险，因为检查代码看似正确，但溢出使条件判断失效。

**核心原则：作为边界检查条件的算术运算必须防止溢出。** 在比较之前将减法转换为 size 检查，或在加法前使用 checked 语义。

### 检测逻辑

**模式 1：加法回绕绕过检查**

```c
// 必须报告：offset + len 可回绕 → 检查通过但 memcpy 越界
if (offset + len > buf_size) return;      // wrap: offset + len < buf_size
memcpy(buf + offset, src, len);           // bypassed!

// 正确：检查在加法之前
if (len > buf_size - offset) return;
memcpy(buf + offset, src, len);

// 正确：使用 __builtin_add_overflow
size_t end;
if (__builtin_add_overflow(offset, len, &end)) return;
```

**模式 2：减法下溢**

```c
// 必须报告：data_len - header_len 可下溢为极大值
if (data_len - header_len > MAX_PAYLOAD) return;   // underflow!
process(data, data_len - header_len);

// 必须报告：size_t 减法后赋值
char *body = payload + header_len;
size_t body_len = total_len - header_len;           // total < header 则 underflow

// 正确：减法前检查
if (data_len < header_len) return;
if (data_len - header_len > MAX_PAYLOAD) return;
```

**模式 3：先溢出后检查（最危险的误报源）**

```c
// 报告：乘法结果赋值后检查——检查已无效
size_t total = count * size;    // 可能已回绕为极小值
if (total > MAX) return ERROR;  // 检查无效！
malloc(total);                   // 如果 total 溢出后 < MAX 则分配不足

// 不报告：先检查后计算
if (count > SIZE_MAX / size) return ERROR;
size_t total = count * size;    // 安全：已验证不会溢出
```

**特别注意**：不要将"检查后操作"误判为安全。当 `n = SIZE_MAX / sizeof(T) + 1` 时，`total ≈ 0`，若 `MAX_BUF = 100`，则 `0 > 100` 为 FALSE——检查被绕过。**这是真正的漏洞，不是误报。**

### 检测模式

```
# MATCH（触发检测）
加法/减法结果直接用作边界检查条件，操作数中含运行时变量
→ 同作用域内无 (__builtin_add_overflow | __builtin_sub_overflow | ckd_add | ckd_sub)
→ 操作数均为无符号类型可能存在回绕

减法下溢：size_t 变量 = size_t - size_t（无前置被减数 ≥ 减数检查）
→ 结果用于数组索引、memcpy 长度、边界比较

先溢出后检查：乘法/加法结果赋值 → 后续 if (result > LIMIT) 检查
→ 但溢出已发生在赋值时，检查基于回绕后的无效值

# EXCLUDE（不报告）
减法前有 if (a < b) return / if (a <= b) return 保护
加法前有 len > buf_size - offset 等效检查
使用 checked 算术 builtins
非安全关键路径中的溢出（仅用于日志/统计）
```

### 修复指引

1. **边界检查**：从减法改为 `if (len > buf_size - offset) return;`
2. **加法**：使用 `__builtin_add_overflow(offset, len, &end)` 或 C23 `ckd_add`
3. **减法**：始终在减法前验证 `if (a < b) return;`，再 `a - b`
4. **顺序原则**：先检查后计算，绝不可先计算再检查

---

## Scenario 3: 符号/类型转换陷阱（CWE-190）

### 威胁定义

有符号整数在用于内存大小参数时被（显式或隐式）转换为无符号整数。负数转换为 `size_t` 后变为极端大值（如 -1 → 18446744073709551615），导致 memcpy/malloc 实际操作超大缓冲区。有符号溢出本身是未定义行为，编译器可优化掉依赖其结果的检查。

**核心原则：用于 size 参数的整型必须是非负的。** 有符号转无符号必须验证非负；有符号算术不能发生溢出。

### 检测逻辑

**模式 1：有符号 → size_t 直接转换**

```c
// 必须报告：负数变为极大 size_t
int n = get_user_input();            // 攻击者提供 -1
memcpy(dst, src, (size_t)n);         // size_t(-1) = 18446744073709551615

// 正确：前有负值验证
int n = get_user_input();
if (n < 0) return ERROR;
memcpy(dst, src, (size_t)n);
```

**模式 2：有符号算术溢出（UB）**

```c
// 必须报告：有符号加法 UB，编译器可删除检查
int offset = compute_offset();
if (offset + size > MAX) return;     // 若 offset = INT_MAX, INT_MAX+1 是 UB

// 正确：使用 size_t 类型
size_t n = (size_t)get_unsigned_input();
if (n > buf_size) return ERROR;
```

**模式 3：有符号循环变量导致无限循环**

```c
// 必须报告：size_t 做循环递减
for (size_t i = len; i >= 0; i--)  // 无符号永远 >= 0 → 无限循环！

// 必须报告：size_t 循环终止条件永不满足
for (size_t i = 0; i <= SIZE_MAX; i++)  // 不会停止
```

### 检测模式

```
# MATCH（触发检测）
有符号 int/long 直接 cast 为 (size_t) 用于 memcpy/malloc/calloc/realloc 的 size 参数
→ 同一作用域内无负值验证 (if (x < 0) return)

有符号 + 有符号的算术结果用于边界检查条件
→ 操作数非编译期常量

size_t 类型循环变量使用 i >= 0 终止条件（永远为真）

# EXCLUDE（不报告）
有符号变量已验证非负后转为 size_t
从起点即使用 size_t 类型（非从有符号转换而来）
循环使用 i > 0 终止条件
```

### 修复指引

1. **类型选择**：从源头使用 `size_t` 而非 `int` 表示大小
2. **转换检查**：`if (n < 0) return ERROR;` 后转 `(size_t)n`
3. **循环边界**：`for (size_t i = len; i > 0; i--)` 而非 `i >= 0`
4. **有符号算术**：避免有符号整数的乘法/加法结果用于安全检查

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。



---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：存在算术运算的分配/边界检查代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：溢出是否影响内存安全边界
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：变量从赋值到用于分配/检查的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：算术运算→分配/检查的调用链
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：操作数值/类型/溢出检查结果
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用 `-fsanitize=integer` 或 UBSan
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "外部输入 count 无范围限制，来自网络解析", "file": "src/network.c", "line": 42},
    "propagate": {"description": "count * sizeof(item_t) 无溢出保护，可回绕为极小值", "file": "src/network.c", "line": 45},
    "sink": {"description": "malloc(count * sizeof(item_t)) 分配不足，后续写入越界", "file": "src/network.c", "line": 45}
  },
  "scenario": "Scenario 1: 分配大小中的乘法溢出",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
