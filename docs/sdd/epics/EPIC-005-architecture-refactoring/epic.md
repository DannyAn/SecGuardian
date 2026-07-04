# EPIC-005: Architecture Refactoring — Aligning Architecture with Product Vision

> **状态**: Active
> **创建**: 2026-07-04
> **目标版本**: v0.13.0

## 动机

SecGuardian 的 architecture 已经从 v0.1 演进到 v0.12，但架构文档未能同步反映产品愿景。
当前内部结构（indexer + skills + knowledge + detectors）是功能导向的，而产品方向是
"安全角色驱动的 SDLC 工作流"。

本轮目标不是改写代码，而是通过新增 `docs/architecture/` 目录下的架构文档，
使项目的架构叙事与产品愿景对齐，为后续渐进式重构打下基础。

## 范围

| 包含 | 不包含 |
|------|--------|
| 8 份架构文档 (docs/architecture/) | Go 代码修改 |
| 3 份合约文档 (engine/output/CI 边界) | 命令/skill 文件修改 |
| 明确 Architecture Rule 0 及 7 条 ADR | README 直接重写 |
| 执行策略层定义（非系统） | Security Engine 实现 |
| Execution Context 模型（单管线） | 双运行时/consumption mode 概念引入 |
| 7 条工程约束（EP-1~EP-7） | 过度工程抽象 |
| README 演进计划 | extensions/ 或 manifest.json 修改 |

## 依赖

- 依赖 `req-20260704.md` 作为 Spec 输入
- 不依赖其他 EPIC 或 FEATURE

## 演进路径

| 阶段 | 产出 | 状态 |
|------|------|------|
| ✅ 架构文档定义 | 8 份文档 + SDD 闭环 + 3 轮 review | 2026-07-04 完成 |
| ✅ 合约文档定义 | engine/output/CI 边界规格 | 2026-07-04 完成 |
| ⬜ 架构合约落地 | 合约驱动的命令/skill 重构 | future |
| ⬜ Engine 策略切换 | 确定性执行策略可选 | future |

## 相关文档

- `docs/sdd/req-20260704.md` — 架构重构需求（Brainstorm + Spec 输入）
- `README.md` — 当前 README（待演进，但本轮不动）

## Review History

| Cycle | Date | Scope | Result |
|-------|------|-------|--------|
| Round 1 | 2026-07-04 | Over-engineering audit | Collapsed dual-runtime; Engine → strategy; added 2 docs (CHANGE-001) |
| Round 2 | 2026-07-04 | CI framing + deterministic pre-pass | CI → verification layer; added pre-pass authority + signals (CHANGE-002) |
| Round 3 | 2026-07-04 | Layer boundary insights | Added 3 contract docs; deferred code changes (CHANGE-003) |
