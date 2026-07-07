好，这一轮我不再给“架构愿景”，只给**能让 Codex 直接动手改、且不容易跑偏的 review3.md（最终执行版）**。

我会刻意压掉抽象，把问题收敛成：**必须改什么文件、改成什么状态、为什么、验收标准是什么**。

---

# 📄 review3.md（Final Execution Review）

## 目标（必须统一认知）

当前系统不是“设计问题”，而是：

> ❗**“AI 扫描系统已经能跑，但架构表达与执行边界不一致，导致未来 CI/CD 化会失控”**

这轮重构的唯一目标：

> ✔ 把“能跑的 Agent 工程”收敛成 **可稳定演进的 Security Engine Core**

---

# 1. ❌ 当前最大结构性问题（必须修）

## 1.1 Command / Skill / Engine 三层职责混乱

### 现状问题

目前存在：

* `/secguard.md`（command = 调度 + 流程 + IO + policy）
* `secguard-cpp.md`（skill = 又在写流程 + 又在写 index 使用）
* internal Go engine（parser/indexer/indexer.go）

👉 结果：

> ❌ 同一逻辑在 3 个层级重复定义（尤其 index.json 使用权）

---

### 必须修改（强制）

#### ✔ Rule A：Command 层只能做 3 件事

修改 `/commands/secguard.md`

只允许：

```
1. 参数解析
2. 调度 skill
3. 定义 output root path
```

❌ 删除/禁止：

* index.json 使用说明
* detector 执行流程
* SARIF schema
* validation logic
* namespace mapping

👉 **这些全部下沉到 skill 或 engine**

---

## 1.2 Skill 层“伪 engine 化”问题

### 现状问题

`secguard-cpp.md`：

* 在写 Phase 1~5 全流程
* 在写 indexer 使用
* 在写文件系统规则
* 在写 SARIF

👉 本质错误：

> ❌ skill = mini engine（导致未来无法替换 runtime）

---

### 必须修改

#### ✔ Rule B：Skill 必须降级为 “Detector Planner”

改成只有 4 件事：

```
1. 输入解释（language + filter + mode）
2. detector selection 规则
3. index.json 使用方式（只读契约）
4. 输出 contract（调用 engine API）
```

---

### ❌ 必须删除：

* Phase 1~5 pipeline
* mkdir / file system 操作
* SARIF 输出逻辑
* index.json 构建逻辑
* shell scripts

---

### ✔ Skill 改造目标：

> skill 不再“执行扫描”，只回答：

```
👉 哪些 detector 应该运行
👉 用什么输入数据
👉 交给 engine 做什么
```

---

## 1.3 Engine 层缺失（关键架构缺口）

你现在**最大隐患不是复杂，是没有真正 engine contract**

---

### 必须新增文件：

```
internal/engine/engine_contract.md
```

定义唯一执行协议：

```md
SECENGINE CONTRACT v1

输入：
- index.json
- file list
- detector list
- scan mode

输出：
- findings[] (structural)
- logs
- artifacts paths

禁止：
- IO决策
- language decision
- detector selection
```

---

👉 关键点：

> engine 是唯一“可以读代码 + 写结果”的层

---

# 2. ❌ index.json 使用权混乱（严重）

## 当前问题

* command 在用
* skill 在用
* engine 在用
* detector 在用

👉 导致：

> ❌ 无法替换 indexer
> ❌ 无法做 CI/CD isolation
> ❌ 无法做 multi-runtime

---

## ✔ 必须修复（强约束）

### Rule C：index.json 只能由 engine 读取

所有其他层必须改成：

```
❌ read index.json
✔ request engine.context
```

---

### 需要新增 abstraction：

```
internal/context/context.go
```

增加：

```go
type SecurityContext struct {
    Files []File
    Symbols SymbolTable
    CallGraph Graph
    AllocFreePairs []AllocFree
}
```

---

👉 skill / command 只能看到 context，不许直接碰 index.json

---

# 3. ❌ 输出系统设计错误（未来 CI/CD 会炸）

## 当前问题

你现在：

* command 写 report path
* skill 写 report.md
* engine 写 SARIF
* scripts 再 render

👉 4 个 source of truth

---

## ✔ 必须统一

### Rule D：输出必须单向流

```
engine → artifacts
renderer → format
command → only path
```

---

## ✔ 必须修改结构：

### ❌ 删除：

* skill 中所有 report.md / sarif 描述
* command 中 output tree 说明

---

### ✔ 新标准：

新增：

```
internal/output/output_contract.md
```

定义：

```text
engine emits:
- findings.json (raw)
- events.json (log stream)

renderer consumes:
- findings.json → report.md / sarif / dashboard
```

---

👉 **核心原则：engine 不负责格式化**

---

# 4. ❌ detector 执行模型混乱（AI 会漂）

## 当前问题

你现在：

* skill 决定 detector
* engine 又引用 index.json
* command 又 filter

---

## ✔ 必须统一为：

### Rule E：detector selection 只有一条路径

```
command filter
        ↓
skill mapping
        ↓
engine executes
```

---

👉 严禁：

* engine 自己选 detector
* skill 动态调整 execution
* command override execution logic

---

# 5. ❌ CI/CD 扩展点没有稳定边界

## 当前问题

你现在 CI/CD 是“未来设想”，但已经污染 core design

---

## ✔ 必须改：

### Rule F：CI/CD 是 consumer，不是 architecture participant

新增：

```
docs/ci-cd-interface.md
```

定义：

```
CI/CD only consumes:

- results.sarif
- status.json
- summary.json

CI/CD must NOT:
- call engine internals
- modify detector logic
- access index.json
```

---

# 6. ✔ 最关键收敛（架构一句话）

必须统一为：

> **Command decides WHAT to run
> Skill decides WHICH detectors
> Engine decides HOW to execute
> Renderer decides HOW to display**

---

# 7. 🧪 验收标准（非常重要）

Codex 改完必须满足：

## A. 分层检查

* command 不含 detector logic ❌
* skill 不含 filesystem / execution ❌
* engine 不含 output formatting ❌
* renderer 不含 analysis logic ❌

---

## B. index.json only used in engine

全仓库 grep：

```
index.json
```

只能出现在：

```
internal/engine/*
internal/indexer/*
```

---

## C. 输出一致性

一次 scan：

```
1 engine output
1 renderer output
N views
```

不能多源写文件

---

# 8. 🚀 下一步给 Codex 的指令（直接用）

你可以直接喂这个：

---

## 📌 Codex Execution Prompt（下一轮执行）

```
你是 SecGuardian 架构重构执行器。

任务：执行 review3.md 中所有强制修改项。

要求：

1. 严格分层：
   - command / skill / engine / renderer 必须职责隔离

2. 删除所有跨层污染逻辑：
   - skill 中的 index.json 操作必须移除
   - command 中 detector / SARIF / scan logic 必须移除

3. 引入：
   - internal/engine/engine_contract.md
   - internal/output/output_contract.md
   - internal/context/SecurityContext

4. 强制规则：
   - index.json 只能在 engine 使用
   - skill 只能返回 detector selection
   - engine 不允许输出 report/sarif
   - renderer 不允许做安全分析

5. 输出：
   - 修改 diff
   - 修改理由（每个文件不超过5行）

6. 不允许重构过度：
   - 不要改 detector 数量
   - 不要改 rules 内容
   - 不要改 indexer 实现
   - 只做架构边界修正

目标：让系统变成可替换 runtime 的 AI security engine，而不是 monolithic agent script.
```

---

# 最后一句结论（重要）

你现在系统的问题不是“AI不够聪明”，而是：

> ❗**聪明的 AI 被混乱的职责边界逼成了“到处写流程的脚本机”**

这轮改完之后，你的系统才会从：

```
AI Agent Tool → Security Engine Platform
```

变成真正可进 CI/CD / 可替换 LLM / 可扩展 detector runtime 的结构。

---

如果你下一步愿意，我可以帮你做一件更狠的事：

> 👉 把“secguard vs secfix vs secreview”统一成一个**execution lattice（执行格）模型**

那一步之后，这个项目才会真的像“平台”，而不是“工具集合”。
