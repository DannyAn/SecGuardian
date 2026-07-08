---
name: secguard-cpp-integer_overflow
description: "Detect integer overflow/wraparound in allocation-size arithmetic and boundary checks"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# Integer Overflow 检视算子

## 元数据

- id: memory.integer_overflow
- severity: critical
- cwe: CWE-190
- category: memory
- signal_source: call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: `malloc`, `calloc`, `realloc`, `aligned_alloc`, `memcpy`, `memmove`, `memset`, `new`
- 按信号分组: 优先处理 callee 参数中包含 `*` 或 `+` 算术表达式的分配调用，其次是 callee 参数为有符号变量的分配调用

## 检视协议

### Step 1: 信号确认
对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在，且第三个参数或参数中包含乘法/加法/减法运算

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: 用户输入、网络数据、文件大小、循环索引、配置值等外部可控的整数值
- Propagate: 算术运算（`a * b`, `a + b`, `a - b`, `a << b`）将上述值传播到分配大小或边界检查
- Sink: 分配函数（malloc/calloc/realloc/new）的参数、memcpy 的 size 参数、数组索引、边界检查的右值

### Step 3: 安全变体参数审计
1. 检查乘法操作数是否均为编译期常量或 sizeof 表达式 — 如是则不报告
2. 检查算术表达式前是否存在溢出防护: `if (a > SIZE_MAX / b)` 或 `__builtin_mul_overflow` 等
3. 检查有符号变量在用于 size 参数前是否已做非负验证: `if (n < 0) return ERROR;`
4. 检查无符号整型参与运算时可能产生回绕的路径
5. 确认溢出结果不会绕过安全检查: `if (total > MAX) return ERROR;` — 如果 total 已回绕则为假安全

### Step 4: 跨函数补证
Max depth 1, beyond → downgrade to suspicious
- 追踪分配大小的源变量是否从被调用函数返回
- 检查被调用函数中是否存在溢出防护
- 如果数据流跨越更多层且无显式保护，标记为 suspicious 而非 confirmed

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 运算结果用于内存分配或缓冲区大小?
**Q2**: 参与运算的操作数中有不可信输入?
**Q3**: 运算前有溢出检查（如 __builtin_mul_overflow）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

