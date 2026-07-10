---
name: secguard-cpp-operator_precedence
description: "检测 C/C++ 中因运算符优先级导致的可疑表达式（位运算与比较混用、移位与算术混用且无括号）"
category: language-specific
language: cpp
topic: [semantic, correctness]
skill_id: semantic.operator_precedence
signal_filter: semantic.operator_precedence*
signal_source: suspicious_expressions[kind="operator_precedence"]
severity: medium
cwe: [CWE-783]
---

# operator_precedence 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `semantic.operator_precedence` |
| signal_source | `suspicious_expressions[kind="operator_precedence"]`（引擎 S11 信号） |
| 默认严重度 | Medium |
| CWE | CWE-783 (运算符优先级错误) |

## 威胁定义

C 运算符优先级常违反直觉，最经典两类：
- **位运算（`&` `^` `|`）比比较（`==` `!=` `<`）优先级低**：`if (flags & 0x1 == 0)` 实际是 `flags & (0x1 == 0)` = `flags & 0` = `0`，恒假，本意 `(flags & 0x1) == 0`。常导致权限/标志位校验失效。
- **移位（`<<` `>>`）比算术（`+` `-`）优先级低**：`a + b << c` 实际 `(a + b) << c`，本意可能 `a + (b << c)`。常导致地址/长度计算错误。

引擎通过 Tree-sitter AST 识别"外层低优先级运算符包裹内层高优先级运算符且无括号"。

## 引擎信号（S11）

仅对**经典误用对**报（避免对正常算术 `a + b * c` 噪声）：
- 外层 `&`/`^`/`|` + 内层 `==`/`!=`/`<`/`>`/`<=`/`>=`
- 外层 `<<`/`>>` + 内层 `+`/`-`

## 危险模式（CONFIRMED）

```c
if (flags & 0x1 == 0) {}        // 恒假，权限校验失效
if (mask | 0xFF == 0xFF) {}     // | 低于 ==，恒真
addr = base + offset << 2;      // (base+offset)<<2，本意 base+(offset<<2)
```

## 安全模式（SUPPRESS）

```c
if ((flags & 0x1) == 0) {}      // 显式括号，正确
addr = base + (offset << 2);    // 显式括号
```

## Q-matrix 判定

```json
{
  "Q1_defect_exists": true|false,   // 优先级确被误用（非刻意）
  "Q2_exploitable": true|false,     // 影响安全校验/地址计算（非纯无副作用）
  "Q3_mitigation_exists": true|false // 有显式括号或上下文证明结果正确
}
```

| Q1 缺陷真实 | Q2 可利用 | Q3 有缓解 | 判决 |
|------------|----------|----------|------|
| No | — | — | SUPPRESS（刻意的低优先级组合）|
| Yes | — | Yes | SUPPRESS（已加括号/结果正确）|
| Yes | Yes | No | **CONFIRMED**（Medium-High，校验失效升 High）|
| Yes | No | No | CONFIRMED（Medium，潜在计算错误）|

**锚定要求**：引用引擎信号行号 + 实际解析的括号结构，回答 Q1（程序员本意是否即当前结合）。
