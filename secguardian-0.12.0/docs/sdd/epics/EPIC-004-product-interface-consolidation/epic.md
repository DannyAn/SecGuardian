# EPIC-004: Product Interface Consolidation

> **状态**: 📋 Spec 阶段
> **周期**: 2026-06-21 ~
> **目标**: 统一三个产品命令接口、重构知识层结构、实现构建时自动化消除 drift

## 概述

本 Epic 是对 SecGuardian 三个产品（SecGuard / SecAudit / SecReview）的**接口与知识层统一**。核心变化：

- 三个命令参数统一为 `<path> <language>`，消除解析歧义
- 知识库统一为 `{command}-rules/` 命名模式，迁移到 `knowledge/`
- SecAudit 从 17 个独立 skill 变为 1 个旗舰 workflow
- 构建时自动化消除 Gemini .toml drift 和手工 language-index

## 包含 Feature

| Feature | 状态 | 说明 |
|---------|------|------|
| [FEATURE-001: Command Unification](./FEATURE-001-command-unification/) | 📋 Spec 阶段 | 三命令参数统一 + 知识层重组 + 构建自动化 |

## 架构影响

- `commands/*.md` — 三个命令的执行流程全部重写
- `commands/gemini/*.toml` — 从源码变为构建 artifact
- `knowledge/` — detectors/ → guard-rules/，新增 audit-rules/ + review-rules/
- `skills/secaudit/` — 17 个 skill → 1 个 workflow
- `scripts/` — 新增 sync 脚本

## 关键里程碑

| 日期 | 里程碑 |
|------|--------|
| 2026-06-21 | Brainstorm 完成 |
| — | Spec 写作中 |
