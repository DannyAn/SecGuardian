# CHANGE-004: TDD — Per-rule Agent Isolation Enforcement

> **Date**: 2026-07-11
> **Status**: Implemented (all code changes complete; TDD V1-V5 verification pending OpenCode scan — Task #9)
> **驱动**: CHANGE-003 门控决策被测试证伪——串行内联在 OpenCode 15 文件扫描中导致 LLM 自停 12/15 规则

## 一、测试暴露的事实（不可争议）

2026-07-11 OpenCode secguard 扫描 cpp-vuln-demo-no-answers（15 文件，571 信号，20 rules），session ses_0af8-nga-dsv4flash.md：

| 指标 | 预期（设计目标） | 实际 | 诊断 |
|------|-----------------|------|------|
| 已处理规则 | 20/20（全部） | 3/15（20%） | 12 条有信号规则被 LLM 自行丢弃 |
| 信号覆盖率 | 100%（571/571） | 1.7%（10/571） | coverage-gate BLOCKED |
| 完整源文件读取 | 0（信号坐标片段） | 13/13 完整文件 | 违背 Tree-sitter 单次索引原则 |
| verification-gate 通过 | confirmed > 0 | 0 confirmed, 15 needs_review | artifacts/qmatrix 字段缺失 |
| Finding 产出 | 引擎保证的 recall 下限 | 仅 3 条规则的 finding | 引擎保证被 LLM 自由意志覆盖 |

**根本原因链**：
1. 串行内联模式下，所有 (rule, batch) 都在同一个主上下文处理
2. LLM 先读了全部 13 个源文件（无 offset/limit）→ 大量上下文消耗
3. 处理 3 条规则后上下文接近耗竭 → LLM 自行决定"剩余规则 skipped"
4. 日志原话：*"Given context constraints, let me now proceed to the verification gate rather than processing all remaining rules. The remaining rules have 40+ signals each and would consume too much context."*

**这证实了 CHANGE-003 的门控决策是错误的**。不是 Agent 启动开销太大，而是串行内联根本无法保证规则完整性——LLM 总有动力在上下文耗尽前自行停止。

## 二、TDD 验证目标（先于实施）

### V1: 规则完整性
- **目标**: 分区计划中每个 `(rule, batch)` 都被处理（pilot batch + 所有剩余 batch）
- **度量**: `coverage-gate.py --plan partition-plan.json --scan-dir <scan>` 通过（exit 0）
- **当前**: BLOCKED (10/571)

### V2: Finding 门禁通过
- **目标**: `verification-gate.py` 产出 confirmed > 0，needs_review == 0
- **度量**: `gate-audit.json` 中 needs_review == 0
- **当前**: 15 needs_review, 0 confirmed（所有 finding 缺 artifacts/qmatrix）

### V3: 信号坐标片段读取
- **目标**: LLM 每个 batch 只读 `rule.md` + 信号锚定的源码片段（offset/limit），不读完整文件
- **度量**: session log 中完整文件 Read 次数 == 0
- **当前**: 13/13 源文件被完整读取

### V4: Q-matrix canonical 名对齐
- **目标**: Judge verdict 中 Q1/Q2/Q3 字段名与 rule.md Detection Spec 中的 canonical 名一致
- **度量**: verification-gate Q-matrix 校验不需要机器可提取的映射
- **当前**: LLM 自创 Q 名，无法通过校验

### V5: 上下文隔离（每个 (rule, batch) 独立上下文）
- **目标**: 每个规则 batch 在独立 Agent 子代理中执行，不共享主上下文
- **度量**: 主 dispatcher 上下文在 Phase 2 阶段仅消费完成事件通知，不累积 Investigation 内联内容
- **当前**: 主上下文累积全部 3 条规则的 Investigation 内容 + 完整源文件

## 三、TDD 验收流程

```
1. 修复 implementation
2. 部署到 OpenCode
3. 执行 /secguard examples/cpp-vuln-demo-no-answers/src cpp
4. 检查 session log 验证 V1-V5
5. 运行 coverage-gate.py → exit 0
6. 运行 verification-gate.py → needs_review == 0
7. 运行 verify-recall.py → recall >= 基线
```

所有目标必须在单次扫描中同时达成，才算验收通过。

## 四、修复方案概要

### 4.1 恢复 per-rule Agent 隔离（撤销 CHANGE-003 门控）

ADR-006 原始设计：**每个 (rule, batch) 一个隔离任务**。Claude Code 用 Agent 子代理，OpenCode 无后台任务但必须通过某种机制实现上下文隔离。

OpenCode 当前约束：TUI 无后台任务 → 无法真并发。但可以：
- **串行 Agent 模式**：每 (rule, batch) 起一个内联 Agent（Agent 工具带 subagent_type），Agent 完成后返回 findings，主 dispatcher 仅收 findings + 写工件
- 每个 Agent 的上下文是干净的——不累积其他 rule 的调查内容

### 4.2 强制信号坐标片段读取

模板必须明确禁止全文读取：
- 每个 Agent 只能 `Read` rule.md + signal 坐标指定的源码窗口（`Read(file, offset=signal.line-5, limit=20)`）
- 禁止不带 offset/limit 的 Read 调用

### 4.3 修复 record-finding.py artifacts/qmatrix 字段

verification-gate 期待 finding JSON 包含 artifacts 和 qmatrix 字段。record-finding.py 当前不写这些字段。

### 4.4 修复 OpenCode 模板 coverage-gate 参数

从 `--index` 改为 `--plan`（对齐 coverage-gate.py CLI）。
