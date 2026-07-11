# Progress — FEATURE-007: Signal Precision & Function-Level Context Assembly

> **隶属**: EPIC-011 / FEATURE-007
> **状态**: ⬜ 设计就绪，待评审

## 状态总览

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 2026-07-11 — OpenCode 崩溃回溯 + 跨平台审计 + 信号精度剖析 |
| 📋 Spec | ✅ 就绪 — 5 个 REQ + 6 个 TDD 验收标准 |
| 📝 ADR | ✅ 就绪 — ADR-007~012 |
| 📐 Plan | ✅ 就绪 — P1~P4 + Cross-language |
| 🔨 Task | ⬜ 待开工 |

## 进度
- [x] TASK-001: C++ callee 级 signal_source（9 个 rule.md） ✅ 2026-07-11
- [ ] TASK-002: 跨语言 callee 路由对齐 ⬜
- [x] TASK-003: prefilter.py 骨架 + null_dereference 预筛 ✅ 2026-07-11
- [x] TASK-004: prefilter.py double_free/memory_leak 预筛 ✅ 2026-07-11
- [x] TASK-005: prefilter.py command_injection 预筛 ✅ 2026-07-11
- [ ] TASK-005b: prefilter.py buffer_overflow 三层写入校验 ⬜
- [x] TASK-006: V1+V2 调用图合并 ✅ 2026-07-11
- [x] TASK-007: FunctionCallContext 类型 + 索引器导出 ✅ 2026-07-11
- [ ] TASK-008: partition-signals --group-by function ⬜
- [ ] TASK-009: Investigation Pipeline 适配函数上下文 ⬜
- [ ] TASK-010: 各语言 rule.md 对齐 ⬜
- [ ] TASK-011: prefilter.py + FunctionCallContext 打包部署 ⬜
- [ ] TASK-012: MAX_BATCHES 硬上限 + severity 优先调度 ⬜
- [ ] TASK-013: 全量回归（self-check + ci-check + e2e） ⬜
- [ ] TASK-014: OpenCode 实际扫描验证 ⬜

## 关键里程碑
- 2026-07-11: 设计四环就绪（本 Feature）

## 阻塞项
- 无外部阻塞。依赖的索引器数据（variable_writes/pointer_validations/cfgs/taint_flows）已存在。
