# EPIC-002: Platform Engineering

> **状态**: 🔄 进行中
> **周期**: 2026-06 ~ 至今
> **目标**: 提升 SecGuardian 的平台化能力——消除维护痛点、拓展消费层

## 概述

Platform Engineering 聚焦于 SecGuardian 作为平台的工程能力：消除散弹式修改、通过 MCP 协议拓展到更多 AI 编辑器和工具链。

## 包含 Feature

| Feature | 状态 | 说明 |
|---------|------|------|
| [FEATURE-001: Manifest-Driven Tokens](./FEATURE-001-manifest-driven-tokens/) | ✅ 已完成 | manifest.json 为单一权威源，sync-manifest.sh 自动同步 |
| [FEATURE-002: MCP Server](./FEATURE-002-mcp-server/) | 🔄 设计中 | 将 Security Knowledge + Code Intelligence 封装为 MCP 协议接口 |
| [FEATURE-003: Release Artifact Standardization](./FEATURE-003-release-artifact-standardization/) | 🔨 实现中 | 单包分发 + install.sh 统一安装器 |

## 架构愿景

SecGuardian 的核心资产只有两层：

```
Security Knowledge    →  67 个 detector、threat-catalog、5 个语言画像、4 个标准映射
    +
Code Intelligence     →  tree-sitter 解析器、符号索引、调用图、alloc/free 配对、锁分析
```

所有入口（CLI slash commands、MCP Server、IDE 插件、CI pipeline）都是消费层。

**任何消费层可以被替换，但 Knowledge + Intelligence 是唯一不可替代的资产。**

## 关键里程碑

| 日期 | 里程碑 |
|------|--------|
| 2026-06-07 | Manifest-Driven Tokens 设计与实现完成 |
| 2026-06-15 | MCP Server 设计 v0.3（经两轮架构评审） |
| TBD | MCP Server v1.0 实现 |

## 未来 Feature 候选

- **FEATURE-003: Multi-Platform Deployment** — Claude Code / OpenCode / Gemini CLI 三平台统一部署（当前已实现但未形成 SDD 文档）
- **FEATURE-004: VS Code Extension** — 通过 MCP Server 消费层接入 VS Code
- **FEATURE-005: CI/CD Native Integration** — GitHub Actions / GitLab CI 原生集成
