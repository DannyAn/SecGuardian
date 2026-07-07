# FEATURE-001: Architecture Documentation vNext

> **隶属 Epic**: EPIC-005 Architecture Refactoring
> **版本**: v0.1 (Final)
>
> **修改时间**: 2026-07-04
> **目标版本**: v0.13.0

---

## 1. Problem Statement

### 1.1 架构叙事缺失

项目目前有：
- **代码架构** — `internal/`, `skills/`, `knowledge/`, `commands/` 等目录体现了功能组织
- **产品叙事** — README 描述了 "Four Security Gates" SDLC 工作流
- **开发指引** — AGENTS.md 描述了项目解剖、构建方式和验证流程

**但缺少**一份文档，把三件事串联起来：
1. 产品愿景（AI Security Engineer）和当前架构之间的关系
2. 为什么某些东西是现在这样（架构决策的 rationale）
3. 架构未来怎么演进（Security Engine → 治理平台）

### 1.2 运行时概念混淆

当前代码中，"AI Agent" 和 "CI" 共用同一扫描管线，但：
- AI Agent 需要交互式反馈、上下文维持、增量扫描
- CI 需要确定性执行、SARIF 输出、非零退出码

这两者的约束条件不同，但架构中未显式区分。导致 skill 文件和输出协议试图同时满足两个场景。

### 1.3 Security Engine 缺乏定义

`/secguard`, `/secreview`, `/secfix`, `/secaudit` 四个命令各有不同的执行流程，但：
- 没有统一的 engine 概念
- Rule Pack 的实际位置（knowledge/）和 AI 加载方式（通过 SKILL.md）未被显式建模
- Engine 的职责边界不清：它应该自己执行规则，还是委托给 LLM？

---

## 2. Requirements

### REQ-001: 创建 architecture-vNext.md

一份主架构文档，回答以下问题：

- 产品愿景（AI Security Engineer）对应的架构视图是什么？
- 每个命令对应什么安全角色？
- Data flow 从索引到报告的完整路径是什么？
- 架构演进路径（v0.12 → v0.14 → v0.16+）是什么？

### REQ-002: 创建 runtime-model.md

单管线执行架构文档，CI 不作为独立 runtime：

- Execution Context Profiles（交互式执行剖面）
- 共享管线（indexer → knowledge → LLM → output）
- CI = verification constraint layer over artifacts
- 禁止：双运行时、CI 作为 consumption mode、交互式 vs CI 对称性

### REQ-003: 创建 security-engine.md

定义 Execution Strategy Layer（不是系统）：

- 当前策略：LLM-assisted（唯一实现）
- 确定性预检权威：index 派生候选空间，LLM 验证候选
- 当前确定性信号：symbols / call_graph / alloc_free / lock_graph
- LLM May / May Not 约束
- Do NOT implement engine as separate service
- Do NOT define engine interfaces, APIs, or telemetry schemas


### REQ-004: 创建 design-principles.md

将 req-20260704.md 中的 architecture principles 转化为 ADR 格式：

- Architecture Rule 0 — Security roles, not tools
- Principle 1 — LLM-agnostic
- Principle 2 — Knowledge is the product
- Principle 3 — AI Agents are runtimes
- Principle 4 — CI/CD's value is telemetry
- Principle 5 — Developer UX first
- Principle 6 — Execution Strategy Convergence

每条 ADR 包含：Context, Decision, Consequences。


审阅当前 README，不做直接修改，而是产出演进计划：

- 哪些章节需要改（naming, positioning）
- 哪些章节保持（Quick Start, Tech Architecture）
- 哪些措辞需要演进（"Four Security Gates" → "Security Roles"）
- 分几步改（Phase 1 / Phase 2 / Phase 3）


### Additional Deliverables (added during review cycles)

| 文件 | 来源 | 说明 |
|------|------|------|
| execution-model-current.md | Round 1 review | 当前单一执行路径文档（禁止 dual runtime 表达） |
| engineering-principles.md | Round 1 review | 反过度设计约束（EP-1~EP-7） |
| engine_contract.md | Round 3 review | Engine 边界定义（internal/engine/） |
| output_contract.md | Round 3 review | Renderer 边界定义（internal/output/） |
| ci-cd-interface.md | Round 3 review | CI as artifact consumer（docs/） |

---

## 3. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | architecture-vNext.md 存在，且包含架构视图、数据流、演进路径 | 文件可读 |
| 2 | runtime-model.md 存在，Execution Context Profiles + CI as verification constraint layer | 文件可读 | grep -c consumption |
| 3 | security-engine.md 存在，Execution Strategy Layer + deterministic pre-pass + LLM May/Not | 文件可读 | grep -c 'LLM MAY' |
| 4 | design-principles.md 存在，且每条原则以 ADR 格式记录 | ADR 含 Context-Decision-Consequences |
| 5 | readme-refactor-plan.md 存在，且含分阶段修改计划 | 文件可读 |
| 6 | 不修改 production 代码 | `git diff --stat` 仅含 docs/ |
| 7 | Feature Package 完整 | spec + adr + plan + progress + tasks |
| 8 | execution-model-current.md 存在，单管线描述（无 dual runtime 表达） | 文件可读 | grep -c 'dual runtime' = 0 |
| 9 | engineering-principles.md 存在，EP-1~EP-7 全部定义 | grep -c '^## Principle EP-' = 7 |
| 10 | engine_contract.md 存在，含 Engine 职责/边界定义 | 文件可读 |
| 11 | output_contract.md 存在，含 Renderer 职责/边界定义 | 文件可读 |
| 12 | ci-cd-interface.md 存在，CI as artifact consumer | 文件可读 |
| 13 | runtime-model.md 无 consumption mode 语言 | grep -c = 0 |
| 14 | security-engine.md 含 LLM May/Not 约束 | grep -c 'LLM MAY' >= 1 |

---

## 4. 相关文档

- `docs/sdd/req-20260704.md` — 架构重构输入
- `AGENTS.md` — 当前开发守则
- `README.md` — 当前 README（待演进目标）
- `knowledge/protocols/scan-output.md` — 输出协议 v5.0
- `internal/context/analysis_context.go` — 索引数据结构
