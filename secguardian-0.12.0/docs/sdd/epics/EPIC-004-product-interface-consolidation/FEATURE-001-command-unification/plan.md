# Command Unification — 实施计划

> **Feature**: FEATURE-001-command-unification
> **Epic**: EPIC-004-product-interface-consolidation
> **状态**: 📐 Plan 阶段
> **预估**: 10-12 个人日（含验证）

---

## Architecture

```
commands/                              ← 命令格式统一 + Git diff 对齐
  secguard.md                            <path> <language> [filters]
  secaudit.md                            <path> <language> [--focus <domain>]
  secreview.md                           <path> <language>

knowledge/                             ← 知识层重组
  guard-rules/                          从 detectors/ 改名（61 个文件，内容不变）
  audit-rules/                          从 skills/secaudit/*/SKILL.md 迁移（17 个文件）
  review-rules/                         从 skills/secreview/*/references/*.md 迁移（5 个文件）
  language-index.md                     新增，构建时自动生成

skills/                                ← workflow 层
  secaudit/workflow-secaudit/SKILL.md   新增，17 phase 编排

scripts/                               ← 构建自动化
  sync-language-index.sh                新增·扫描 guard-rules frontmatter
  sync-toml.sh                          新增·.md → .toml 转换

commands/gemini/                       ← 从手工维护变为构建 artifact
  secguard.toml                         构建时生成，不再 git 跟踪
  secaudit.toml                         同上
  secreview.toml                        同上
```

---

## Tasks

### Phase 1: 知识层迁移（先做纯改名，不动逻辑）

| Task | 描述 | 文件 |
|------|------|------|
| TASK-001 | `knowledge/guard-rules/` → `knowledge/guard-rules/` 纯改名 | 61 个 .md 文件路径 |
| TASK-002 | 从 `skills/secaudit/*/SKILL.md` 迁移审计知识 → `knowledge/audit-rules/*.md` | 17 个文件 |
| TASK-003 | 从 `skills/secreview/*/references/*.md` 迁移反模式 → `knowledge/review-rules/*.md` | 5 个文件 |
| TASK-004 | 批量更新所有引用旧路径的 10+ 文档 | README, DEVELOPER, AGENTS, commands 等 |

### Phase 2: 构建自动化

| Task | 描述 | 文件 |
|------|------|------|
| TASK-005 | `scripts/sync-language-index.sh` — 扫描 guard-rules frontmatter 的 `language` 字段，生成 `knowledge/language-index.md` | 新增脚本 |
| TASK-006 | `scripts/sync-toml.sh` — 从 .md → .toml 转换（提取 frontmatter description + 正文） | 新增脚本 |
| TASK-007 | `package.sh` 集成 — 在构建流程中插入 sync-language-index + sync-toml 步骤 | scripts/package.sh |
| TASK-008 | `.gitignore` 更新 + `commands/gemini/` 下 .toml 移除 git 跟踪 | .gitignore, git rm |

### Phase 3: 命令格式重写

| Task | 描述 | 文件 |
|------|------|------|
| TASK-009 | `commands/secguard.md` — 参数格式改为 `<path> <language> [filters]`；Step 2.5 职责纠正；Step 3 指向 language-index.md | commands/secguard.md |
| TASK-010 | `commands/secreview.md` — 参数格式统一 + 引用更新 | commands/secreview.md |
| TASK-011 | `commands/secaudit.md` — 全量重写：参数格式、workflow 路由逻辑、--focus 处理 | commands/secaudit.md |

### Phase 4: SecAudit Workflow

| Task | 描述 | 文件 |
|------|------|------|
| TASK-012 | `skills/secaudit/workflow-secaudit/SKILL.md` — 17 phase 编排 + 全量/单项路由逻辑 | 新增 |

### Phase 5: 验证

| Task | 描述 | 命令 |
|------|------|------|
| TASK-013 | L1 设计一致性检查 | `bash scripts/self-check.sh` |
| TASK-014 | 端到端验证：三个命令、五语言 | `bash scripts/e2e-verify.sh` |

---

## Task 依赖关系

```
TASK-001 ─┐
TASK-002 ─┤
TASK-003 ─┤
TASK-004 ─┤
          ├──→ TASK-005 ─┐
          │              ├──→ TASK-007 ─→ TASK-008
          └──→ TASK-006 ─┘
TASK-009 ─────────────────────────→ TASK-010 ─→ TASK-011
                                                ↓
                                          TASK-012
                                                ↓
                                          TASK-013 ─→ TASK-014
```

- Phase 1（TASK-001~004）必须先完成，因为 Phase 2 和 Phase 3 都依赖新路径
- TASK-005 和 TASK-006 可并行
- TASK-009/010/011（命令重写）不依赖 Phase 1，可并行执行
- TASK-012（workflow）依赖 TASK-011（secaudit.md 重写完成）

---

## Verification

| 阶段 | 验证命令 | 通过标准 |
|------|---------|---------|
| Phase 1 后 | `bash scripts/self-check.sh` | 全绿，无路径引用错误 |
| Phase 2 后 | `scripts/sync-language-index.sh && cat knowledge/language-index.md` | cpp/java/python/go/js 五语言各有对应规则 |
| Phase 2 后 | `scripts/sync-toml.sh && diff <(cat commands/gemini/secguard.toml) <(git show HEAD:commands/gemini/secguard.toml 2>/dev/null)` | 内容一致（仅 metadata 字段可能有版本号变化） |
| Phase 4 后 | `bash scripts/self-check.sh && bash scripts/e2e-verify.sh` | L1 + L4 全绿 |
