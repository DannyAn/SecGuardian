# TASK-002: Rewrite engine_contract.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `internal/engine/engine_contract.md`
> **改动量**: 重写 ~75%

## 目标

将 `engine_contract.md` 从"Engine 组件合约（定义 API/接口）"重写为"执行策略行为合约（定义约束规则）"。

## 具体修改

### 删除/替换的内容

1. **标题和定位**："SECENGINE CONTRACT v1" → "EXECUTION STRATEGY CONTRACT v2"
2. **§2 Contract → Inputs/Outputs 表**：删除 Engine API 定义（"Engine receives/processes/emits"）
3. **§3 Execution Model**：整体替换。删除独立 Engine 执行流程描述
4. **§4 index.json Access Rule (Rule C)**：放宽。从"index.json is engine-only"改为"index.json 结构知识应封装在索引器侧，命令/skill 应引用确定性信号而非直接操作 index 字段"

### 新增的内容

1. **§2 重写为"行为约束"**：

**锚定约束 (Anchor Rule)**:
- 每个 finding 的 `location` 必须指向 index.json 中存在的符号或文件+行号
- 如果 detector 在没有对应 index 符号的情况下产生 finding，标记为 `confidence: low` 并说明原因

**证据约束 (Evidence Rule)**:
- 每个 finding 的 `evidence` 必须引用具体代码片段
- 不允许仅基于"代码模式看起来像"的推断
- 证据必须可被人类 reviewer 独立验证

**预筛规则 (Pre-filter Rule)**:
- 基于 index 信号选择性触发 detector：
  - `symbols.functions` 含 `malloc`/`realloc` 但无对应 `free` → 触发 memory-leak detector
  - `symbols.functions` 含 `strcpy`/`sprintf`/`gets` → 触发 buffer-overflow detector
  - 无加密库函数符号 → 跳过 crypto detector

2. **§3 重写为"当前执行现实"**：
   - 明确说明：当前 LLM prompt 是实际执行载体，没有独立 Engine 二进制
   - 确定性信号来自索引器（已有），LLM 推理来自 AI Agent（已有）
   - 无需中间 Engine 层

### 保留的内容

- §1 Purpose 的核心意图（只有一层读代码+产生 finding）
- §5 Output Rule (Rule D) 单方向流
- §6 Related Documents 交叉引用

## 验证

```bash
# 不再定义 Engine API
grep -c "Engine receives\|Engine processes\|Engine emits" internal/engine/engine_contract.md  # 期望: 0

# 包含锚定/证据约束
grep -c "锚定\|anchor\|证据\|evidence" internal/engine/engine_contract.md  # 期望: >= 4

# 包含预筛规则
grep -c "预筛\|Pre-filter\|pre.filter" internal/engine/engine_contract.md  # 期望: >= 1

# 明确标注当前无独立 Engine
grep -c "no.*independent.*engine\|no.*separate.*engine\|LLM.*prompt.*execution" internal/engine/engine_contract.md  # 期望: >= 1
```
