---
name: secguard-cpp-assignment_in_condition
description: "检测 C/C++ 中赋值表达式作为 if/while 条件顶层（疑似 == 误写为 =）"
category: language-specific
language: cpp
topic: [semantic, correctness]
skill_id: semantic.assignment_in_condition
signal_filter: semantic.assignment_in_condition*
signal_source: suspicious_expressions[kind="assignment_in_condition"]
severity: high
cwe: [CWE-480, CWE-481]
---

# assignment_in_condition 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `semantic.assignment_in_condition` |
| signal_source | `suspicious_expressions[kind="assignment_in_condition"]`（引擎 S11 信号） |
| 默认严重度 | High |
| CWE | CWE-480 (传值替代比较) / CWE-481 (赋值代替比较) |

## 威胁定义

`if (x = 5)` 把赋值 `=` 误写为比较 `==`：条件恒为赋值结果（非零即真），导致分支逻辑错误、绕过校验、或意外改写变量。这是 C/C++ 经典低级错误，传统 SAST 的基础检测项——引擎通过 Tree-sitter AST 直接识别"条件顶层是 assignment_expression"，LLM 不可漏。

## 引擎信号（S11，确定性检出）

引擎在 `suspicious_expressions[kind="assignment_in_condition"]` 中给出：if/while 条件的 parenthesized_expression 的**顶层**子节点是 `assignment_expression`。

**关键：仅顶层赋值才报**。以下写法不报（赋值被包裹，属刻意）：
- `if ((x = foo()) != 0)` — 顶层是 `!=` 比较表达式，赋值在括号内（常见惯用法）
- `if ((x = foo()))` — 顶层是 parenthesized_expression 包裹的赋值（已显式括号）

## 危险模式（CONFIRMED）

```c
if (x = 5) { ... }       // 恒真，本意 x == 5
while (p = next()) {}    // 本意 p == next()；若 next() 返回非零则死循环
if (status = ERROR) {}   // 本意 status == ERROR；status 被覆盖
```

## 安全模式（SUPPRESS，刻意赋值）

```c
if ((x = foo()) != 0) { ... }   // 赋值 + 判空，C 惯用法，显式括号
while ((c = getchar()) != EOF) {} // 惯用法
```

## Q-matrix 判定（Fact-Anchor Reflection）

```json
{
  "Q1_defect_exists": true|false,   // 是真实缺陷（非刻意惯用法）
  "Q2_exploitable": true|false,     // 可达且导致逻辑错误/校验绕过
  "Q3_mitigation_exists": true|false // 有显式括号包裹或上下文证明刻意
}
```

**极性（Q1/Q2 Yes=危险，Q3 Yes=安全，自洽）**：

| Q1 缺陷真实 | Q2 可利用 | Q3 有缓解 | 判决 |
|------------|----------|----------|------|
| No | — | — | SUPPRESS（惯用法/误报）|
| Yes | — | Yes | SUPPRESS（显式括号/已缓解）|
| Yes | Yes | No | **CONFIRMED**（High）|
| Yes | No | No | CONFIRMED（Medium，潜在逻辑错误）|

**锚定要求**：判决必须在 evidence 中引用引擎信号行号 + 代码片段，并回答 Q1（是否刻意惯用法，看有无括号/赋值结果是否被使用）。
