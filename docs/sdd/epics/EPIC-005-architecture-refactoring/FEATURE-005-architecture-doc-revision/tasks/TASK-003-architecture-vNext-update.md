# TASK-003: Update architecture-vNext.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `docs/architecture/architecture-vNext.md`
> **改动量**: 局部修改 ~20%

## 目标

更新 `architecture-vNext.md` §5 演进路径，消除与 ADR-009/ADR-010 的矛盾。

## 具体修改

### §2 Architecture Overview 架构图

- Strategy Note 区域更新：从"没有独立 Engine"改为"信号-LLM 协作"

### §5 Evolution Path

**Phase 2 重写**:

旧: "Knowledge Extraction (v0.14) — YAML frontmatter + structured metadata"
新: "Signal Enhancement R1 (v0.14) — 跨文件调用图 + 类型继承图"

| Change | Today | Target |
|--------|-------|--------|
| 调用图范围 | 同文件 `strings.Contains` | 跨文件全局符号表匹配 |
| 类型信息 | 仅记录类型名 | 类型继承链 + 接口实现图 |
| 索引器输出 | 当前 call_graph.edges | 新增 type_hierarchy.nodes + type_hierarchy.edges |

**Phase 3 重写**:

旧: "Strategy Exploration (v0.15) — deterministic matcher research"
新: "Signal Enhancement R2 (v0.15) — 数据流预分析 + 锚定约束 CI 应用"

| Change | Today | Target |
|--------|-------|--------|
| 数据流 | 不存在 | Source-sink 配对（函数参数→敏感操作） |
| CI 使用信号 | 不使用 | 锚定校验 + 预筛匹配率 → 快速门禁 |

**Phase 4/5 保持不变**（仅措辞微调确保一致性）

### §7 Mapping to Current Project Structure

更新映射表中 Security Engine 一行：
旧: "Security Engine \| (does not exist) \| Strategy note in docs"
新: "Execution Strategy \| index.json + LLM prompt \| 确定性信号来自索引器，推理来自 AI Agent"

### §8 Risks and Mitigations

更新风险表：删除"Premature engine abstraction"（已被本修正消除），增加"信号质量不足"风险。

## 验证

```bash
# Phase 2/3 不提 deterministic matcher
grep -c "deterministic.*match\|deterministic.*engine" docs/architecture/architecture-vNext.md  # 期望: 0

# Phase 2 提到跨文件调用图/类型继承
grep -c "cross-file\|跨文件\|type.*hierarch\|类型.*继承" docs/architecture/architecture-vNext.md  # 期望: >= 1

# Strategy Note 更新
grep -c "Signal-LLM\|信号.*LLM\|signal.*collaboration" docs/architecture/architecture-vNext.md  # 期望: >= 1
```
