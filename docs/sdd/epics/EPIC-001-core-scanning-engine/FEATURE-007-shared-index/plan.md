# FEATURE-007: 共享索引 — Plan

> **Goal**: 消除重复索引，所有命令复用同一 index.json
> **改动量**: 约 15 个文件，分 6 个 Task

## Tasks

- [ ] **TASK-001**: commands/secguard.md — Step 2 索引路径改为共享、新增 `--force` 逻辑、Step 4 输出目录改为 `secguardian/<cmd>/scans/`
- [ ] **TASK-002**: commands/secaudit.md + secreview.md — 同步 TASK-001 的变更
- [ ] **TASK-003**: scripts/secguardian-index wrapper — 支持共享路径查找
- [ ] **TASK-004**: scripts/render-report.py — `--index` 默认查找共享路径
- [ ] **TASK-005**: scripts/validate-index.py — 共享 index.json 查找
- [ ] **TASK-006**: knowledge/protocols/scan-output.md — 目录结构文档更新
- [ ] **TASK-007**: E2E 验证 + 自检 + deploy

## Verification

```bash
bash scripts/self-check.sh
bash scripts/e2e-verify.sh --quick
# 手动验证: 运行 /secguard，检查 index.json 是否在共享路径
ls .codeagent/secguardian/index.json
```