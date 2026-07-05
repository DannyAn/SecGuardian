# Plan: Architecture Document Revision

> **Feature**: FEATURE-005 Architecture Document Revision
> **Epic**: EPIC-005 Architecture Refactoring
> **目标**: 修正 6 份架构文档，消除设计-代码鸿沟，确立"信号-LLM协作"模型
> **核心约束**: 不改 production 代码，只改 docs/ + internal/engine/ + internal/output/ 下的 .md 文件

---

## Phase 1: SDD Setup

| # | 步骤 | 产出 | 状态 |
|---|------|------|------|
| 1 | Brainstorm 记录 | brainstorm-log.md 条目 | ✅ Done |
| 2 | Spec | spec.md | ✅ Done |
| 3 | ADR | adr.md (ADR-009 + ADR-010) | ✅ Done |
| 4 | Plan | 本文件 | 🔄 This |
| 5 | Tasks | 7 个 Task 文件 | ⬜ |

## Phase 2: 核心文档重写（改动量最大，先做）

| # | Task | 文件 | 改动类型 | 预估 |
|---|------|------|---------|------|
| 1 | TASK-001 | security-engine.md | 重写 ~70% | 45 min |
| 2 | TASK-002 | engine_contract.md | 重写 ~75% | 30 min |

## Phase 3: 关联文档更新

| # | Task | 文件 | 改动类型 | 预估 |
|---|------|------|---------|------|
| 3 | TASK-003 | architecture-vNext.md | 局部 ~20% | 20 min |
| 4 | TASK-004 | runtime-model.md | 局部 ~15% | 15 min |
| 5 | TASK-005 | design-principles.md | 局部 ~10% | 15 min |
| 6 | TASK-006 | engineering-principles.md | 局部 ~5% | 10 min |

## Phase 4: 验证

| # | Task | 验证内容 | 命令 |
|---|------|---------|------|
| 7 | TASK-007 | 交叉引用一致性 + self-check | `grep` + `bash scripts/self-check.sh` |

## Phase 5: 约束落地 (CHANGE-001 — 扫描实测触发)

| # | Task | 文件 | 改动类型 | 预估 |
|---|------|------|---------|------|
| 8 | TASK-008 | commands/secguard.md | 锚定+预筛收紧 ~20行 | 15 min |
| 9 | TASK-009 | skills/secguard/{5 langs}/SKILL.md | 锚定+证据约束注入 | 20 min |
| 10 | TASK-010 | scripts/record-finding.py | 必填参数强化 | 10 min |
| 11 | TASK-011 | 最终验证 | deploy + self-check | 10 min |

---

## 关键约束

1. **不改一行 Go** — 所有变更仅限于 `.md` 文件
2. **不改 commands/skills/knowledge** — 锚定约束注入在 FEATURE-006
3. **不新增文档** — 只修正已有文档，不创建新的架构/合约文档
4. **交叉引用完整** — 修正后所有文档间互链必须一致
5. **engineering-principles.md 自洽** — 修正后的架构文档必须通过 EP-1~EP-7 的检验

## 验证清单

```
□ security-engine.md: 无 "LLM MAY NOT introduce" 绝对约束
□ security-engine.md: 含信号层能力表 + 渐进演进路线
□ engine_contract.md: 无 Engine API/接口定义
□ engine_contract.md: 含锚定约束 + 证据约束
□ architecture-vNext.md: Phase 2/3 无 "deterministic matcher"
□ architecture-vNext.md: Phase 2 改为跨文件调用图+类型继承
□ runtime-model.md: 含 CI 确定性预检流程
□ design-principles.md: ADR-007 更新 + ADR-008 新增
□ engineering-principles.md: EP-1 提供替代方案
□ 6 份文档间交叉引用无断裂
□ bash scripts/self-check.sh exit 0
□ git diff --stat 仅含 docs/ + internal/engine/ + internal/output/
```
