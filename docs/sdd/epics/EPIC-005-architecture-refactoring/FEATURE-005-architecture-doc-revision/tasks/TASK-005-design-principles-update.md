# TASK-005: Update design-principles.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `docs/architecture/design-principles.md`
> **改动量**: 局部修改 ~10%

## 目标

更新 ADR-007 并新增 ADR-008，反映"信号-LLM协作"模型。

## 具体修改

### ADR-007 更新

**标题**: "Execution Strategy Convergence" → "Signal-LLM Collaboration Model"

**Decision 段落更新**:
- 保留"策略统一而非系统分裂"的正确方向
- 删除暗示"收敛到统一引擎"的措辞
- 增加"当前执行策略 = 确定性信号层（索引器）+ LLM 推理层（AI Agent），无中间组件"
- 增加 Rejected Alternative: "独立 Security Engine 二进制"

### 新增 ADR-008: Progressive Signal Enhancement

```markdown
## ADR-008: Progressive Signal Enhancement

### Context
索引器当前提供符号表、近似调用图、alloc/free 配对、锁图。
这些信号的质量和覆盖范围决定了"确定性锚定"的可靠性。
需要明确索引器的渐进增强路径，每次增强一个可独立验证的能力。

### Decision
索引器增强按以下顺序渐进：
1. v0.14: 跨文件调用图（全局符号表匹配替代同文件字符串包含）
2. v0.14: 类型继承图（Tree-sitter 已有类型信息，建立继承链）
3. v0.15: 数据流预分析（source-sink 配对，研究阶段）

每一步增强是索引器的一个具体能力提升，不引入架构层抽象变更。
增强后的信号直接体现在 index.json 的新字段中，
commands/skills 无需修改即可受益（LLM 读取更丰富的 index）。

### Consequences
- Positive: 每一步可独立验证，可独立发布
- Positive: 与 EP-1~EP-7 全部一致
- Risk: 数据流预分析（v0.15）可能需要 IR 层，标记为研究阶段
```

## 验证

```bash
# ADR-007 包含协作模型描述
grep -c "Signal-LLM\|信号.*协作\|collaboration" docs/architecture/design-principles.md  # 期望: >= 1

# ADR-008 存在
grep -c "ADR-008\|Progressive Signal" docs/architecture/design-principles.md  # 期望: >= 1

# 明确拒绝独立 Engine
grep -c "Rejected.*Engine\|独立.*Engine\|separate.*engine" docs/architecture/design-principles.md  # 期望: >= 1
```
