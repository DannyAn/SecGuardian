# TASK-004: 实施 Backlog（待启动）

> **Feature**: FEATURE-002-mcp-server
> **状态**: ⬜ Pending
> **预估**: 2-3 人天
> **原则**: Task 驱动编码 — 每个 Task 对应一次可验证的代码变更

## Goal

将 v0.3 设计落地为可用 MCP Server。

## Tasks

### Phase 1: 重构 indexer（半天）
- [ ] 提取 `internal/indexer/runner.go` — RunIndex 公共函数
- [ ] 重构 `cmd/secguardian-index/main.go` — 调用 runner
- [ ] 验证：`self-check.sh` 全绿

### Phase 2: 结构化查询（半天）
- [ ] `internal/indexer/query.go` — callers/callees/alloc_free/symbols

### Phase 3: MCP Server 核心（1 天）
- [ ] `cmd/secguardian-mcp/main.go` — 入口
- [ ] `internal/mcp/server.go` — STDIO server (mcp-go)
- [ ] `internal/mcp/resources.go` — 5 类 Resource + `?section=` 路由
- [ ] `internal/mcp/tools.go` — 5 个 Tool handlers
- [ ] `internal/mcp/prompts.go` — 3 个 Prompt 模板

### Phase 4: 构建集成（半天）
- [ ] `scripts/generate-detectors-index.sh` — frontmatter → detectors_index.json
- [ ] `scripts/package.sh` 改动 — MCP 编译 + index 生成
- [ ] 端到端验证：Claude Desktop + VS Code

## Dependency

- Phase 2 依赖 Phase 1（需要 `runner.go` 提取完成）
- Phase 3 依赖 Phase 1+2（Tools 需要调用 indexer + query）
- Phase 4 依赖 Phase 3

## Blocked By

无。等待进入实施阶段。
