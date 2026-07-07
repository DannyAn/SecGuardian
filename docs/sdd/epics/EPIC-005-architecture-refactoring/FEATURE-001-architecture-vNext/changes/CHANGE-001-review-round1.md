# CHANGE-001: Round 1 Architecture Review — Downgrade from Over-Engineering

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Date**: 2026-07-04
> **Trigger**: ChatGPT architecture review (docs/architecture/review-arch-round1.md)
> **Severity**: Significant — multiple documents rewritten or restructured

---

## What Changed

### Review Found Three Over-Engineering Patterns

1. **Dual-Runtime Architecture** — runtime-model.md defined Runtime A (AI Agent)
   and Runtime B (CI) as independent execution systems. CI does not exist as a
   runtime. It is a future consumption mode of the same pipeline.

2. **Security Engine as System** — security-engine.md defined SecurityEngine
   interface, Scan API, LoadRules API, output schemas, and telemetry format.
   No engine exists. All detection logic is LLM-driven.

3. **DSL Assumption** — Documents implied structured rule formats (YAML/JSON)
   when all detector rules are Markdown consumed by LLM prompts. Structured
   rules are a premature abstraction.

### Changes Made

| Document | Change | Before | After |
|----------|--------|--------|-------|
| runtime-model.md | Full rewrite | Dual-runtime (Runtime A/B) | Execution Context Profiles (one pipeline) |
| security-engine.md | Full rewrite | SecurityEngine interface/API/output | Execution Strategy Layer (system → note) |
| architecture-vNext.md | Full rewrite | Engine as separate layer in diagram | Strategy note; no engine layer |
| design-principles.md | ADR-007 rewrite | "Convergence into One Security Engine" | "Execution Strategy Convergence" |
| execution-model-current.md | **New** | — | Single pipeline documentation (no dual runtime) |
| engineering-principles.md | **New** | — | 7 anti-over-engineering constraints |

### What Was Kept

- architecture-vNext.md sections 1, 3, 6, 8 (Product Vision, Security Roles,
  Architecture Invariants, Risks) — unchanged
- design-principles.md ADR-001 through ADR-006 — unchanged
- Knowledge layer description — unchanged
- Output layer description — unchanged
- SDD Feature Package structure — unchanged

---

## Why This Change

The review identified that the architecture documents were "prematurely
productizing the future" — designing systems (Engine, dual-runtime) that
have no implementation today and no clear path to implementation in v0.x.

The correction: documents must describe **what exists**, not what might
exist. Future directions are allowed as notes, not as system designs.

---

## Verification

- `bash scripts/self-check.sh` — passed (120+ checks)
- `git diff --stat -- ':(exclude)docs/' ':(exclude)README.md'` — 0 lines
- All docs/ files match current system capabilities (no unimplemented systems)
- `engineering-principles.md` provides explicit constraints against regression

---

## Lessons

1. Architecture documents must describe the **current system** (80%) and
   only briefly note future directions (20%).
2. Any "system" that doesn't exist in code must be a strategy note, not
   an interface/API/component definition.
3. CI/CD integration must be artifact-based, not execution-based.
4. Engine abstraction requires 2+ production use cases before any interface.
5. Knowledge format is Markdown until proven otherwise.
