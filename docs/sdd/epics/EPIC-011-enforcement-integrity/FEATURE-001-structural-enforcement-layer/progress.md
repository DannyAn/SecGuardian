# Progress — FEATURE-001: Structural Enforcement Layer + Verification Oracle

> **隶属**: EPIC-011 / FEATURE-001
> **状态**: 🔄 进行中（设计四环就绪，实现待启动）

## 状态总览

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 已记入 brainstorm-log.md |
| 📋 Spec | ✅ 就绪 |
| 📝 ADR | ✅ 就绪（ADR-001~004）|
| 📐 Plan | ✅ 就绪（TG-A~D，13 Task）|
| 🔨 Task | 🔄 TG-A 启动中 |
| 📊 Progress | 🔄 本文件 |
| 🔄 Change | ⬜ 无 |

## Task 进度

### TG-A: CI 速赢
- [x] TASK-001 F2 CI exit code + severity 强校验 ✅ 2026-07-10（--ci 真退出码 + _normalize_severity + record-finding --from-file 校验；e2e §6 显式断言进程 exit 1）
- [x] TASK-002 F12 渲染 detail block ✅ 2026-07-10（§3 detail block 移入 for 循环 + data_flow continue 修复）
- [x] TASK-003 F13 ci-check exit 位置 ✅ 2026-07-10（§6 移到结果汇总前，exit 移到末尾）
- [x] 附带 F4：e2e §12 两处过时路径检查修复（knowledge/audit-rules→扩展、commands→平台子目录）

### TG-B: Pillar A 强制层
- [ ] TASK-004 verification-gate.py 骨架
- [ ] TASK-005 record-finding.py 接入
- [ ] TASK-006 Q-matrix + 工件校验
- [x] TASK-007 信号覆盖下限 ✅ 2026-07-10（`coverage-gate.py`：self-test 绿；真实 cpp PASSED 11.17%；模拟 batch-suppression BLOCKED exit 1；e2e §15 接入）

### TG-C: Pillar B 验证回路
- [x] TASK-008 verify-recall.py ✅ 2026-07-10（ground-truth oracle：normalize_verdict + case_matches_finding + evaluate；self-test 确定性数学绿；python/cpp 真实基线产出 recall/precision）
- [x] TASK-009a recorder 从 index 自动回填 function ✅ 2026-07-10（TDD 验证 my_func 自动解析；修 function=N/A 数据缺口）
- [x] TASK-009b e2e §14 接入 oracle ✅ 2026-07-10（self-test 硬门禁 + python 真实基线 informational）
- [ ] TASK-009c ground truth 补全（人工标注，待确认范围）
- [ ] TASK-009d 删 verify-lang-pipeline.sh 伪造（待真扫描可自动化后）
- [ ] TASK-010 self-check mini-oracle

#### Oracle v1 集成审视暴露的问题（待 TASK-009 处理）
1. **ground truth 不完整**：python expected-results 仅 16 case（p0-p3/tp 文件），未覆盖 webapp.py/crypto_utils.py 等漏洞文件 → 真实漏洞被判 FP，precision 虚低（0.111）。需补全 expected-results 覆盖所有漏洞文件。
2. **findings function=N/A**：v5.0 findings_index 的 function 多为 N/A（recorder 数据缺口，agent 未填）→ 依赖 file-basename 降级匹配。需 recorder 强制 function。
3. **cpp 行号对齐**：cpp ground truth 用 line 定位且 function 缺失，与 finding 行号 ±2 未对齐 → recall 虚低（0.0）。需 expected-results 补 function 或对齐行号。

### TG-D: 死代码与协议
- [ ] TASK-011 恢复 claude Steps 4-8
- [ ] TASK-012 diff_parser 接入
- [ ] TASK-013 协议字段

## 关键里程碑
- 2026-07-10: 设计四环就绪，待评审

## 阻塞项
- TASK-006 待 FEATURE-003 Q-matrix 极性定义（先 stub）
- TASK-008 待 expected-results.json 人工复核（并行）
