# Plan — FEATURE-008: Audit Framework

> **Feature**: FEATURE-008
> **状态**: ✅ Complete (MVP)
> **计划日期**: 2026-06-30
> **实际完成**: 2026-06-30

---

## 任务清单

| # | 任务 | 文件 | 工时 | 状态 |
|---|------|------|------|------|
| 1 | FEATURE-008 SDD 包 | spec.md + adr.md + plan.md + progress.md | 30m | ✅ |
| 2 | 创建 audit-framework/ 目录骨架 | audit-framework/ | 5m | ✅ |
| 3 | 创建 rulepacks/ 目录 + README | audit-framework/rulepacks/ | 10m | ✅ |
| 4 | 创建 secguardian rule pack + pack.json | audit-framework/rulepacks/secguardian/ | 20m | ✅ |
| 5 | 创建 engine/ 文档 | audit-framework/engine/README.md | 15m | ✅ |
| 6 | 创建 templates/ 文档 | audit-framework/templates/README.md | 10m | ✅ |
| 7 | 创建 reporters/ 文档 | audit-framework/reporters/README.md | 10m | ✅ |
| 8 | 更新 commands/secaudit.md | commands/secaudit.md | 30m | ✅ |
| 9 | 更新 README.md | README.md | 10m | ✅ |
| 10 | self-check 验证 | — | 10m | ✅ |

**总工时**: ~2.5h
**依赖**: FEATURE-007（四门工作流）必须先完成

---

## 依赖关系

```
FEATURE-007 (四门基础)
    │
    ▼
SDD 包 (1)
    │
    ▼
目录骨架 (2)
    │
    ├── rulepacks/README (3)
    │       │
    │       ▼
    │   secguardian pack (4)
    │
    ├── engine/README (5)
    ├── templates/README (6)
    └── reporters/README (7)
    │
    ├── commands/secaudit.md (8)
    └── README.md (9)
        │
        ▼
    self-check (10)
```

---

## 回退方案

如果 self-check 因本次修改失败：
1. 检查 `audit-framework/` 下是否有正确的 4 个子目录
2. 检查 `pack.json` JSON 格式（`python3 -m json.tool pack.json`）
3. 如果 commands/secaudit.md 引用路径错误，恢复旧版本
4. 极端回退：`git checkout -- audit-framework/ commands/secaudit.md`
