# ADR-001: Architecture Principles as Design Records

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Epic**: EPIC-005 Architecture Refactoring

## ADR-001-001: Security Roles as Module Boundaries (Architecture Rule 0)

**Context**: 项目的四个命令（secguard, secreview, secfix, secaudit）目前被描述为"扫描"或"检测"的不同级别。
产品愿景是 AI Security Engineer，每个命令对应 SDLC 中的一个安全角色。

**Decision**: 每个主要模块对应真实世界的安全角色职责：
- secguard → Secure Coding Advisor
- secreview → Security Reviewer
- secfix → Security Remediation Engineer
- secaudit → Release Security Auditor

Future modules must follow: 新模块应以安全角色命名，而非技术功能。

**Consequences**:
- Positive: 模块边界清晰，新角色容易添加
- Positive: 产品叙事自然延伸（"Security Team" 类比）
- Risk: 现有代码内部可能尚未完全解耦角色间的依赖
- Mitigation: 本轮不改代码，仅在架构文档中建立此约定

---

## ADR-001-002: LLM Agnosticism (Principle 1)

**Context**: 当前实现深度依赖 Claude Code 的 agentic 能力（MCP、slash commands）。
产品被误解为"又一个 AI 扫描工具"，而非安全平台。

**Decision**: SecGuardian 不是 AI 模型。LLM 是可替换的运行时组件。
知识（knowledge/）、规则（detectors/）、协议（protocols/）是核心资产。
Prompt 和模型是临时实现细节。

**Consequences**:
- Positive: 安全知识有长期防御力（知识比 AI 模型长寿）
- Positive: 不绑定单一 LLM 提供方
- Risk: 当前 skill 文件包含大量 prompt 编排，需要逐步抽象
- Risk: 不同 LLM 的能力差异（尤其是工具调用）需要适配层

---

## ADR-001-003: Knowledge is the Core Asset (Principle 2)

**Context**: 67 个检测器以 Markdown 格式存储在 knowledge/ 中。
但这些知识目前通过 SKILL.md 中的 prompt 加载给 LLM，没有独立于 LLM 的加载路径。

**Decision**: Security knowledge (detectors, rules, protocols) is the product.
AI 模型和 prompt 是运行时依赖，不是产品本身。
知识内容应能独立于 AI 加载路径被版本管理和审查。

**Consequences**:
- Positive: 知识修改不需要等模型升级
- Positive: 知识可以输出为 PDF/SARIF/HTML 等独立于 AI 的格式
- Work to do: 需要抽象一个独立的 Knowledge Loader，不依赖 SKILL.md

---

## ADR-001-004: AI Agents Are Runtimes (Principle 3)

**Context**: 三个 AI Agent（Claude Code, OpenCode, Gemini CLI）各自有不同的 skill 加载机制、
MCP 支持和扩展部署方式。当前项目为每个平台维护独立的 extension.json。

**Decision**: AI Agent 是执行环境（Runtime），不是产品特性。
SecGuardian 的行为在所有运行时上应一致。
差异仅在部署机制和平台支持上。

**Consequences**:
- Positive: 添加新 Agent 支持只需要新的 extension 包装，不改变核心逻辑
- Positive: 产品不绑定单个 Agent 的生态
- Risk: 不同 Agent 的能力差异（如 MCP 支持程度）可能导致行为差异
- Mitigation: 核心知识尽量通过文件系统加载，减少对 Agent 特殊能力的依赖

---

## ADR-001-005: CI/CD's Primary Value Is Telemetry (Principle 4)

**Context**: 当前 CI/CD 集成与 AI Agent 共享同一扫描管线。
CI 被认为需要"same scanning"，但 CI 的真正价值在于趋势追踪和门禁。

**Decision**: CI/CD 不是主要运行时。它的核心价值是：
1. Telemetry — 安全评分趋势、Finding 生命周期追踪
2. Gate — 阻止 CVE 进入生产
3. Evidence — 合规证据链（SARIF 输出）
扫描逻辑应跟随 AI Agent（开发者日常使用），而非 CI（定期检查）。

**Consequences**:
- Positive: CI 管线更轻量（不需要维持上下文）
- Positive: CI 输出聚焦于 score drift 和 gate decisions
- Work to do: CI 模式应简化（skip interactive skills, focus on audit rules）
- Risk: 如果不理解此原则，会试图在 CI 中运行 /secguard（非正确用法）

---

## ADR-001-006: Developer UX First (Principle 5)

**Context**: 当前项目的开发者体验（通过 slash commands 交互）与 CI 模式可能有冲突。
CI 需要零交互、确定性退出码；开发者需要上下文维持和增量反馈。

**Decision**: Developer UX is the primary design constraint.
永远不为 CI 兼容性牺牲 AI Agent 交互体验。
CI 体验在 Developer UX 确认后再适配。

**Consequences**:
- Positive: 开发者工具的核心价值保持清晰
- Positive: CI 适配可以作为独立工作流
- Risk: CI 团队可能觉得被降级对待

---

## ADR-001-007: Execution Strategy Convergence (Principle 6)

**Context**: 当前扫描逻辑分散在：
- 命令定义（commands/）
- Skill 文件（skills/）
- 检测器（knowledge/detectors/）
- 输出协议（knowledge/protocols/）

没有统一的执行模型。每个 skill 文件重新描述如何运行 detector。

**Decision**: 长期方向是收敛为一个执行策略定义（Execution Strategy），
而不是一个 Engine 系统。

当前系统只有一种策略：LLM-assisted。确定性匹配是未来研究方向，
不是当前实现目标。

在第二个策略出现之前，不允许抽象 Engine interface。
参见 engineering-principles.md EP-1（禁止提前抽象 execution kernel）。

**Consequences**:
- Positive: 策略定义使执行逻辑可审查
- Positive: 当第二个策略出现时，它作为具体实现添加，而非接口提取
- Risk: 仍可能被解读为"要建一个 Engine"
- Mitigation: engineering-principles.md 明确禁止提前内核抽象
- Risk: ADR-001-001~006 的原则仍需要代码收敛才能完全落地
- Mitigation: 优先做确定性候选提取原型（index.json → candidates.json）

