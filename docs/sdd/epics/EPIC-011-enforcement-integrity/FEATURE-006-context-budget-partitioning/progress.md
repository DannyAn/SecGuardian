# Progress — FEATURE-006: Context-Budget Partitioning

> **隶属**: EPIC-011 / FEATURE-006
> **状态**: 🔄 进行中（ADR + 引擎工具就绪，命令模板编排待 F1）

## 状态总览

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 用户三关切驱动（per-rule 隔离/批量不稳/30-skill 慢）|
| 📝 ADR-006 | ✅ per-rule 隔离 + 引擎预过滤 + 有界 batch + 平台无关 partition |
| 🔨 引擎工具 | ✅ `partition-signals.py`（per-rule 分组 + batch，TDD）|
| 🔨 命令模板编排 | ⬜ F1（恢复 Claude secguard.md pipeline + 消费 partition 计划）|

## 进度
- [x] ADR-006 调度架构决策 ✅ 2026-07-10
- [x] `partition-signals.py` 引擎工具 ✅ 2026-07-10（self-test 绿；真实 cpp 16 rules/21 batches；cat→category 别名；e2e §17）
- [ ] 命令模板消费 partition 计划 + 平台适配调度（Claude=Agent/batch, OpenCode=串行）— F1
- [ ] 跨平台一致性（FEATURE-005 单源）

## 关键里程碑
- 2026-07-10: ADR-006 定调度架构；partition 工具证明 per-rule 隔离可负担（引擎预过滤，非旧 30-skill 重扫）

## 阻塞项
- 命令模板编排依赖 F1（Claude secguard.md 恢复 Steps 4-8）+ FEATURE-005（单源）
