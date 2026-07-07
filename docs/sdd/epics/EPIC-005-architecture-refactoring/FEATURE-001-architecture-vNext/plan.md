# Plan: Architecture Documentation vNext

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Epic**: EPIC-005 Architecture Refactoring
> **目标**: 创建 8 份架构文档 + 3 份合约 + SDD 闭环
> **作者**: Codex / 2026-07-04

---

## Implementation Plan

### Phase 1: SDD Setup (已完成)

| # | 步骤 | 产出 | 状态 |
|---|------|------|------|
| 1 | 创建 EPIC-005 | epic.md | ✅ Done |
| 2 | 创建 FEATURE-001 spec | spec.md | ✅ Done |
| 3 | 创建 FEATURE-001 ADR | adr.md (7 ADRs) | ✅ Done |
| 4 | 创建 plan.md | 本文件 | ✅ Done |
| 5 | 创建 5 个 Task | tasks/TASK-001~005.md | 🔄 This |

### Phase 2: TASK Execution

| # | Task | 文档 | 依赖 | 预估 |
|---|------|------|------|------|
| 1 | TASK-001 | architecture-vNext.md | — | ~20 min |
| 2 | TASK-002 | runtime-model.md | — | ~15 min |
| 3 | TASK-003 | security-engine.md | — | ~20 min |
| 4 | TASK-004 | design-principles.md | ADR-001 (素材) | ~15 min |
| 5 | TASK-005 | readme-refactor-plan.md | README.md (输入) | ~15 min |
| 6 | TASK-006 | execution-model-current.md | Round 1 review | ~10 min |
| 7 | TASK-007 | engineering-principles.md | Round 1 review | ~10 min |

### Phase 3: Verification

| # | 验证 | 命令 |
|---|------|------|
| 1 | 8 个文件存在 | `ls docs/architecture/` && `ls internal/engine/` && `ls internal/output/` && `ls docs/ci-cd-interface.md` |
| 2 | 无 production 代码修改 | `git diff --stat` |
| 3 | self-check | `bash scripts/self-check.sh` |
| 4 | 更新 progress.md | 更新进度表 |

---

## 关键约束

1. **不改一行 Go** — 所有变更仅限于 docs/
2. **不改 README** — 只创建 readme-refactor-plan.md
3. **Security Engine 只定义，不实现**
4. **每个提案必须可逐步实现** — 能与现有实现共存
5. **输出质量** — 像主架构师写的一样，无营销语言

### Phase 4: Review Cycles

| Cycle | Scope | Changes |
|-------|-------|---------|
| Round 1 | Over-engineering correction | Collapsed dual-runtime, downgraded Engine to strategy, added 2 new docs |
| Round 2 | CI framing + deterministic pre-pass | CI = verification constraint layer; added deterministic signals + pre-pass authority + LLM May/Not |
| Round 3 | Layer boundary insights | Added 3 contract docs (engine/output/CI); deferred code changes (CHANGE-003) |

See changes/CHANGE-001, CHANGE-002, CHANGE-003 for details.
