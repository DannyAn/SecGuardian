---
name: secguard-cpp-signed_unsigned_compare
description: "检测 C/C++ 中有符号数与无符号数的比较（负数被提升为巨大无符号数致比较错误）"
category: language-specific
language: cpp
topic: [semantic, integer]
skill_id: semantic.signed_unsigned
signal_filter: semantic.signed_unsigned*
signal_source: suspicious_expressions[kind="signed_unsigned_compare"]
severity: high
cwe: [CWE-194, CWE-196]
---

# signed_unsigned_compare 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `semantic.signed_unsigned` |
| signal_source | `suspicious_expressions[kind="signed_unsigned_compare"]`（引擎 S11 信号） |
| 默认严重度 | High |
| CWE | CWE-194 (意外符号转换) / CWE-196 (有符号到无符号转换错误) |

## 威胁定义

C 整数提升规则：有符号数与无符号数比较时，有符号数被隐式转为无符号。若该数为负，转为巨大无符号值，导致比较结果反转：
```c
int s = -1; unsigned u = 5;
if (s < u) { }   // false！-1 转为 UINT_MAX，> 5
```
常致循环边界/长度校验/数组越界检查失效，是缓冲区溢出的常见前置。

## 引擎信号（S11，常见情形）

引擎在 `suspicious_expressions[kind="signed_unsigned_compare"]` 中识别：比较运算符（`<` `>` `<=` `>=` `==` `!=`）的两操作数中，一为 signed 类型、一为 unsigned 类型。类型来自 S3 Declarations。

**根技术限制（诚实）**：仅当两操作数均为**简单标识符**且其声明类型已知时检出。复杂表达式（函数返回值、数组下标、运算结果）的类型需类型推断，是未来根技术增强项（DFG/类型系统）。本规则覆盖最常见的"变量 vs 变量""变量 vs 类型化字面量"情形。

## 危险模式（CONFIRMED）

```c
int len; unsigned size;
if (len < size) {}            // len<0 时反转，越界检查失效
for (int i = 0; i < count; i++) {}  // count 为 unsigned 且 i 为 int（循环比较）
if (signed_ret < sizeof(buf)) {}   // sizeof 返回 size_t（无符号）
```

## 安全模式（SUPPRESS）

```c
if ((unsigned)len < size) {}         // 显式转换，刻意
if (len >= 0 && (unsigned)len < size) {} // 先判非负
```

## Q-matrix 判定

```json
{
  "Q1_defect_exists": true|false,   // 确为有符号 vs 无符号比较且无显式转换
  "Q2_exploitable": true|false,     // 负值可达且影响边界/越界校验
  "Q3_mitigation_exists": true|false // 显式 cast 或前置非负检查
}
```

| Q1 缺陷真实 | Q2 可利用 | Q3 有缓解 | 判决 |
|------------|----------|----------|------|
| No | — | — | SUPPRESS（非符号混用/已显式转换）|
| Yes | — | Yes | SUPPRESS（显式 cast/前置校验）|
| Yes | Yes | No | **CONFIRMED**（High，边界失效）|
| Yes | No | No | CONFIRMED（Medium，符号混用但负值不可达）|

**锚定要求**：引用引擎信号 + 两操作数类型（来自 Declarations），回答 Q2（被比较的有符号数是否可能为负）。
