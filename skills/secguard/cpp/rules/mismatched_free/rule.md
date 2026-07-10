---
name: secguard-cpp-mismatched_free
description: "检测 C/C++ 中分配/释放函数不配对（malloc↔delete、new↔free、new[]↔delete[] 等）导致的堆损坏与未定义行为"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.mismatched_free
signal_filter: memory.mismatched_free*
signal_source: call_sites[cat="memory"]
severity: high
cwe: [CWE-762]
---

# mismatched_free 检测规则

> **来源**：从原 `ownership_transfer` 规则拆出（ownership_transfer 混合了 UAF 与 mismatched-free 两个 CWE，已拆分；UAF 部分归 use_after_free，本规则专注 CWE-762 分配/释放不配对）。补齐 threat-catalog 已列的 `memory.mismatched-free`。

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.mismatched_free` |
| signal_source | `call_sites[cat="memory"]` |
| 默认严重度 | High |
| CWE | CWE-762 (不匹配的内存释放) |

## 威胁定义

C/C++ 有多套分配体系，各自维护独立内部数据结构，混用必然导致堆损坏：
- `malloc` ↔ `free`（C 堆）
- `new` ↔ `delete`（C++ 单对象）
- `new[]` ↔ `delete[]`（C++ 数组）
- 自定义 `xxx_alloc` ↔ `xxx_free`

`malloc` 的指针用 `delete` 释放、`new` 的指针用 `free` 释放、`new[]` 用 `delete`（非 `delete[]`）释放等，均属不配对，行为未定义，常致堆元数据损坏→后续任意崩溃或可利用漏洞。

## Scenario 1: 跨体系分配/释放不配对

```c
// BAD: malloc 配 delete
char *p = malloc(100);
delete p;              // 不配对：malloc 应配 free

// BAD: new 配 free
int *q = new int(5);
free(q);               // 不配对：new 应配 delete

// BAD: new[] 配 delete（非 delete[]）
int *arr = new int[10];
delete arr;            // 不配对：new[] 应配 delete[]

// BAD: 自定义分配器配标准 free
void *b = my_alloc(64);
free(b);               // 不配对：应配 my_free
```

## 安全模式

```c
char *p = malloc(100); free(p);              // 配对
int *q = new int(5); delete q;               // 配对
int *arr = new int[10]; delete[] arr;        // 配对
void *b = my_alloc(64); my_free(b);          // 配对
```

## Q-matrix 判定（Fact-Anchor Reflection）

```json
{
  "Q1_mismatch_exists": true|false,   // 确存在分配/释放体系不配对
  "Q2_mismatch_exploitable": true|false, // 不配对释放可达且影响堆元数据
  "Q3_mitigation_exists": true|false   // RAII/智能指针/统一分配器消除手动配对
}
```

| Q1 不配对真实 | Q2 可利用 | Q3 有缓解 | 判决 |
|--------------|----------|----------|------|
| No | — | — | SUPPRESS（配对正确/误报）|
| Yes | — | Yes | SUPPRESS（RAII/统一分配器）|
| Yes | Yes | No | **CONFIRMED**（High）|
| Yes | No | No | CONFIRMED（Medium，潜在堆损坏）|

**锚定要求**：引用分配点 file:line + 释放点 file:line + 两者的分配体系。
