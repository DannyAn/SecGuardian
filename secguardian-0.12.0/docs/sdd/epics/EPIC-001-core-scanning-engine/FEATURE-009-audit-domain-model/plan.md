# Plan — FEATURE-009: SecAudit Domain Model

> **Feature**: FEATURE-009
> **计划日期**: 2026-07-02

---

## 任务清单

| # | 任务 | 文件/目录 | 工时 | 依赖 |
|---|------|----------|------|------|
| 1 | FEATURE-009 SDD 包 | spec.md + adr.md + plan.md + progress.md | 30m | — |
| 2 | 删除 5 个分析方法 knowledge 文件 | knowledge/audit-rules/{attack-surface,data-flow,state-machine,taint,trust-boundary}-analysis.md | 5m | 1 |
| 3 | 新增 information-exposure.md | knowledge/audit-rules/information-exposure.md | 15m | 1 |
| 4 | 删除 15 个独立 skill 目录 | skills/secaudit/{5 analysis + 12 domain} — 保留 workflow-secaudit | 10m | 1 |
| 5 | 更新 workflow-secaudit/SKILL.md | skills/secaudit/workflow-secaudit/SKILL.md | 15m | 4 |
| 6 | 重写 commands/secaudit.md | commands/secaudit.md | 30m | 2-5 |
| 7 | 更新 docs/audit-framework/ 文档 | docs/audit-framework/architecture.md + workflow.md | 15m | 1 |
| 8 | 更新 manifest.json 和 self-check 计数 | manifest.json | 5m | 2 |
| 9 | 更新 docs/sdd/ 进度文档 | progress.md + brainstorm-log.md | 5m | 1-8 |
| 10 | self-check 验证 | — | 10m | 9 |

**总工时**: ~2h

---

## 依赖关系

```
SDD 包 (1)
    │
    ├── knowledge 清理 (2) ──┬── manifest 更新 (8)
    │                       │
    │                       └── self-check (10)
    │
    ├── information-exposure (3) ──┘
    │
    ├── skills 清理 (4) ──┬── workflow 更新 (5)
    │                     │
    │                     └── commands 重写 (6)
    │
    └── docs 更新 (7) ────┘
```

## 回退方案

如果 self-check 因本次修改失败：
1. 检查 knowledge/audit-rules/ 文件数
2. 检查 skills/secaudit/ 是否只有 workflow-secaudit
3. 检查 manifest.json 计数是否匹配
4. 极端回退: `git checkout -- knowledge/audit-rules/ skills/secaudit/ commands/secaudit.md manifest.json`
