# TASK-003: 第二轮架构评审 + 深度修订

> **Feature**: FEATURE-002-mcp-server
> **状态**: ✅ Done
> **完成日期**: 2026-06-15
> **原则**: Task 驱动编码

## Goal

第二轮 ChatGPT 评审 → 聚焦架构锚点和简化 → v0.3 深度修订。

## Done

### 关键修订

| # | Issue | 处置 |
|---|-------|------|
| 1 | **Architecture Vision 缺失** — 未阐明 "Knowledge + Intelligence 是唯一不可替代资产" | ✅ 新增 §Architecture Vision |
| 2 | **`knowledge_id`/`index_path` 双轨** — Resource 和 Tool 各自定义知识源定位方式，不一致 | ✅ 统一为 `index_path` |
| 3 | **`validate_findings` → `validate_report_schema`** — validation 应是 render_report 内置步骤而非独立 Tool | ✅ 合并：render_report 调用前自动执行 schema 校验 |
| 4 | **版本体系 4 套 → 2 套** — detector schema 是 knowledge 子集，protocol 版本由 schema 自身表达 | ✅ 精简为 `server_version` + `knowledge_version` |
| 5 | **Prompts 不引用 Tool 名** — Prompt 应描述分析目标，不应硬编码 Tool 调用序列 | ✅ 改为目标导向自然语言 |
| 6 | **v2 优先级调整** — Executable Detector > Session | ✅ 理由：跨模型一致性是产品级问题 |

### v0.3 修订内容
- [x] 新增 Architecture Vision 锚点
- [x] 移除 knowledge_id/index_path 双轨
- [x] `validate_findings` → `validate_report_schema`，render_report 内置自校验
- [x] 版本体系精简（4 → 2）
- [x] Prompts 不引用 Tool 名
- [x] v2 优先级调整

## Deliverable

v0.3 修订版设计文档（当前 spec.md）
