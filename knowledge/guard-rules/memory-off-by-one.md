---
detector: off-by-one
severity: high
cwe: CWE-193
language: [c, cpp]
tags: [memory, boundary, logic-error]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "memory.off-by-one",
  "type": "guard-rule",
  "namespace": "memory",
  "severity": "High",
  "cwe": "CWE-193",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "arr",
    "buf",
    "code_context",
    "data_flow_path",
    "judgment_rationale",
    "memset",
    "ptr",
    "strcpy",
    "strlen",
    "strncpy",
    "variable_state"
  ],
  "match_patterns": [
    "for.*<=.*sizeof|for.*<=.*len|for.*<=.*count              # 正向循环边界差一",
    "for.*i = .*; i >= 0; i--                                 # 倒序循环（i >= 0 可能最终写入 arr[-1]）",
    "char \\*ptr = ...|void \\*ptr = ...|T \\*ptr = ...           # 指针声明",
    "strlen(src) + 分配大小                                     # 可疑：检查是否少分配了1字节",
    "strncpy\\(dst, src, sizeof\\(dst\\)\\)                         # 可能不写 null 终止符"
  ],
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

缓冲区操作中边界计算差一（`<=` 而非 `<`），导致写入刚好一个字节越界。这一字节可覆盖相邻堆块的 size 字段或栈帧的保存 EBP，实现控制流劫持。

**核心原则：循环边界和大小计算必须精确验证。特别关注 `<=` vs `<` 和 null 终止符额外占用的一字节空间。**

## 检测逻辑 (Detection Logic)

### Step 1: 循环边界检查 (Loop Boundary Analysis)

```c
// BAD: <= 导致越界
char buf[64];
for (int i = 0; i <= 64; i++)    // 应该是 i < 64
    buf[i] = 0;                   // 最后一次迭代 buf[64] 越界

// BAD: 倒序循环
for (int i = n; i >= 0; i--)      // 应该是 i > 0 或 i >= 1
    arr[i] = arr[i-1];
```

### Step 2: 字符串操作 (String Operations)

```c
// BAD: strlen 不包含 '\0'
char *src = "hello";              // strlen=5
char dst[5];                      // 需要 6 字节 (5 + null)
strcpy(dst, src);                 // 溢出 1 字节！

// GOOD:
char dst[6];
strcpy(dst, src);
```

### Step 3: memcpy/memset 大小计算 (memcpy/memset Size Calculation)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：越界写入点的完整代码，包含缓冲区声明（类型+大小）、循环/操作边界表达式（`<=` vs `<`）、写入操作语句的三者对照
      → findings.evidence.code_context
- [ ] **judgment_rationale**：精确计算缓冲区字节大小 vs 写入操作覆盖的最大索引——对于 `i <= N` 覆盖 N+1 个元素，数组大小为 N 时最后一个元素索引为 N-1；对于 strlen 场景，说明是否需要 +1 存放 '\0'
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：缓冲区从声明/分配 → 循环/操作写入 → 后续读取使用的完整生命期，标注溢出字节会覆盖哪个相邻内存区域（栈上相邻变量、堆块元数据）
      → findings.evidence.data_flow_path
- [ ] **call_stack**：缓冲区所在函数 → 调用者，确认缓冲区是栈分配、堆分配还是全局数组
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：缓冲区大小（字节）、边界表达式的最大值、实际写入的元素数量、相邻变量的内存布局（栈帧中 buf 与 saved EBP/return address 的偏移）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：ASan (AddressSanitizer) 输出、编译器 -Warray-bounds / -Wstringop-overflow 诊断、Fortify Source 运行时检测
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **循环条件**：始终使用 `<` 而非 `<=`，除非显式验证数组大小
2. **字符串空间**：`char buf[N]` 最多存储 `N-1` 个字符 + `\0`
3. **strncpy 注意**：不保证 null 终止，需手动 `buf[N-1] = '\0'`
4. **代码审查**：关注所有 `>=`/`<=` 循环边界和 `sizeof()` 计算

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `strncpy` + 手动 null 终止 | 代码在 strncpy 后显式设置了 `buf[sizeof(buf)-1] = '\0'` | 确认 strncpy 后紧跟 null 终止赋值语句 |
| 循环边界为 `sizeof(array)/sizeof(array[0])` | 编译期常量计算，表达式结果等于数组元素个数，配合 `<` 使用时自然正确 | 确认边界表达式使用 sizeof 计算且运算符为 < |
| sentinel 标记结尾 | 缓冲区末尾使用显式终止符（如 0/NULL/-1）标记有效数据结束 | 确认 sentinel 值在缓冲区最后一个有效位置，且读取方检查 sentinel |
| 零长度/空数组边缘情况 | 当数组长度为 0 时，`< 0` 等于 never-true，行为正确 | 确认 N=0 时有合理的控制流处理（提前返回或跳过循环） |
| 循环条件是 `i < sizeof(buf)` | sizeof 返回字节数，数组大小 = 字节数时 `i < sizeof(buf)` 等价于 `i < N` | 确认 buf 为 char/byte 数组，sizeof(buf) = 元素个数 |
| 倒序循环 `i >= 0` 但 i 为有符号且循环体用 `arr[i-1]` | 实际写入在 i >= 2 时发生，边界恰好正确 | 逐项分析写入索引最小值，确认不会访问 arr[-1] 或 arr[N] |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# <= 代替 < (正向循环越界)
for.*<=.*sizeof|for.*<=.*len|for.*<=.*count              # 正向循环边界差一
                                                          # → MUST: code_context (声明+边界+写入三对照)
→ buf\[i\]|arr\[i\]|ptr\[i\]                              # 数组写入操作
                                                          # → MUST: judgment_rationale (精确边界计算)

# 倒序循环边界错误
for.*i = .*; i >= 0; i--                                 # 倒序循环（i >= 0 可能最终写入 arr[-1]）
→ arr\[i\]|buf\[i\]                                        # → SHOULD: data_flow_path (溢出字节影响分析)

# sizeof 指针陷阱
char \*ptr = ...|void \*ptr = ...|T \*ptr = ...           # 指针声明
→ sizeof(ptr)                                             # 指针大小 (8字节) 而非数组大小
                                                          # → MAY: variable_state (内存布局)

# strlen + 边界
strlen(src) + 分配大小                                     # 可疑：检查是否少分配了1字节
→ (分配空间 <= strlen(src))                                # 没有 +1 放 '\0'
→ malloc\(strlen\(|new char\[strlen\(                     # 直接使用 strlen 作分配大小

# strncpy 无 null 终止
strncpy\(dst, src, sizeof\(dst\)\)                         # 可能不写 null 终止符
→ (无 dst\[sizeof\(dst\)-1\] = '\\0')                      # 缺少手动终止

# === EXCLUDE (不报告) ===
→ strncpy.*\n.*\[sizeof.*- 1\] = '\\0'                   # strncpy + 手动null终止
→ for.*< sizeof\(.*\)/sizeof\(                             # sizeof除法表达式 + < 运算符
→ dst\[sizeof\(dst\)-1\] = '\\0'                          # 显式null终止
→ i >= 1.*arr\[i-1\]|i > 0.*arr\[i-1\]                    # 倒序循环边界正确（i >= 1 配合 arr[i-1]）
→ if \(n == 0\) return|if \(len <= 0\) return              # 零长度显式处理
→ buf\[sizeof\(buf\)-1\] = 0|buf\[sizeof\(buf\)-1\] = NULL # sentinel终止符
```
