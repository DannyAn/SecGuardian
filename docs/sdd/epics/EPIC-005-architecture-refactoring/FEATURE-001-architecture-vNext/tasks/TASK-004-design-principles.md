# TASK-004: Create design-principles.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 4 / 5

## 目标

创建 `docs/architecture/design-principles.md`，将 req-20260704.md 中的 7 项架构原则转化为 ADR 格式。

## 内容要求

文档包含：

1. Architecture Rule 0 — Security roles as module boundaries
2. Principle 1 — LLM Agnosticism
3. Principle 2 — Knowledge is the core asset
4. Principle 3 — AI Agents are runtimes
5. Principle 4 — CI/CD's primary value is telemetry
6. Principle 5 — Developer UX first
7. Principle 6 — Convergence into one Security Engine

每条 ADR 必须包含：
- **Context** — 为什么需要这个原则
- **Decision** — 具体原则内容
- **Consequences** — Positive + Risk + Mitigation

## 注意

ADRs in `docs/sdd/` (FEATURE-001/adr.md) 是 SDD 内部记录。
此文档是发布到 `docs/architecture/` 的正式版本，面向架构读者。

## 原则

- 每条原则都有明确 trade-off 记录
- 避免说教语气（"Should" 而不是 "Must"）
- 记录否决过的替代方案

## 验证

- 文件存在：`docs/architecture/design-principles.md`
- 每条 ADR 包含 Context-Decision-Consequences 三段式
