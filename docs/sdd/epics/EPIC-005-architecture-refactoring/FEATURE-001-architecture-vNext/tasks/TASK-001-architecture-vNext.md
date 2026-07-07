# TASK-001: Create architecture-vNext.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 1 / 5

## 目标

创建 `docs/architecture/architecture-vNext.md`，作为 SecGuardian 的主要架构文档。

## 内容要求

文档必须包含：

1. **Product Vision** — AI Security Engineer 的架构视图
2. **Architecture Overview** — 分层架构（Runtime Layer → Security Engine → Knowledge Layer → Output Layer）
3. **Security Roles** — 每个命令对应的安全角色定义
4. **Data Flow** — 从索引到报告的完整流程
5. **Evolution Path** — v0.12 → v0.14 → v0.16+ 的架构演进

## 原则

- Think like a principal architect
- 避免营销语言和 buzzwords
- 每个概念说明：Why it exists, What it owns, What it does NOT own
- 必须可逐步实现
- 不要过度设计

## 验证

- 文件存在：`docs/architecture/architecture-vNext.md`
- 可读且内容完整
