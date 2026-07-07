很好，这一步你要做的是**把“隐性架构争论”变成“可执行修复任务”**，否则 codex 会继续写漂亮文档但系统不会收敛。

我直接给你一份可以让 codex 执行的：

---

# 📄 Round2—检视结果.md（给你直接落地用）

你可以原样提交给 codex。

---

## 1. 总体结论（必须先读）

当前 Round2 的修改：

### ✔ 正确方向

* 已经从“架构叙事”回到“pipeline统一性”
* CI/CD 不再被当成独立 runtime
* security-engine 已经从“伪engine”回收为 strategy

### ❌ 但存在 3 个结构性残留问题

---

## 2. 问题1：CI/CD 仍然存在“语义独立性”

### 位置

`runtime-model.md`

### 问题描述

仍然存在隐性模型：

> CI = consumer profile（消费模式）

这个定义是错误的，因为它导致：

* CI 与 Agent 输出逻辑差异被“合理化”
* artifact 不再是唯一 truth source
* verification 变成“模式问题”而不是“约束问题”

### 正确模型（必须改）

CI 不是 profile，也不是 runtime：

> CI is a **verification constraint layer over artifacts**

---

## 3. 问题2：LLM权重仍然过高（未实质下降）

### 位置

`security-engine.md`

### 问题描述

虽然已经改成：

> LLM = reasoning backend

但系统仍然：

* 没有明确“deterministic pre-pass is authoritative”
* 没有明确“LLM cannot override index-derived candidates”
* detection truth 仍隐含来自 LLM

### 结果风险

当前仍然是：

> LLM decides what is a vulnerability

而不是：

> index.json defines candidate space + LLM validates

---

## 4. 问题3：deterministic能力被“语言压制”而非“系统显式化”

### 位置

security-engine.md

### 问题描述

你已经拥有：

* index.json
* call graph
* alloc/free
* lock graph

但你只是写成：

> “future direction”

这导致：

* deterministic能力不可见
* 无法被 CI gate 使用
* 无法被逐步增强

---

## 5. 必须执行的修正（非常重要）

### 🔧 修正1：runtime-model.md

#### 必须替换内容

把所有 CI 相关描述改成：

```
CI = verification constraint layer over SecGuardian artifacts
CI does NOT define execution behavior
CI does NOT define runtime profile
CI only evaluates:
  - SARIF
  - status.json
  - summary.json
```

#### 删除内容

* “consumption mode”
* “future CI runtime”
* “interactive vs CI symmetry”

---

### 🔧 修正2：security-engine.md

#### 必须新增一条核心约束

```
Deterministic pre-pass (index-driven candidate generation) is authoritative.

LLM may:
- validate candidates
- explain findings
- generate fixes

LLM may NOT:
- introduce new findings outside index-derived candidate space
```

---

### 🔧 修正3：必须显式化 deterministic layer（关键）

在 security-engine.md 中加入：

```
Current system already contains deterministic signals:
- index.json (files + symbols)
- call_graph.edges
- alloc_free.pairs
- lock_graph.mutexes

These are NOT future features.
They are CURRENT candidate generation inputs.
```

---

## 6. 禁止行为（必须遵守）

codex 不允许：

* ❌ 引入新 runtime
* ❌ 引入 engine/service abstraction
* ❌ 改 CI/CD pipeline结构
* ❌ 改 skill/command结构
* ❌ 引入 DSL / schema redesign
* ❌ 引入新 execution layer

---

## 7. 输出要求

codex 必须输出：

```
1. unified diff only
2. 不允许新增文件
3. 不允许改 knowledge 目录结构
4. 只允许修改：
   - runtime-model.md
   - security-engine.md
```

---

# 8. 下一步你要让 codex 做什么（关键）

这一轮结束后，不要再改架构。

下一步只做一件事：

---

## 👉 Step 3（非常关键但很小）

让 codex 做：

### “Deterministic candidate extraction prototype（最小验证）”

### 目标

证明一件事：

> index.json 可以独立生成“疑似漏洞候选点”

---

## codex prompt（下一步）

```
TASK: add minimal deterministic candidate extraction (NO LLM change)

GOAL:
Introduce a lightweight pre-pass that uses index.json ONLY to generate
"vulnerability candidate locations".

SCOPE:
- ONLY add new script OR extend existing indexer output (choose minimal change)
- DO NOT modify LLM behavior
- DO NOT modify command/skill system

REQUIREMENTS:

1. Input: index.json
2. Output: candidates.json

Candidates include:
- alloc sites without clear free in alloc_free.pairs
- lock without matching unlock
- suspicious sinks from call_graph (system, crypto, web entrypoints)

STRICT RULES:
- No LLM usage
- No new architecture layers
- No CI changes
- No command changes

OUTPUT:
- candidates.json only
- simple deterministic logic is enough
```

---

# 9. 你现在的真实位置（很重要）

我帮你直说结论：

你现在已经从：

> “LLM-based SAST system”

走到了：

> “hybrid deterministic + LLM verification system（early stage）”

但还差一步：

> **把 deterministic layer从“描述”变成“事实”**

---

如果你下一轮做对，你这个系统会出现一个质变：

> CI 不再依赖 LLM 判断漏洞，而是只验证候选结果

那时候你这个项目才开始真正有“企业价值”。
