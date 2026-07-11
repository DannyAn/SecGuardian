# Progress — FEATURE-006: Context-Budget Partitioning

> **隶属**: EPIC-011 / FEATURE-006
> **状态**: 🔄 进行中（代码修复完成，TDD 验证待执行）

## 状态总览

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 用户三关切驱动（per-rule 隔离/批量不稳/30-skill 慢）|
| 📝 ADR-006 | ✅ per-rule 隔离 + 引擎预过滤 + 有界 batch + 平台无关 partition |
| 🔨 引擎工具 | ✅ `partition-signals.py`（per-rule 分组 + batch，TDD）|
| 🔨 命令模板编排 | ✅ F1（三平台恢复 Steps 4-8 + partition 消费）|
| 🐛 CHANGE-003 修复 | ✅ 知识加载 bash cat→Read + Agent 门控逻辑 |
| 🐛 CHANGE-004 修复 | ✅ TDD per-rule Agent 隔离强制执行（串行内联证伪）|
| 🧪 TDD 验证 (Task #9) | 🔄 ses_0af3 暴露 OpenCode batch 合并问题，CHANGE-005 修复中 |

## 进度
- [x] ADR-006 调度架构决策 ✅ 2026-07-10
- [x] `partition-signals.py` 引擎工具 ✅ 2026-07-10
- [x] 统一调度协议 `knowledge/protocols/dispatch-protocol.md` ✅ 2026-07-10
- [x] F1 命令模板编排（三平台一致）✅ 2026-07-10
- [x] CHANGE-003 Claude 调度效率审计 ✅ 2026-07-11
- [x] CHANGE-004 TDD per-rule Agent 隔离强制执行 ✅ 2026-07-11
  - verification-gate `load_findings()` 修复：findings.json → findings/ 目录树
  - Claude 模板 Steps 5-8 重写：强制 Agent 子代理 per (rule, batch)
  - OpenCode 模板 Phase 2 重写：串行上下文隔离模拟 + 信号坐标只读片段
  - OpenCode 模板 coverage-gate 参数修复：--index → --plan
  - benchmark.md detector 引用修复：web.sql-injection/race-condition → 实际规则 ID
  - benchmark.md 路径修复：fp-verification-demo → cpp-vuln-demo-no-answers
  - dispatch-protocol.md 更新：移除"统一串行内联基线"，改为 per-rule 上下文隔离
  - Phase 3 管道验证更新：workers/ 目录结构改为 <rule_id>/<batch_id>/
- [x] CHANGE-005 OpenCode batch delegation enforcement ✅ 2026-07-11
  - ses_0af3 证明 Phase 1 正确，但 Phase 2 仍可合并 30 个 batch 到单个 Task
  - OpenCode 模板改为每个 nonempty `(rule_id,batch_id)` 必须单独 Task 子代理
  - self-check 修复：secguard 模板缺陷必须计入失败
- [ ] TDD 验证执行 (Task #9) 🔄 — 需重新运行 OpenCode 扫描验证 V1-V5 + one-Task-per-batch
- [ ] 跨平台单源生成（FEATURE-005，进一步消除漂移）

## 关键里程碑
- 2026-07-10: ADR-006 定调度架构
- 2026-07-11: CHANGE-003 串行内联门控被测试证伪
- 2026-07-11: CHANGE-004 恢复 per-rule Agent 隔离（TDD 驱动）
- 2026-07-11: CHANGE-005 修复 OpenCode 合并 batch 委派与 self-check 假绿

## 阻塞项
- CHANGE-005 后需要用户在 OpenCode 中重新执行 `/secguard` 扫描并分享 session log，验证每个 nonempty batch 单独 Task 执行
