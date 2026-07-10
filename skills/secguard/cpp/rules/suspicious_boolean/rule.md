---
name: secguard-cpp-suspicious_boolean
description: "检测 C/C++ 中可疑布尔构造（对赋值取反、布尔运算符含赋值操作数）"
category: language-specific
language: cpp
topic: [semantic, correctness]
skill_id: semantic.suspicious_boolean
signal_filter: semantic.suspicious_boolean*
signal_source: suspicious_expressions[kind="suspicious_boolean"]
severity: high
cwe: [CWE-480, CWE-358]
---

# suspicious_boolean 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `semantic.suspicious_boolean` |
| signal_source | `suspicious_expressions[kind="suspicious_boolean"]`（引擎 S11 信号） |
| 默认严重度 | High |
| CWE | CWE-480 (传值替代比较) / CWE-358 (条件包含赋值) |

## 威胁定义

布尔上下文中的可疑赋值，常因 `=`/`==` 混写或优先级误判：
- **对赋值取反**：`if (!x = y)` 实际 `!(x = y)`（赋值后取反），本意 `(!x) == y` 或 `(x != y)`。
- **布尔运算符含赋值操作数**：`if (a && b = c)` 实际 `a && (b = c)`，本意 `a && (b == c)`。

这类错误改变控制流，常致校验绕过或逻辑反转。

## 引擎信号（S11，确定性检出）

引擎在 `suspicious_expressions[kind="suspicious_boolean"]` 中给出：
- `unary_expression`（`!`/`~`）的操作数是 `assignment_expression`
- `binary_expression`（`&&`/`||`）的操作数是 `assignment_expression`

## 危险模式（CONFIRMED）

```c
if (!x = y) {}        // !(x=y)，本意 (!x)==y 或 x!=y
if (a && b = c) {}    // a && (b=c)，本意 a && (b==c)
if (a || b = c) {}    // a || (b=c)，本意 a || (b==c)
```

## 安全模式（SUPPRESS）

```c
if (!x) {}                  // 纯取反，无赋值
if (a && b) {}              // 纯布尔，无赋值
if (!(x = foo())) {}        // 刻意：对赋值结果取反（少见但合法，需上下文确认）
```

## Q-matrix 判定

```json
{
  "Q1_defect_exists": true|false,   // 确为可疑布尔构造且非刻意
  "Q2_exploitable": true|false,     // 改变控制流/致校验绕过
  "Q3_mitigation_exists": true|false // 括号/上下文证明刻意
}
```

| Q1 缺陷真实 | Q2 可利用 | Q3 有缓解 | 判决 |
|------------|----------|----------|------|
| No | — | — | SUPPRESS（纯布尔/刻意取反赋值结果）|
| Yes | — | Yes | SUPPRESS（已括号/上下文证明）|
| Yes | Yes | No | **CONFIRMED**（High，控制流反转）|
| Yes | No | No | CONFIRMED（Medium，潜在逻辑错误）|

**锚定要求**：引用引擎信号 + 实际布尔结构，回答 Q1（程序员本意是否含赋值）。
