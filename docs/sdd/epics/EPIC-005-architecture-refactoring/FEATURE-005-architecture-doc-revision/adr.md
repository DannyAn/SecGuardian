# ADR: Architecture Document Revision — Signal-LLM Collaboration Model

> **Feature**: FEATURE-005 Architecture Document Revision
> **Date**: 2026-07-05
> **Status**: ✅ Accepted

---

## ADR-009: Signal-LLM Collaboration Model (Replaces ADR-007 Direction)

### Context

EPIC-005 FEATURE-001 产出的 `security-engine.md` 和 `engine_contract.md` 描述了一个"确定性预检权威"（Deterministic Pre-Pass Authority），其中 LLM 只能在 index 派生的候选空间内验证发现。同时 `engine_contract.md` 定义了一个独立 Engine 组件的 I/O 接口。

经过深入审视，这个设计存在两个根本性问题：

1. **索引器质量无法支撑"权威候选空间"**：当前调用图是 `strings.Contains(body, name+"(")` 近似匹配，alloc/free 不跨文件追踪，无 CFG/DFG/类型继承。用这样的索引器定义"权威候选空间"，是在不准确的地基上建墙。

2. **过度限制 LLM 价值**：LLM 的核心优势是语义理解、上下文推理、发现传统 SAST 找不到的问题。将其限制在"只能验证候选"会放弃 SecGuardian 最核心的差异化能力。

同时，AD-007 "Execution Strategy Convergence" 的正确方向（策略统一而非系统分裂）应当保留并强化。

### Decision

采用 **"确定性信号层 + LLM 推理层"协作模型**，替代"独立 Security Engine"概念：

1. **确定性信号层**（Deterministic Signals）的职责：
   - **锚定**：每个 finding 的 `location` 必须能追溯到 index.json 中的符号或文件+行号
   - **预筛**：基于信号快速过滤"明显不相关"的代码路径（如无 crypto 函数 → 跳过 crypto detector）
   - **去重**：多个 detector 命中同一代码位置时合并
   - **不做**：独立发现漏洞、独立判断漏洞真实性

2. **LLM 推理层**（LLM Reasoning）的职责：
   - 语义分析、上下文推理、业务逻辑判断
   - 补丁生成、解释说明
   - 受两条硬约束：①锚定约束（location 可溯源）②证据约束（引用具体代码片段）
   - **不做**：凭空推断、无证据断言

3. **不做独立 Engine 二进制**：
   - 引擎不是一个独立组件，而是"信号+LLM"在同一管线内的协作模式
   - 信号来自索引器（已有），推理来自 AI Agent（已有），不需要中间层

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **独立 Security Engine 二进制** | 索引器质量不支撑，过早抽象（违反 EP-1），会创建与 LLM 输出不一致的第二条执行路径 |
| **LLM 完全不受约束** | 无法做 CI 门禁、无法保证可溯源性、不同模型输出差异无法控制 |
| **结构化规则 DSL + 确定性匹配** | 违反 EP-5（Knowledge is Markdown），需要年级别的工程投入，且放弃了 LLM 的核心优势 |

### Consequences

- **Positive**: 架构描述与代码现实一致（不存在的东西不描述为存在）
- **Positive**: 保留了 LLM 的智能发现能力（SecGuardian 的差异化价值）
- **Positive**: 渐进增强路径清晰：符号锚点 → 跨文件调用图 → 类型继承 → 数据流预分析
- **Positive**: CI 快速门禁可在不依赖 LLM 的情况下用确定性信号做预检
- **Risk**: "协作模型"比"独立组件"更难画架构图——读者需要理解两个协作层而非一个独立盒子
- **Mitigation**: 用清晰的数据流图替代组件图，强调"协作"而非"分层"

---

## ADR-010: Progressive Signal Enhancement Over Deterministic Matching

### Context

`architecture-vNext.md` Phase 2/3 当前描述的是"Knowledge Extraction"和"Strategy Exploration"，暗示了结构化规则提取和独立确定性匹配引擎。这与 EP-5（Knowledge is Markdown）和 ADR-009（不做独立 Engine）矛盾。

### Decision

演进路径从"提取知识→构建引擎"改为"渐进式增强确定性信号"：

| 阶段 | 当前计划（旧） | 新计划 |
|------|-------------|--------|
| Phase 2 (v0.14) | Knowledge Extraction: YAML frontmatter | **Signal Enhancement R1**: 跨文件调用图 + 类型继承图 |
| Phase 3 (v0.15) | Strategy Exploration: deterministic matcher research | **Signal Enhancement R2**: 数据流预分析（source-sink 配对） |
| Phase 4 (v0.16+) | Consumption Mode Expansion | 不变：CI/CD artifact consumer |
| Phase 5 (v0.17+) | Governance Platform | 不变：企业治理功能 |

每一步增强都是索引器的一个具体能力提升，不是架构层的抽象变更。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **YAML frontmatter 提取作为 Phase 2** | 在索引器能提供高质量候选空间之前，结构化规则元数据没有执行载体 |
| **Deterministic matcher research 作为独立 Phase** | 违反 ADR-009，暗示独立引擎方向 |

### Consequences

- **Positive**: 每一步都是可独立验证的索引器能力提升，不依赖架构层的抽象变更
- **Positive**: 与 `engineering-principles.md` 七条约束全部一致
- **Positive**: 跨文件调用图和类型继承图的实现难度可控（Tree-sitter 已有类型信息，跨文件只需全局符号表）
- **Risk**: 数据流预分析（Phase 3）难度远高于前两步，可能需要 IR 层
- **Mitigation**: Phase 3 明确标记为"研究阶段"，不承诺一定实现
