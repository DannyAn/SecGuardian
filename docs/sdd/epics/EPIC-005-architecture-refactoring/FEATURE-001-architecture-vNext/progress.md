# Progress: Architecture Documentation vNext

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **开始**: 2026-07-04
> **完成**: 2026-07-04
> **Round 1 Review**: 2026-07-04 — applied (CHANGE-001)
> **Round 2 Review**: 2026-07-04 — applied (CHANGE-002)

---

## Overall Status

| # | Task | Status | Notes |
|---|------|--------|-------|
| — | SDD Setup (Epic/Spec/ADR/Plan) | ✅ Done | epics + spec + ADR + plan created |
| 1 | TASK-001: architecture-vNext.md | ✅ Done (rewritten ×2) | Round 1 — removed Engine as layer; Round 2 — no additional changes needed |
| 2 | TASK-002: runtime-model.md | ✅ Done (rewritten ×2) | Round 1 — collapsed dual-runtime; Round 2 — removed CI consumption mode → verification layer |
| 3 | TASK-003: security-engine.md | ✅ Done (rewritten ×2) | Round 1 — system → strategy layer; Round 2 — added deterministic pre-pass + signals |
| 4 | TASK-004: design-principles.md | ✅ Done (ADR-007 updated ×2) | Round 1 — softened to strategy convergence; Round 2 — no additional changes needed |
| 5 | TASK-005: readme-refactor-plan.md | ✅ Done | Unchanged by reviews |
| 6 | TASK-006: execution-model-current.md | ✅ Done (new) | Round 1 addition — single pipeline |
| 7 | TASK-007: engineering-principles.md | ✅ Done (new) | Round 1 addition — anti-over-engineering |
| — | CHANGE-001 logged | ✅ Done | Round 1 change record |
| — | CHANGE-002 logged | ✅ Done | Round 2 change record |
| — | Verification | ✅ Done | self-check passed (×3) |

---

## Deliverables Summary

| File | Lines | Status |
|------|-------|--------|
| docs/architecture/architecture-vNext.md | ~350 | Rewritten (Round 1) |
| docs/architecture/runtime-model.md | ~170 | Rewritten (Round 1 + Round 2) |
| docs/architecture/security-engine.md | ~260 | Rewritten (Round 1 + Round 2) |
| docs/architecture/design-principles.md | ~280 | ADR-007 updated (Round 1) |
| docs/architecture/readme-refactor-plan.md | ~200 | Original |
| docs/architecture/execution-model-current.md | ~180 | **New** (Round 1) |
| docs/architecture/engineering-principles.md | ~250 | **New** (Round 1) |
| docs/architecture/round1-review.md | (input) | Review artifact |
| docs/architecture/round2-review.md | (input) | Review artifact |

## Key Metrics

- Architecture documents created: 7 (5 original + 2 from Round 1)
- Design principles documented: 7 ADRs + 7 Engineering Principles (EP-1~EP-7)
- Execution contexts: 1 (interactive) + CI as verification layer
- Deterministic signals identified: 7 (existing, not future)
- Production code modified: 0
- SDD change records: CHANGE-001 + CHANGE-002

## Corrections Applied

### Round 1 — Over-Engineering Correction

| Pattern | Before | After |
|---------|--------|-------|
| Dual runtime | Runtime A / Runtime B as entities | Execution Context Profiles, same pipeline |
| Security Engine | System with interface/API/output | Execution Strategy Layer (note) |
| Rule DSL | Structured YAML/JSON assumed | Markdown stays; structured is future research |
| CI as runtime | CI flow diagram, separate engine | CI as artifact consumer (future) |

### Round 2 — CI Framing + Deterministic Pre-Pass

| Pattern | Before | After |
|---------|--------|-------|
| CI as "consumption mode" | CI = profile/consumer | CI = verification constraint layer over artifacts |
| LLM authority | No constraint on LLM findings | Deterministic pre-pass authoritative; LLM validates |
| Deterministic signals | Framed as "future direction" | Explicit table of 7 CURRENT signals |

## Blockers

- 无

## Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-07-04 | Feature Package created | Initial |
| 2026-07-04 | All 5 deliverables created | Architecture refactoring complete |
| 2026-07-04 | CHANGE-001 applied | Round 1 review — removed over-engineering |
| 2026-07-04 | CHANGE-002 applied | Round 2 review — CI as verification layer + deterministic pre-pass |

### Round 3 — Layer Boundary Insights

| Pattern | Before | After |
|---------|--------|-------|
| Engine contract | (did not exist) | `internal/engine/engine_contract.md` — defines what engine owns/does not own |
| Output contract | (did not exist) | `internal/output/output_contract.md` — single-direction flow |
| CI/CD boundary | Referenced loosely | `docs/ci-cd-interface.md` — artifact consumer contract |

**Production code NOT modified.** Command/skill refactoring (thin dispatchers, detector planners) identified as future implementation work, deferred beyond architecture documentation phase.

| Date | Change | Reason |
|------|--------|--------|
| 2026-07-04 | CHANGE-003 applied | Round 3 review — layer boundary enforcement |
