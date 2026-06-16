# TASK-001: MCP Server 设计初稿

> **Feature**: FEATURE-002-mcp-server
> **状态**: ✅ Done
> **完成日期**: 2026-06-15
> **原则**: Task 驱动编码 — 设计阶段 Task 同样可追踪

## Goal

产出 MCP Server 完整设计文档 v0.1，覆盖 Resources / Tools / Prompts / Transport / 安全 / 版本。

## Done

- [x] 问题陈述：当前架构核心矛盾（3 extension × 3 平台 = 9 套维护）
- [x] Resources 设计：5 类知识资源（detector / threat-catalog / language-profile / standard-mapping / findings-schema）
- [x] Tools 设计：4 个 Tool（index_code / query_code_graph / search_detectors / render_report / health_check）
- [x] Prompts 设计：3 个 Prompt 模板（secguard / secaudit / secreview）
- [x] 目录结构规划：`cmd/secguardian-mcp/` + `internal/mcp/`
- [x] 技术选型：Go + mcp-go + embed
- [x] 安全考量：STDIO-only / embed 防篡改 / path 沙箱
- [x] 版本兼容体系
- [x] 明确边界（v1 不做什么）

## Deliverable

`docs/designs/2026-06-15-mcp-server-design.md`（v0.1，772 行）
