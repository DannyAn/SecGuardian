# ADR-002: Architecture Contract Implementation Decisions

> **Feature**: FEATURE-002 Architecture Contract Implementation
> **Epic**: EPIC-005 Architecture Refactoring

## ADR-002-001: Progressive Architecture Injection (Not Rewrite)

**Context**: commands/*.md 和 skills/*/SKILL.md 包含 AI Agent 执行扫描所需的所有指令。
当前没有独立的 Engine 层——LLM prompt 本身就是 execution engine。
直接删除执行指令会破坏系统可用性。

**Decision**: 采用渐进式架构注入（Progressive Architecture Injection）：

1. 不删除 commands/skills 中的任何现有内容
2. 增加架构分层标记（Command Layer / Engine Layer / Skill Layer 分组）
3. 内容按架构层重组，而非删除
4. 行为零变化——扫描结果与之前完全一致

**Consequences**:
- Positive: AI Agent 保持可用，不受影响
- Positive: 架构可见性立即提升——每个 section 明确标注所属层
- Positive: 未来 Engine 实现时知道从哪些 section 提取逻辑
- Risk: 文件仍然"胖"（内容未减少）
- Mitigation: 这是过渡态——Engine 实现后再精简
- Risk: 分层标记可能不一致
- Mitigation: 所有标记引用同一套合约文档（engine_contract.md, output_contract.md）

## ADR-002-002: Architecture Layers as Section Hierarchy

**Context**: 架构合约定义了 Command / Skill / Engine 三层。
但 commands/*.md 和 skills/*/SKILL.md 是扁平文档，没有分层结构。

**Decision**: 在每个文件中增加 H2 级别分组标题，将内容归入对应层：

- `## ⚙️ Command Layer` — 属于 command 的内容（parse, dispatch, output path）
- `## 🛠️ Engine Layer` — 属于 engine 的内容（execution, index, findings）
- 不创建子文件——所有内容留在同一文件，用标题分层

**Consequences**:
- Positive: 文件数量不变，变更影响最小
- Positive: 层次关系一目了然
- Risk: 单个文件可能变长（多了一些标题行）
- Mitigation: 内容不增删，只增加分组标题和引用

## ADR-002-003: Contract References as Anchors

**Context**: 合约文档（engine_contract.md, output_contract.md）定义了各层的职责边界。
commands/skills 需要引用这些合约，使架构约束可见。

**Decision**: 每个 Engine Layer 分组下添加合约引用：

```
## 🛠️ Engine Layer

以下内容属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。
当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。
```

**Consequences**:
- Positive: 读者知道哪些内容属于 Engine 层
- Positive: 实现者知道从哪些 section 提取 Engine 逻辑
- Risk: 注释比内容长
- Mitigation: 一个分组一句话引用，不重复
