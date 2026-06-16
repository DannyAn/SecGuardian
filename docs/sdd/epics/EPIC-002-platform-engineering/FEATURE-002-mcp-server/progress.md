# MCP Server — 进度追踪

> **Feature**: FEATURE-002-mcp-server
> **最后更新**: 2026-06-15

## 状态: 🔄 设计中

## 当前阶段

设计完成 v0.3（经两轮 ChatGPT 架构评审），待进入 Phase 1 实施。

## 完成清单

### 设计阶段 ✅
- [x] v0.1 初稿（2026-06-15）
- [x] v0.2 第一轮评审修订（新增 query_code_graph/validate_findings Tool、code_features 搜索、?section= 参数、Prompts 去执行步骤、版本兼容）
- [x] v0.3 第二轮评审修订（Architecture Vision、移除双轨、validate_findings→validate_report_schema、版本精简、Prompt 不引用 Tool 名）

### 实施阶段 ⬜
- [ ] Phase 1: 重构 indexer（runner.go 提取 + query.go 实现）
- [ ] Phase 2: MCP Server 核心实现（server/resources/tools/prompts/main）
- [ ] Phase 3: 构建集成（detectors_index.json 生成 + package.sh）
- [ ] Phase 4: 端到端验证

## 设计评审关键决策

| 评审轮次 | 关键决策 |
|---------|---------|
| 第一轮（9 issues） | 接受 6 项修订，推迟 3 项到 v2 |
| 第二轮 | validate_findings → validate_report_schema（内联自校验）、knowledge_id/index_path 双轨移除、版本体系从 4 套精简到 2 套 |

## 架构锚点

> SecGuardian 的核心资产只有两层：Security Knowledge + Code Intelligence。
> MCP Server 是消费层，不是产品本身。
> **任何消费层可以被替换，但 Knowledge + Intelligence 是唯一不可替代的资产。**

## 阻塞项

无。等待进入实施阶段。
