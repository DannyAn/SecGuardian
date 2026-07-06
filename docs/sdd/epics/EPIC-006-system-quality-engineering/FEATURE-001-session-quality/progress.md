# FEATURE-001 会话质量与稳定性增强 — 进度追踪

> **Epic**: EPIC-006-system-quality-engineering

## 当前状态

- [x] Spec 完成
- [x] ADR 完成
- [x] Plan 完成
- [x] TASK-001: record-finding.py 增强
- [x] TASK-002: 命令模板加固
- [x] TASK-003: Token/路径效率
- [x] self-check.sh 非跳过标记检查

## 变更记录

### CHANGE-001: 首次实施 (2026-07-06)

- record-finding.py: `--from-stdin` 独立 JSON, argparse 拒未知参数
- 命令模板: timeout 30s, 非跳过标记, cd USER_PROJECT, 相对路径
- Token: todowrite → tasks, $RECORDER → $SECGUARDIAN_HOME 固化
- self-check: @secguardian:non-skippable 完整性检查
