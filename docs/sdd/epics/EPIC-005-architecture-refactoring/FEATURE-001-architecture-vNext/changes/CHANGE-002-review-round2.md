# CHANGE-002: Round 2 Architecture Review — CI as Verification Layer + Deterministic Pre-Pass

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Date**: 2026-07-04
> **Trigger**: ChatGPT architecture review (docs/architecture/review-arch-round2.md)

## What Changed

### Review Found Three Residual Issues

1. **CI still had "semantic independence"** — runtime-model.md described CI as a
   "consumption mode" (profile), implying CI defines execution behavior.
   Correct model: CI is a verification constraint layer over artifacts.

2. **LLM weight still too high** — security-engine.md lacked an explicit
   constraint that deterministic pre-pass (index-derived candidates) is
   authoritative. LLM could still introduce findings outside candidate space.

3. **Deterministic signals suppressed by "future direction" framing** —
   Existing signals (index.json, call_graph, alloc_free, lock_graph) were
   labeled "future research" instead of "current reality."

### Changes Made

| Document | Change |
|----------|--------|
| runtime-model.md | Removed "Profile: Consumption" section, "What Differs" table, "Evolution" section, all "consumption mode" language. Added "CI: Verification Constraint Layer" section. |
| security-engine.md | Added Section 3 "Current Deterministic Signals" (7 signals table). Added Section 4 "Deterministic Pre-Pass Authority." Added LLM May / May Not constraints. Updated Commitment table. |

### What Was Kept

- All Round 1 corrections intact
- architecture-vNext.md, design-principles.md, execution-model-current.md, engineering-principles.md — unchanged
- SDD Feature Package structure — unchanged

## Verification

- `bash scripts/self-check.sh` — passed (120 checks)
- `grep -c "consumption" runtime-model.md` — 0
- `grep -c "Current Deterministic Signals" security-engine.md` — 1
- `grep -c "LLM MAY" security-engine.md` — 2
- No new files added (only modified: runtime-model.md, security-engine.md)

## Lessons

1. CI modeling is a recurring mistake — must be constrained by engineering-principles.md EP-3 and EP-6
2. "index defines candidate space" is a non-negotiable constraint; remove it and detection quality degrades
3. Existing deterministic signals should be labeled CURRENT, not "future" — documentation must describe what exists
