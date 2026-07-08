---
name: secguard-cpp-ownership_transfer
description: "Detect use-after-free via ownership transfer violations including realloc misuse and container-stored dangling pointers"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# Ownership Transfer 检视算子

## 元数据

- id: memory.ownership_transfer
- severity: high
- cwe: CWE-416 (related)
- category: memory
- signal_source: call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: `free`, `realloc`, `delete`, `delete[]`, `*_free`, `*_destroy`, `*_release`, `FREE_*`
- 按信号分组: 优先处理 `realloc` 调用（需检查旧指针后续使用），其次含有同作用域内 free 后指针使用的函数，最后考虑跨函数的释放模式

## 检视协议

### Step 1: 信号确认
对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在，且调用属于内存释放或所有权转移操作

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: 通过 `malloc`/`calloc`/`new` 分配的原始指针
- Propagate: 指针被传递、赋值给别名 `p2 = p1`、存储在容器中、或作为函数参数传递
- Sink: `free(p)` 或 `realloc(p, new_size)` 执行后，原始指针或其别名在后续代码中被解引用（`p->field`、`p[index]`、`*p`）或传递给另一个使用函数

### Step 3: 安全变体参数审计
1. **realloc 不当使用**:
   - `p = realloc(p, new_size);` — 安全：realloc 可能返回不同的指针，但旧指针被更新
   - `q = realloc(p, new_size); free(p);` — 双重释放：realloc 内部已释放 p，`free(p)` 导致 double-free
   - `q = realloc(p, new_size); p[0] = 'x';` — 释放后使用：如果 realloc 移动了内存，p 已无效

2. **释放后别名使用**:
   - `free(p); p2->field = 1;` — 如果 `p2 == p` 则为 UAF
   - 检查函数范围内是否存在别名赋值 `p2 = p` 或 `p2 = p + offset`

3. **容器/数据结构中的悬空指针**:
   - 释放指针后未从容器中移除: `free(p); list_contains(p) == true`
   - 检查同一数组或链表中存储的指针

4. **所有权转移的调用者错误**:
   - 函数参数标明 `__attribute__((ownership_takes(p)))` 或类似语义
   - 调用者继续使用已被调函数释放的指针
   - 函数文档说"调用者负责调用 free"但调用者没有 — 视为 resource-leak 而非此算子

5. **C++ 移动语义不当**:
   - 移动后继续访问原始对象: `auto b = std::move(a); a.method();` // a 已转移

### Step 4: 跨函数补证
Max depth 1, beyond → downgrade to suspicious
- 检查被调用函数内部是否执行 free，但调用者在调用后仍使用该指针
- 检查函数返回值是否为所有权转移信号（如 realloc 返回值）
- 对 C++ unique_ptr 的 move，追踪到构造后原对象不再使用

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 原所有者释放后新所有者继续使用同一指针?
**Q2**: 释放后原指针被置 NULL?
**Q3**: 所有权转移通过 RAII/智能指针/显式契约明确管理?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

