# Plan — FEATURE-007: Strategic Repositioning

> **Feature**: FEATURE-007
> **状态**: ✅ Complete (all tasks in v1)
> **计划日期**: 2026-06-30
> **实际完成**: 2026-06-30

---

## 任务清单

| # | 任务 | 文件 | 工时 | 状态 |
|---|------|------|------|------|
| 1 | README-EN.md 分析 | — | 30m | ✅ |
| 2 | README.md 英文重写（v1） | README.md | 45m | ✅ |
| 3 | /secreview 命令微重构 | commands/secreview.md | 30m | ✅ |
| 4 | /secreview 5 语言 SKILL.md 重构 | skills/secreview/{cpp,go,java,python,js}/SKILL.md | 45m | ✅ |
| 5 | /secfix 命令定义 | commands/secfix.md | 15m | ✅ |
| 6 | README.md 自检修正（Why / Deep AI / Rule Packs / Vision） | README.md | 30m | ✅ |
| 7 | README.md 四门工作流 + /secfix 插入 | README.md | 20m | ✅ |
| 8 | self-check 验证 | — | 10m | ✅ |
| 9 | brainstorm-log.md 补充 | docs/sdd/brainstorm-log.md | 15m | ✅ |
| 10 | FEATURE-007 SDD 包建包 | spec.md + adr.md + plan.md + progress.md | 30m | ✅ |

**总工时**: ~4.5h
**并行度**: 任务 1→2→3→4 顺序依赖，5 可并行，6→7→8 顺序依赖

---

## 依赖关系

```
README-EN.md 分析 (1)
    │
    ▼
READNE.md 重写 (2)
    │
    ├────────────────────────────────────────────────┐
    │                                                │
    ▼                                                ▼
/secreview 命令重构 (3)                   /secfix 命令定义 (5)
    │
    ▼
/secreview 5 语言 SKILL.md (4)
    │
    └──────────────────────────────┬─────────────────┘
                                   │
                                   ▼
                     README 自检修正 (6)
                                   │
                                   ▼
                     README 四门工作流 (7)
                                   │
                                   ▼
                      self-check 验证 (8)
                                   │
                                   ├── brainstorm-log (9)
                                   │
                                   └── SDD 包 (10)
```

---

## 回退方案

如果 self-check 因本次修改失败：

1. 检查 skills/secreview/ 5 个目录是否齐全（预期 5，`ls skills/secreview/`）
2. 检查每个 SKILL.md 的 YAML frontmatter 是否合法（`---` 成对出现）
3. 检查 commands/secreview.md 是否正确引用 protocols 路径
4. 检查 commands/secfix.md 是否符合 /commands 目录规范
5. 如果以上都通过但仍失败，回退路径：`git checkout -- README.md commands/secreview.md commands/secfix.md skills/secreview/*/SKILL.md`
