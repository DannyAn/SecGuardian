# TASK-001: Rewrite security-engine.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `docs/architecture/security-engine.md`
> **改动量**: 重写 ~70%

## 目标

将 `security-engine.md` 从"Execution Strategy Layer（预检权威）"重写为"Signal-LLM Collaboration Model（信号-LLM协作模型）"。

## 具体修改

### 删除/替换的内容

1. **§1 标题和定位**："Why a Strategy Layer (Not a System)" → "Execution Strategy: Signal-LLM Collaboration"
2. **§4 "Deterministic Pre-Pass Authority"**：整节替换。取消"预检权威"概念，取消"LLM MAY NOT introduce new findings outside index-derived candidate space"
3. **§4 "LLM Role Constraints"**：重写约束。从"MAY / MAY NOT"改为"锚定约束 + 证据约束"
4. **§5 Future Direction**：删除"Deterministic Strategy"独立路径描述

### 新增的内容

1. **§2 增加"确定性信号层能力表"**：

| 信号 | 来源 | 当前质量 | 能支撑什么 |
|------|------|---------|-----------|
| symbols.functions | Tree-sitter AST | ✅ 可靠 | 锚定 finding 到函数 |
| call_graph.edges | 文本近似 | ⚠️ 同文件 | 调用链分析（有限） |
| alloc_free.pairs | 文本扫描 | ⚠️ 同文件 | 内存泄漏候选 |
| lock_graph.mutexes | 文本扫描 | ⚠️ 同文件 | 锁使用候选 |

2. **§3 新增"渐进式信号增强路线"**：
   - v0.14: 跨文件调用图 + 类型继承图
   - v0.15: 数据流预分析（source-sink 配对）
   - v0.16+: 跨文件数据流 + CI 快速门禁

3. **§4 重写为"LLM 推理层的约束"**：
   - 锚定约束：每个 finding 的 `location` 指向 index 中的符号或文件+行号
   - 证据约束：每个 finding 的 `evidence` 引用具体代码片段（不能凭空推断）
   - LLM 保留语义分析、业务逻辑判断、补丁生成能力

### 保留的内容

- §6 Knowledge Consumption（当前 Markdown → LLM 路径描述正确）
- §7 Integration Points（CI 不注入策略层）
- §8 CRITICAL WARNING 的核心精神（更新理由）
- §9 Commitments（全部更新为协作模型）

## 验证

```bash
# 不再有 "LLM MAY NOT introduce" 绝对约束
grep -c "MAY NOT.*introduce" docs/architecture/security-engine.md  # 期望: 0

# 包含信号层能力表和渐进路线
grep -c "信号层\|Signal Layer\|渐进\|progressive" docs/architecture/security-engine.md  # 期望: >= 3

# 包含锚定/证据约束
grep -c "锚定\|anchor\|证据\|evidence" docs/architecture/security-engine.md  # 期望: >= 3

# 不再暗示独立 Engine 系统
grep -c "separate.*engine\|independent.*engine\|engine.*system" docs/architecture/security-engine.md  # 期望: 0
```
