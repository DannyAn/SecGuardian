# Plan: Architecture Contract Implementation

> **Feature**: FEATURE-002 Architecture Contract Implementation
> **Epic**: EPIC-005 Architecture Refactoring
> **目标**: commands/skills 渐进式架构注入，行为零变化
> **作者**: Codex / 2026-07-04

---

## Implementation Plan

### Phase 1: SDD Setup

| # | 步骤 | 产出 | 状态 |
|---|------|------|------|
| 1 | Brainstorm | brainstorm-log.md 条目 | ✅ Done |
| 2 | Spec | spec.md | ✅ Done |
| 3 | ADR | adr.md (3 ADRs) | ✅ Done |
| 4 | Plan | 本文件 | ✅ Done |
| 5 | Tasks | tasks/TASK-001~005.md | 🔄 This |

### Phase 2: Commands Restructuring (4 files)

| # | Task | 文件 | 模式 |
|---|------|------|------|
| 1 | TASK-001 | commands/secguard.md (594→~610行) | Command Layer / Engine Layer 分组 + 合约引用 |
| 2 | TASK-001 | commands/secreview.md (327→~340行) | 同上 |
| 3 | TASK-002 | commands/secfix.md (137→~150行) | 同上（输出内容引用 output_contract.md） |
| 4 | TASK-002 | commands/secaudit.md (313→~330行) | 同上 |

### Phase 3: Skills Restructuring (11 files)

| # | Task | 文件 |
|---|------|------|
| 5 | TASK-003 | skills/secguard/{cpp,go,java,python,js}/SKILL.md (5 files) |
| 6 | TASK-004 | skills/secreview/{cpp,go,java,python,js}/SKILL.md (5 files) |
| 7 | TASK-004 | skills/secaudit/SKILL.md (1 file) |

### Phase 4: Verification

| # | 验证 | 命令 |
|---|------|------|
| 1 | section headers 检查 | `grep "^## " commands/*.md` 含 Command Layer / Engine Layer |
| 2 | contract 引用检查 | `grep engine_contract commands/*.md` >= 4 |
| 3 | skill 分区检查 | `grep "Detector Selection\|Engine Instructions" skills/*/SKILL.md` >= 11 |
| 4 | self-check | `bash scripts/self-check.sh` exit 0 |
| 5 | e2e 行为检查 | `bash scripts/e2e-verify.sh --quick` exit 0（扫描结果与基线一致） |

---

## 关键约束

1. **行为零变化** — 扫描结果必须与之前完全一致
2. **不删除内容** — 只增加分层标记和合约引用
3. **不改 Go 代码** — 仅限于 commands/ 和 skills/ 下的 markdown 文件
4. **所有 Engine 层内容标注过渡态** — "当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。"
