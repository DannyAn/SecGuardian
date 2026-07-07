# Plan: FEATURE-001 会话质量与稳定性增强

> **Feature**: FEATURE-001-session-quality
> **日期**: 2026-07-06

## 文件变更清单

| 文件 | 变更类型 | 对应 Task |
|------|---------|-----------|
| `scripts/record-finding.py` | 修改 | TASK-001 |
| `commands/secguard.md` | 修改 | TASK-001 + TASK-002 + TASK-003 |
| `commands/secaudit.md` | 修改 | TASK-001 + TASK-002 + TASK-003 |
| `commands/secreview.md` | 修改 | TASK-001 + TASK-002 + TASK-003 |
| `commands/secfix.md` | 修改 | TASK-001 + TASK-002 + TASK-003 |
| `scripts/self-check.sh` | 修改 | TASK-002 |
| `docs/sdd/brainstorm-log.md` | 追加 | — |

## 实施顺序

```
TASK-001 (record-finding.py) → TASK-002 (命令模板) → TASK-003 (效率) → self-check.sh
```

1. 先改 `record-finding.py`（核心工具），确定新行为
2. 再改 4 个命令模板，引用新行为
3. 最后加 self-check 验证规则
