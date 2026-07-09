# EPIC-010: Investigation Engine — 从 Rule Engine 到 Evidence-Driven Investigation Engine

> **Status**: Inception
> **创建**: 2026-07-09
> **目标版本**: v0.19.0+
> **来源**: LLM-Investigation-Architecture-Guide.md + Brainstorm 2026-07-09
> **前任对照**: EPIC-009（预筛器方案 — 被 Investigation Engine 取代为架构演进方向）

---

## 1. 概述

SecGuardian 当前的架构是 **Rule Engine**：

```
Command → Skill → Rule → Worker → Finding
```

这套架构的问题在 v0.18.0 生产扫描中完全暴露：索引器找到 1358 个信号，LLM 全部抑制为"安全采样"，产出 0 findings。

EPIC-009 的应对是打补丁（加预筛器降信号量），但**根因是架构问题**——Rule Engine 的推理能力被 Rule 文件锁死，Worker 只有一条推理路径，没有多假设思考，没有 Counter Evidence，没有跨 Skill 推理。

**EPIC-010 的核心目标**是将架构从 Rule Engine 演进为 **Evidence-Driven Investigation Engine**。

评价标准：**Recall > Precision**。先发现，再证明。不要先否定，再调查。

---

## 2. 关键区别：EPIC-009 vs EPIC-010

| 维度 | EPIC-009（已实施的基础设施） | EPIC-010（本 Epic） |
|------|----------------------------|--------------------|
| 对架构的态度 | 修补（加预筛器层） | 替换（替换 Worker 模型） |
| 使用 EPIC-009 产出 | 预筛器的 `prescreen_verdict` 作为 Signal 元数据保留 | 预筛器的确定性分析作为 Signal 的 `safe/unknown` 标签 |
| 推理模型 | 逐信号验证 Rule | 多假设 + 自主调查 + 独立裁决 |
| Signal 含义 | "可能有问题" | "这是调查起点，生成 3~5 个假设方向" |
| Worker 等价物 | W1-W5 逐步骤执行 | Investigator 自主调查缺口的证据 |
| 判定机制 | 判定矩阵（W5 Q1-Q2-Q3） | Judge 独立读 Evidence + Counter Evidence 裁决 |
| 跨 Skill 推理 | 无（各 Skill 独立） | 有（一个调查可以跨越多个 Skill 的领域知识） |

**EPIC-009 的产出不会废弃**：预筛器在索引器中对信号做确定性安全判定，这仍然是 Signal 层的补充元数据。差别只是在 Investigation Engine 中，Signal 即使被预筛器标记 safe，仍然会生成 Hypothesis（如"H5: 实际安全"）并在 Counter Evidence 中得到确认。

---

## 3. Feature 分解

| # | Feature | 对应 Guide 阶段 | 说明 | 优先 |
|---|---------|---------------|------|------|
| 1 | **Signal Extraction Dispatcher** | Phase 1 (§4) | Dispatcher 不再分派 Skill/判定漏洞类型，只输出 Signal + 上下文 | P0 |
| 2 | **Rule 瘦身 + Skill 重构（原型）** | Phase 2-3 (§11,§12) | 选 1 个 Rule 做样板删除 Step1-Step5，改为领域知识 | P0 |
| 3 | **Hypothesis + Investigator + Judge** | Phase 4-5 (§5-7,§9-10) | 新推理管线：Signal→Hypothesis→Investigator→Evidence→Counter→Judge | P0 |
| 4 | **Evidence Graph 显式化** | Phase 6 (§8) | 结构化的 Evidence（Source/Propagation/Sink/Lifetime/Ownership） | P1 |
| 5 | **Prompt 全量迁移** | Phase 7 (§19) | 所有命令 + Skill 的 Prompt 按 Investigation Engine 模型重写 | P1 |

---

## 4. 迁移顺序（Guide 对照）

```
Phase 1: Dispatcher     → FEATURE-001   → commands/*.md 重构为 Signal Extraction
Phase 2: Rule 瘦身       → FEATURE-002   → buffer_overflow.md 样板
Phase 3: Skill 重构      → FEATURE-002   → cpp/SKILL.md 重构
Phase 4: Hypothesis      → FEATURE-003   → Hypothesis Generator prompt
Phase 5: Judge           → FEATURE-003   → Judge Agent prompt
Phase 6: Evidence Graph  → FEATURE-004   → Evidence schema + validation
Phase 7: 全部 Skill 迁移  → FEATURE-002,005 → 全部 60+ detector + 27 skill
```

---

## 5. 里程碑

| 里程碑 | 内容 |
|--------|------|
| M0: 架构设计 | Epic + Spec + ADR + Plan 就绪 |
| M1: Signal Extraction | FEATURE-001 完成——Dispatcher 不再判定漏洞类型 |
| M2: 样板完成 | FEATURE-002 + 003 完成——1 个完整 Investigation 流水线 |
| M3: 全量迁移 | FEATURE-004 + 005 完成——全部 Rule/Skill/Prompt 迁移 |
| M4: 回归验证 | 生产项目 Recall 验证 > EPIC-009 基线 |

---

## 6. 风险与约束

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Investigation 管道 token 消耗暴涨 | 高 | 中 | Hypothesis 压缩策略（先出 Top-3），Evidence 只锚定关键行 |
| Investigator 自主无限搜索 | 高 | 高 | 深度限制（最多 3 层调用链）+ 文件数限制（最多 5 个源文件） |
| Judge 过于保守 | 中 | 高 | "Unknown 不允许自动降级 Safe"硬约束 |
| Agent 回到旧 Worker 模式 | 高 | 高 | Dispatcher prompt 硬编码禁止，Judge prompt 强制独立裁决 |
| Counter Evidence 空转 | 中 | 低 | 即使全部 Safe 也要求 Counter Evidence |

---

## 7. 成功标准

| 指标 | 当前（v0.18.0） | 目标 |
|------|----------------|------|
| 生产项目 Recall | ~0% (0/1358) | > 60% verified findings |
| 多假设覆盖率 | 0%（每条信号只有 1 个假设方向） | > 80%（每条信号 ≥ 3 假设） |
| Counter Evidence 覆盖率 | 0% | 100%（每个 Finding 必须有 Counter Evidence 节） |
| Evidence 锚定率 | ~30%（模糊描述） | 100%（都引用 line/function/variable） |
| Unknown 降级 Safe | 100%（全部被抑制） | 0%（Unknown 必须保留在报告中） |
