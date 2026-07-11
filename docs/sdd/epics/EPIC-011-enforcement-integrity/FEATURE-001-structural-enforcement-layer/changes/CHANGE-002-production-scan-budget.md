# CHANGE-002: Production Scan Budget

> **Date**: 2026-07-11
> **Status**: Accepted

## Reason

A real Claude scan of the 15-file C++ no-answers demo took about 15 minutes. The engine expanded 203 unique signals into 571 rule assignments, required at least 1,713 hypotheses, preloaded 14 rules and 14 source files into the dispatcher, and launched multi-rule agents with a roughly 11-minute critical path. All 33 gate-inspected findings were invalid, but the adapter rendered anyway.

## Impact

| Before | After |
|--------|-------|
| Category-wide rule fan-out | Retained until the recall oracle proves a narrower semantic prescreener safe |
| 3-5 hypotheses for every signal | Retained as the Investigation Engine recall mechanism |
| Parent reads all rules and source | Parent reads only compact schedule and gate summaries |
| Multi-rule, multi-batch agents | One exact `(rule_id, batch_id)` per task |
| Full fan-out before format validation | One pilot batch must pass artifact validation before rolling fan-out |
| Polling and narrated counters | Completion events and artifact-derived counters only |
| Gate failure could still render | Any verification or coverage failure terminates the scan as BLOCKED |

## Performance Budget

- Assignment reduction is not an acceptance criterion without ground-truth recall equivalence. Performance changes must bound context and scheduling rather than discard unknown signals.
- Parent dispatcher must not bulk-read rule files or source files.
- Concurrency is rolling and bounded; a task receives one rule and one batch only.
- A malformed pilot prevents all remaining LLM work.
- Final counts come only from gate/manifest artifacts.

## Recall Correction

An initial implementation added exact callee/kind allowlists and reduced hypotheses to one. Architecture review found this contradicted EPIC-009 conservative prescreening and EPIC-010 multi-hypothesis investigation, with no recall oracle proving the removed assignments safe. Those semantic filters were removed before acceptance. The retained optimizations affect orchestration only.
