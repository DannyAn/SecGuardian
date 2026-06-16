# MCP Server — 实施计划

> **Feature**: FEATURE-002-mcp-server
> **Epic**: EPIC-002-platform-engineering
> **状态**: 🔄 计划阶段（详细设计见 spec.md §13）
> **预估工作量**: 2-3 人天

## Architecture

```
cmd/secguardian-mcp/main.go    # MCP Server 入口
├── internal/mcp/server.go      # MCP STDIO server (mcp-go)
├── internal/mcp/resources.go   # Resource handlers (URI routing + ?section=)
├── internal/mcp/tools.go       # Tool handlers (5 tools)
├── internal/mcp/prompts.go     # Prompt templates
├── internal/indexer/runner.go  # ★ Extract from cmd/secguardian-index
├── internal/indexer/query.go   # ★ New: structured query capability
└── detectors_index.json        # ★ New: pre-built detector index (compile-time embed)
```

**Go 依赖**: `github.com/mark3labs/mcp-go`（MCP 协议）
**设计原则**: `internal/` 不引入 MCP 依赖，`secguardian-index` 编译不受影响。

## Implementation Phases

### Phase 1: 重构 indexer（半天）
- [ ] 提取 `internal/indexer/runner.go` — RunIndex 为公共函数
- [ ] 重构 `cmd/secguardian-index/main.go` — 调用 runner 替代内联逻辑
- [ ] 验证：`self-check.sh` 全绿

### Phase 2: 结构化查询能力（半天）
- [ ] 实现 `internal/indexer/query.go`
  - [ ] `query_type=callers` — 谁调用了函数
  - [ ] `query_type=callees` — 函数调用了谁
  - [ ] `query_type=alloc_free` — alloc/free 配对
  - [ ] `query_type=symbols` — 符号表查询

### Phase 3: MCP Server 实现（1 天）
- [ ] `server.go` — MCP STDIO server 初始化 + Tool/Resource/Prompt 注册
- [ ] `resources.go` — 5 类 Resource (detector, threat-catalog, language-profile, standard-mapping, findings-schema) + URI routing + `?section=` 参数
- [ ] `tools.go` — 5 个 Tool handlers:
  - [ ] `index_code` — 运行 indexer
  - [ ] `query_code_graph` — 调用 query.go
  - [ ] `search_detectors` — 按语言/代码特征搜索 detector
  - [ ] `render_report` — 调用 render-report.py（内置 schema 自校验）
  - [ ] `health_check` — 版本+状态检查
- [ ] `prompts.go` — 3 个 Prompt 模板（目标导向，不引用 Tool 名）
- [ ] `main.go` — 入口 + flag 解析

### Phase 4: 构建集成 + 验证（半天）
- [ ] 生成脚本 `scripts/generate-detectors-index.sh` — 解析 detector frontmatter → `detectors_index.json`
  - [ ] 包含 `triggers` 字段（从 detector ## 检测模式汇总 提取）
- [ ] `scripts/package.sh` 改动 — 新增 MCP 编译 + index 生成步骤
- [ ] 端到端测试：Claude Desktop + VS Code 分别连接验证

## Code Estimates

| 组件 | 代码量 |
|------|--------|
| `cmd/secguardian-mcp/main.go` | ~50 行 |
| `server.go` | ~100 行 |
| `resources.go` | ~250 行 |
| `tools.go` | ~400 行 |
| `prompts.go` | ~60 行 |
| `internal/indexer/runner.go` | ~80 行 |
| `internal/indexer/query.go` | ~150 行 |
| `cmd/secguardian-index/main.go` 重构 | ~50 行 |
| `detectors_index.json` 生成脚本 | ~120 行 |
| `scripts/package.sh` 改动 | ~30 行 |
| **总计** | **~1,290 行** |

## Version Strategy

- MCP Server 版本 = SecGuardian 主版本
- `knowledge_version` 独立于 server_version
- `health_check` 暴露版本不兼容警告
- 详见 spec.md §11

## Explicit Non-Goals (v1)

- ❌ SSE/HTTP transport（STDIO only）
- ❌ Session / 状态管理（v2.2）
- ❌ 机器可执行 detector（v2.1，最高优先级）
- ❌ 修改现有 slash commands
- ❌ CI/CD 用 MCP Tool
- ❌ Python MCP 实现
