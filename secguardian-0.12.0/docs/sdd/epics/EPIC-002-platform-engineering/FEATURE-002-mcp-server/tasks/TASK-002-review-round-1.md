# TASK-002: 第一轮架构评审 + 修订

> **Feature**: FEATURE-002-mcp-server
> **状态**: ✅ Done
> **完成日期**: 2026-06-15
> **原则**: Task 驱动编码

## Goal

ChatGPT 架构评审 → 接受/拒绝/推迟 → v0.2 修订。

## Done

### 评审发现（9 issues）

| # | Issue | 处置 |
|---|-------|------|
| 1 | `query_code_graph` Tool 缺失 — 无法查询调用图 | ✅ 接受 → 新增 Tool |
| 2 | `search_detectors` 不支持 `code_features` — 无法按代码特征搜索 | ✅ 接受 → 新增参数 |
| 3 | Prompts 含 Tool 执行步骤 — Prompt 应描述目标而非实现 | ✅ 接受 → 移除步骤 |
| 4 | Resource 无 `?section=` 参数 — 无法按需取章节 | ✅ 接受 → 新增参数 |
| 5 | `validate_findings` Tool — 输出格式校验 | ✅ 接受 → 新增 Tool（v0.3 改为 render_report 内置） |
| 6 | 版本兼容体系不完整 | ✅ 接受 → 完善 |
| 7 | Session 状态管理 — 跨调用复用索引 | ⏸️ 推迟到 v2.2 |
| 8 | 可执行 detector（analyze_with_detector） | ⏸️ 推迟到 v2.1（最高优先级） |
| 9 | Knowledge embed 超 10MB 阈值策略 | ⏸️ 推迟到 v2.5 |

### v0.2 修订内容
- [x] 新增 `query_code_graph` Tool（callers/callees/alloc_free/symbols）
- [x] `search_detectors` 新增 `code_features` 参数
- [x] Resource URI 支持 `?section=` 参数
- [x] Prompts 去除 Tool 执行步骤 → 改为目标导向描述
- [x] 新增 `validate_findings` Tool
- [x] 版本兼容体系完善

## Deliverable

v0.2 修订版设计文档
