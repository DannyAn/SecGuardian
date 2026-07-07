# CHANGE-004: Cross-Reference Integration — Architecture Docs ↔ Contracts

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **Date**: 2026-07-04
> **Trigger**: Cross-reference audit — Round 3 contract docs not linked from architecture docs
> **Severity**: Minor — cross-reference additions only, no content changes

## What Changed

The 3 Round 3 contract documents (engine_contract.md, output_contract.md, ci-cd-interface.md) 
were not referenced by any existing architecture document. This creates a navigation gap:
readers of architecture-vNext.md or runtime-model.md cannot discover the contracts.

### Changes Made

| Document | Change | Target |
|----------|--------|--------|
| architecture-vNext.md §7 | Added 3 rows to project mapping table | engine_contract.md, output_contract.md, ci-cd-interface.md |
| runtime-model.md §4 | Added "See docs/ci-cd-interface.md" | ci-cd-interface.md |
| security-engine.md §7 | Added "See engine_contract.md + output_contract.md" | engine_contract.md, output_contract.md |
| execution-model-current.md §4 | Added "See internal/output/output_contract.md" | output_contract.md |
| engineering-principles.md EP-3 | Added "See docs/ci-cd-interface.md" | ci-cd-interface.md |

### What Was NOT Changed

- No content changes to any architecture or contract document
- No SDD structural changes
- No production code

## Verification

- `grep -c "engine_contract\|output_contract\|ci-cd-interface" docs/architecture/*.md` >= 5
- `bash scripts/self-check.sh` — passed
