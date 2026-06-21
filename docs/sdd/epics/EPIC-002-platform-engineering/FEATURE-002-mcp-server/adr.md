# ADR — MCP Server Architecture Decisions

> **Feature**: FEATURE-002-mcp-server
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: MCP Server 是消费层，不是产品核心

**日期**: 2026-06-15
**状态**: ✅ Accepted（第二轮评审确立）

### Decision

SecGuardian 的核心资产只有两层：
```
Security Knowledge + Code Intelligence
```
MCP Server（以及 CLI slash commands、IDE 插件、CI pipeline）都是消费层。

**任何消费层可以被替换，但 Knowledge + Intelligence 是唯一不可替代的资产。**

### Reason

- 避免"MCP Server 是产品"的认知陷阱——MCP 只是协议适配层
- 架构锚点决定未来三年的扩展决策：新增消费层（如 VS Code 插件）时，不应改动 Knowledge/Intelligence 层
- 与现有 slash commands 的关系：MCP 是新能力，现有工作流一条不改

### Consequences

- `internal/` 不引入 MCP 依赖（`secguardian-index` 编译不受影响）
- 新增 `cmd/secguardian-mcp/` 作为独立入口
- Resource 数据从 `knowledge/` embed，与 slash commands 共享同一知识源

---

## ADR-002: Go 实现 + STDIO-only Transport (v1)

**日期**: 2026-06-15
**状态**: ✅ Accepted

### Decision

- **语言**: Go（`github.com/mark3labs/mcp-go`）
- **Transport**: 仅 STDIO（不做 SSE/HTTP）
- **Resource 数据**: 编译时 `embed` 嵌入（当前 knowledge/ ~150KB）

### Reason

- Go 与现有 `internal/` 同语言，可复用 indexer/parser 代码
- STDIO 是 MCP 协议的基础 transport，覆盖 Claude Desktop + VS Code + Zed 等主流客户端
- embed 消除运行时文件路径依赖，零配置启动

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **Python MCP 实现** | 无法复用 Go indexer，两套语言维护成本高 |
| **SSE/HTTP transport (v1)** | 增加复杂度，v1 无远程调用需求 |
| **外部文件读取（非 embed）** | 需要配置 `SECGUARDIAN_HOME`，增加用户上手成本 |
| **TypeScript/Node.js MCP SDK** | 社区 SDK 成熟度不如 Go，且无法复用 indexer |

### Consequences

- v1 仅 STDIO：用户需本地安装 `secguardian-mcp` 二进制
- embed 上限 ~10MB：当前 ~150KB，仍有充足空间。超阈值时启用外部目录 fallback（v2.5）

---

## ADR-003: 双版本体系（server_version + knowledge_version）

**日期**: 2026-06-15
**状态**: ✅ Accepted（第二轮评审从 4 套精简到 2 套）

### Decision

仅维护两个版本号：

| 版本 | 含义 | 变更频率 |
|------|------|---------|
| `server_version` | MCP Server 自身版本 = SecGuardian 主版本 | 每次 release |
| `knowledge_version` | knowledge/ 数据 + detector schema 版本 | detector 增删改或 schema 变更 |

### Reason

- v0.2 设计有 4 套版本（server / knowledge / detector / protocol）——维护成本高
- detector schema 本质是 knowledge 的子集，不需要独立版本
- protocol 版本可通过 findings schema 自身表达

### Consequences

- `health_check` Tool 返回两个版本号
- 不兼容升级时 Server 启动检测 `knowledge_version` → 输出 warning → 状态标记 `degraded`
