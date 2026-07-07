# CHANGE-003: Round 3 Architecture Review — Layer Boundary Insights

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Date**: 2026-07-04
> **Trigger**: Architecture review (docs/architecture/review-arch-round3.md)
> **Scope**: Architecture documentation only — production code NOT modified

## What Changed

### Review Identified Five Structural Issues

1. **Command / Skill / Engine 三层职责混乱** — Same logic repeated in 3 layers
2. **index.json 使用权混乱** — Commands and skills both read index.json
3. **输出系统设计错误** — Multiple sources of truth for output
4. **Detector 执行模型混乱** — Command filters + skill decides + engine references
5. **CI/CD 扩展点没有稳定边界** — CI referenced without defined interface

### Architecture Documents Added

| File | Purpose |
|------|---------|
| `internal/engine/engine_contract.md` | Engine execution protocol specification — defines what the engine owns and does not own |
| `internal/output/output_contract.md` | Output formatting protocol — single-direction flow from engine through renderer |
| `docs/ci-cd-interface.md` | CI/CD consumption contract — CI is artifact consumer, not architecture participant |

These documents describe the **desired future state** of the architecture.
They do not modify current implementation.

### Production Code NOT Modified

The review identified code-level issues that should be addressed in a
future implementation phase (not this architecture documentation round):

- Commands: should become thin dispatchers (parse + dispatch + output path only)
- Skills: should become detector planners (which detectors, not how to execute)
- These changes are deferred to a separate implementation task

## Verification

- `bash scripts/self-check.sh` — passed (120 checks, 0 failures)
- `git checkout -- commands/ skills/` — reverted earlier changes, no production code modified
- Only untracked files in `docs/architecture/`, `docs/ci-cd-interface.md`, `internal/engine/`, `internal/output/`

## Key Insight

Round 3 clarified the critical architectural boundary:

> **Command decides WHAT to run
> Skill decides WHICH detectors
> Engine decides HOW to execute
> Renderer decides HOW to display**

This boundary is documented in the contract files. Implementation is deferred.
