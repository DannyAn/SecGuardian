# FEATURE-005: Architecture Document Revision — Closing the Design-Code Gap

> **隶属 Epic**: EPIC-005 Architecture Refactoring
> **版本**: v0.1
> **创建**: 2026-07-05
> **状态**: Active

---

## 1. Problem Statement

### 1.1 架构文档与代码现实之间存在结构性鸿沟

EPIC-005 前四轮（FEATURE-001~004）产出了完整的架构文档体系和代码改进，但深入审视发现三个核心矛盾：

| # | 矛盾 | 架构文档说... | 代码现实是... |
|---|------|-------------|-------------|
| 1 | **谁是真引擎** | `engine_contract.md` 定义了独立 Engine 层的 I/O 边界 | LLM prompt 就是引擎，没有独立 Engine 二进制存在 |
| 2 | **确定性预检可行吗** | `security-engine.md §4` 定义"确定性预检权威"，LLM 只能在候选空间内验证 | 索引器调用图是 `strings.Contains` 近似匹配，alloc/free 不跨文件，无 CFG/DFG/类型继承——候选空间质量无法支撑"权威"角色 |
| 3 | **合约是目标还是幻觉** | 三份合约定义了清晰的层边界，要求"命令只是薄分发器" | `secguard.md` 590 行含完整执行管线，`SKILL.md` 178 行含 Phase 1-5 全流程 |

### 1.2 根本原因

FEATURE-001 经过 3 轮 review 后确立了"Security Engine 作为独立策略层"的方向，但设计时隐含了一个未经验证的假设：

> "Tree-sitter 索引器能产出足以覆盖有意义漏洞发现的候选空间。"

当前索引器的能力边界（见 AGENTS.md §当前索引器能力边界）无法支撑这个假设。`engineering-principles.md` EP-1 正确警告了"禁止过早抽象执行内核"，但 `security-engine.md` 本身已经在描述一个过早抽象的"权威预检"角色。

### 1.3 修正方向

不是推翻 EPIC-005 的架构工作，而是**收敛设计到可实现的范围**：

- **保留**：四层架构（Runtime → Command → Execution Strategy → Output）、安全角色模型、单一管线、CI 作为 verification layer
- **修正**：取消"独立 Security Engine"概念，改为"确定性信号层 + LLM 推理层"协作模型
- **明确**：确定性信号层的价值是锚定/预筛/去重，不是独立漏洞发现

---

## 2. Design Decision: Signal-LLM Collaboration Model

### 2.1 核心模型

```
┌──────────────────────────────────────────┐
│        EXECUTION STRATEGY LAYER           │
│                                           │
│  ┌─────────────────┐  ┌───────────────┐  │
│  │ 确定性信号层      │  │  LLM 推理层    │  │
│  │ (Deterministic   │  │ (LLM          │  │
│  │  Signals)        │  │  Reasoning)   │  │
│  │                  │  │               │  │
│  │ 当前:            │  │ 当前:         │  │
│  │ ✅ 符号表        │  │ ✅ 语义分析   │  │
│  │ ✅ 调用图(近似)  │  │ ✅ 上下文推理 │  │
│  │ ✅ alloc/free    │  │ ✅ 补丁生成   │  │
│  │ ✅ lock graph    │  │ ✅ 解释说明   │  │
│  │                  │  │               │  │
│  │ 演进:            │  │ 硬约束:       │  │
│  │ → 跨文件调用图   │  │ ⚠️ 锚定约束   │  │
│  │ → 类型继承图     │  │ ⚠️ 证据约束   │  │
│  │ → 数据流预分析   │  │               │  │
│  └────────┬─────────┘  └───────┬───────┘  │
│           └──────────┬──────────┘          │
│                      ▼                     │
│               findings.json                │
└──────────────────────────────────────────┘
```

### 2.2 关键设计原则

1. **不分家** — 不做独立 Engine 二进制。执行策略层是一个概念层，信号来自索引器（已有），推理来自 AI Agent（已有），两者不是对立组件
2. **信号层不独立发现漏洞** — 它的价值是：锚定（每个 finding 可追溯到 index 符号）、预筛（快速过滤不相关代码）、去重（合并同一代码的多个命中）
3. **LLM 保留智能发现能力** — 语义理解、业务逻辑判断、补丁生成仍是 LLM 的强项，不受"只能验证候选"的限制
4. **渐进增强** — 信号层从符号锚点开始，逐步加跨文件调用图 → 类型继承 → 数据流预分析，每一步都是可独立验证的增量

---

## 3. Requirements

### REQ-001: 重写 security-engine.md — 从"策略层"到"信号-LLM协作模型"

**当前问题**：
- §4 定义"确定性预检权威"，但索引器质量无法支撑
- §4 列出 LLM MAY / MAY NOT 约束，但 MAY NOT 中"不能引入候选空间外的发现"过度限制了 LLM 的价值
- 整体语气暗示存在一个"预检系统"，但实际不存在

**修正方向**：
- 重命名为"Execution Strategy: Signal-LLM Collaboration"
- 取消"预检权威"概念，改为"确定性信号层作为锚点和预筛"
- LLM 约束从"MAY NOT introduce findings outside candidates"改为"每个 finding 必须锚定到 index 中的符号/位置 + 引用具体代码证据"
- 增加信号层能力表和渐进演进路线（符号锚点 → 跨文件调用图 → 类型继承 → 数据流预分析）
- 保留 §8 CRITICAL WARNING 的核心精神（不做独立 Engine），但更新理由

### REQ-002: 重写 engine_contract.md — 从"Engine 合约"到"执行策略合约"

**当前问题**：
- 标题和内容描述了一个不存在的独立 Engine 组件
- 定义了 Engine 的 I/O 接口，但没有 Engine 实现
- "Rule C: index.json is engine-only" 在 LLM 直接读 index.json 的现实下无法执行

**修正方向**：
- 重命名为"Execution Strategy Contract"
- 合约主体变为行为约束而非组件接口：
  - **锚定约束**：每个 finding 的 `location` 必须指向 index.json 中存在的符号或文件+行号
  - **证据约束**：每个 finding 的 `evidence` 必须引用具体代码片段
  - **预筛规则**：哪些确定性信号触发哪些 detector 类别
- 保留"命令不读 index.json 结构"的建议作为最佳实践（非硬合约）
- 移除不存在的 Engine API 定义

### REQ-003: 更新 architecture-vNext.md — 演进路径修正

**当前问题**：
- Phase 2 (v0.14) 描述"结构化规则+确定性匹配"，假设了 DSL/结构化 detector
- Phase 3 (v0.15) 描述"Deterministic matcher research"，暗示独立确定性引擎
- 与 engineering-principles.md EP-5（Knowledge is Markdown, not DSL）矛盾

**修正方向**：
- Phase 2 改为"确定性信号增强 (v0.14)"：跨文件调用图 + 类型继承图
- Phase 3 改为"信号-LLM 协作深化 (v0.15)"：数据流预分析 + 锚定约束在 CI 中的应用
- 删除独立"Deterministic matcher"概念
- 保留 Phase 4 CI/CD artifact consumer 和 Phase 5 Governance Platform

### REQ-004: 更新 runtime-model.md — CI 快速门禁流程

**当前问题**：
- §4 CI 描述偏理论，没有具体流程
- "CI evaluates artifacts" 但没有说明 CI 如何使用确定性信号

**修正方向**：
- 增加"CI 确定性预检流程"：锚定校验 → 去重合并 → 预筛 → 只将候选发给 LLM（或跳过 LLM 做快速门禁）
- 明确 CI 可以使用确定性信号做"快速门禁"（不需要 LLM），完整扫描仍需 LLM

### REQ-005: 更新 design-principles.md — ADR-007 修正

**当前问题**：
- ADR-007 "Execution Strategy Convergence" 仍暗示"策略收敛到统一引擎"
- 方向正确但措辞容易让人误解为"构建 Engine"

**修正方向**：
- ADR-007 更新为"Signal-LLM Collaboration Model"
- 明确拒绝独立 Engine 方案作为 Rejected Alternative
- 增加 ADR-008：Progressive Signal Enhancement（渐进式信号增强）

### REQ-006: 更新 engineering-principles.md — EP-1 修正

**当前问题**：
- EP-1 "No Premature Execution Kernel Abstraction" 禁止了 Engine interface，但没有提供替代方案

**修正方向**：
- EP-1 更新为"Signal Anchoring Over Engine Abstraction"
- 明确替代方案：用确定性信号的锚定约束替代 Engine 抽象
- Non-Violation Example 更新为信号锚定的代码示例

### REQ-007: 注入锚定约束到 commands/secguard.md (CHANGE-001)

**触发**: OpenCode 实测扫描发现架构文档修正后，prompt 指令未同步落地。

**修正方向**：
- Step 4 增加锚定校验步骤："录制 finding 前，验证 `file:line` 在 index.json 的 `files` 列表中存在"
- Step 2.5b 收紧预筛约束：将"即使无匹配也执行"改为"无匹配时标记 `confidence: low` 并说明原因"
- 增加证据要求：每个 finding 必须包含 `--snippet`、`--code-context`、`--rationale`

### REQ-008: 注入锚定约束到 skills (CHANGE-001)

**修正方向**：
- 5 个 `skills/secguard/{cpp,go,java,python,js}/SKILL.md` 的 Detector Selection 区域增加信号预筛规则
- Engine Instructions 区域增加锚定约束和证据约束

### REQ-009: record-finding.py 必填参数强化 (CHANGE-001)

**修正方向**：
- `--snippet`、`--code-context`、`--rationale` 从可选改为必填
- 缺失时打印错误并 exit 1，强制 LLM 在调用前准备证据

---

## 4. Non-Requirements (明确不做)

| 不做 | 原因 |
|------|------|
| 修改 Go 索引器代码 | 本轮只改架构文档，索引器增强在后续 FEATURE |
| 修改 commands/skills | 锚定约束注入在 FEATURE-006 |
| 修改 detector 规则内容 | 知识资产不动 |
| 修改 render-report.py | 输出层不变 |
| 实现 CI 快速门禁 | 在 FEATURE-008 |
| 创建新的合约文档 | 修正现有文档，不新增 |

---

## 5. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | security-engine.md 不再包含"LLM MAY NOT introduce findings"的绝对约束 | `grep -c "MAY NOT.*introduce"` = 0 |
| 2 | security-engine.md 包含信号层能力表和渐进演进路线 | `grep -c "信号层\|Signal Layer\|渐进\|progressive"` >= 3 |
| 3 | engine_contract.md 不再定义 Engine API/接口 | `grep -c "Engine receives\|Engine processes\|Engine emits"` = 0 |
| 4 | engine_contract.md 包含锚定约束和证据约束 | `grep -c "锚定\|anchor\|证据\|evidence"` >= 4 |
| 5 | architecture-vNext.md Phase 2/3 不再提"deterministic matcher" | `grep -c "deterministic.*match\|deterministic.*engine"` = 0 |
| 6 | architecture-vNext.md Phase 2 改为信号增强 | `grep -c "跨文件调用图\|cross-file call graph"` >= 1 |
| 7 | runtime-model.md 包含 CI 确定性预检流程 | `grep -c "快速门禁\|fast gate\|确定性预检"` >= 1 |
| 8 | design-principles.md ADR-007 更新为协作模型 | `grep -c "Signal-LLM\|信号.*LLM"` >= 1 |
| 9 | engineering-principles.md EP-1 提供替代方案 | `grep -c "Signal Anchoring\|信号锚定"` >= 1 |
| 10 | 所有架构文档间交叉引用一致 | 手动检查 6 份文档互链 |
| 11 | self-check 通过 | `bash scripts/self-check.sh` exit 0 |
| 12 | 不修改 production 代码 | `git diff --stat` 仅含 docs/ |

---

## 6. 相关文档

- `docs/architecture/security-engine.md` — 当前版本（待重写）
- `internal/engine/engine_contract.md` — 当前版本（待重写）
- `docs/architecture/architecture-vNext.md` — 当前版本（待更新）
- `docs/architecture/runtime-model.md` — 当前版本（待更新）
- `docs/architecture/design-principles.md` — 当前版本（待更新）
- `docs/architecture/engineering-principles.md` — 当前版本（待更新）
- `AGENTS.md` — 索引器能力边界
- `docs/sdd/brainstorm-log.md` — 2026-07-05 R2 讨论记录
