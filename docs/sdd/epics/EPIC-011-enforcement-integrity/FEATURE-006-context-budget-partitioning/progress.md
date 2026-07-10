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
- [x] 统一调度协议 `knowledge/protocols/dispatch-protocol.md` ✅ 2026-07-10（单一真理源：统一串行内联 + 引擎强制 + 平台差异隔离于调度原语）
- [x] F1 命令模板编排（三平台一致）✅ 2026-07-10
  - Claude secguard.md：恢复 Steps 4-8（曾整段缺失）+ partition + Step 8.5 强制 + 协议引用
  - Gemini secguard.toml：恢复 Steps 4-8（曾整段缺失，与 Claude 同病）+ partition + 强制 + 协议引用
  - OpenCode secguard.md：修 Step 3 断围栏 + partition + Step 8.5 强制 + 协议引用（保留 inline pipeline）
  - 三平台一致校验：Step 4 / partition / 协议引用 / coverage-gate 各 1 处
- [ ] 跨平台单源生成（FEATURE-005，进一步消除漂移）

## 关键里程碑
- 2026-07-10: ADR-006 定调度架构；partition 工具证明 per-rule 隔离可负担（引擎预过滤，非旧 30-skill 重扫）

## 阻塞项
- 命令模板编排依赖 F1（Claude secguard.md 恢复 Steps 4-8）+ FEATURE-005（单源）
