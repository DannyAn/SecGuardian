# FEATURE-002: Architecture Contract Implementation

> **隶属 Epic**: EPIC-005 Architecture Refactoring
> **版本**: v0.1 (Draft)
>
> **修改时间**: 2026-07-04
> **目标版本**: v0.13.0
> **核心原则**: 行为零变化，只增加架构可见性

---

## 1. Problem Statement

### 1.1 架构文档与代码之间存在鸿沟

FEATURE-001 产出了 8 份架构文档和 3 份合约文档，定义了：
- Command 层：只做参数解析 + 调度 + 输出路径定义
- Skill 层：只做 detector 选择规则
- Engine 层：执行检测逻辑（当前不存在，LLM prompt 代行）

但实际 production 代码的结构与架构定义不对应：
- commands/secguard.md 包含 5 步执行管线（594 行），混有 index.json 使用方法、输出目录创建、SARIF schema
- skills/secguard/cpp/SKILL.md 包含 Phase 1-5 全流程（141 行），混合 detector 选择和执行指令
- 三层职责在代码层面没有边界

### 1.2 不能简单删除

当前系统没有独立的 Engine 层。LLM prompt 本身是 execution engine。
删除 commands/skills 中的执行指令 = 破坏系统可用性。

### 1.3 需要渐进式架构注入

本轮的目标不是"实现理想架构"，而是：
- 在保持所有现有行为不变的前提下
- 为 commands/skills 增加架构可见性
- 让每个 section 明确标注其所属的架构层
- 为未来 Engine 提取做好标记

---

## 2. Requirements

### REQ-001: Commands 增加架构分层标记

4 个 command 文件（secguard, secreview, secfix, secaudit）增加分层结构：

- **Command Layer** 分组：Usage / Behavior / Output Path / Namespace Reference
- **Engine Layer** 分组：Pre-flight / Steps 1-5 / Output generation
- 每个分组标注所属架构层，引用对应合约文档
- 不删除任何现有内容

### REQ-002: Skills 分为 Detector Selection + Engine Instructions

11 个 SKILL.md 文件重组为两个明确区域：

- **Detector Selection**（Skill 层职责）：检测器列表、选择规则、语言上下文
- **Engine Instructions**（Engine 层职责，标注为过渡态）：Phase 1-5 / Execution Phases / 输出格式化

不删除任何现有内容。结构和语言调整，行为不变。

### REQ-003: 所有 Engine 层内容引用 engine_contract.md

Commands 的 Engine 层分组和 Skills 的 Engine Instructions 区域
必须引用 `internal/engine/engine_contract.md`，标注这些内容
在未来属于 Engine 的职责范围。

### REQ-004: 输出层内容引用 output_contract.md

所有输出相关内容（SARIF、report.md、输出目录结构）引用
`internal/output/output_contract.md`。

---

## 3. Non-Requirements (明确不做的事)

| 不做 | 原因 |
|------|------|
| 删除任何执行指令 | 无 Engine 替代，破坏可用性 |
| 改变扫描行为 | 架构注入不影响运行时 |
| 改变 detector 内容 | detector 是独立资产 |
| 修改 Go 代码 | 范围约定（本轮不动 internal/） |
| 修改 knowledge/ | 知识独立于执行方式 |
| 修改合约文档 | 合约已基线化 |

---

## 4. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | 4 个 command 文件均有层标记（Command Layer / Engine Layer 分组） | grep section header |
| 2 | 11 个 SKILL 文件均有 Detector Selection + Engine Instructions 区域 | grep section header |
| 3 | Engine 层内容引用 engine_contract.md | grep engine_contract |
| 4 | 输出内容引用 output_contract.md | grep output_contract |
| 5 | 行为不变：示例代码扫描结果与基线一致 | e2e-verify |
| 6 | self-check 通过 | exit 0 |

---

## 5. 相关文档

- `internal/engine/engine_contract.md` — Engine 职责定义
- `internal/output/output_contract.md` — 输出职责定义
- `docs/architecture/architecture-vNext.md` — 整体架构
- `docs/architecture/runtime-model.md` — 执行上下文
- `docs/sdd/brainstorm-log.md` — 方案讨论记录
