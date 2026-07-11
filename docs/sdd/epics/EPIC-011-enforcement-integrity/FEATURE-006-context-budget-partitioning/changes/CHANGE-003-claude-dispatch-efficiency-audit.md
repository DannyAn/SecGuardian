# CHANGE-003: Claude Dispatch Efficiency Audit

> **Date**: 2026-07-11
> **Status**: Accepted

## Reason

OpenCode secguard scans consistently complete in ~4-7 minutes for the C++ no-answers demo (15 files, 203 signals, 16 rules), while equivalent Claude Code scans take significantly longer. Three root causes were identified through cross-platform template comparison and session log analysis:

1. **Knowledge loading method**: Claude template line 86 says "知识文件从 `$SECGUARDIAN_HOME/knowledge/` 用 bash `cat` 按需读取", but line 131 correctly says "通过 Claude Code 原生 `read` 工具读取". This contradiction means the Engine Layer instruction (line 86) wins in practice — `bash cat` incurs shell stdout overhead per knowledge file vs `Read` tool's direct context injection. OpenCode and Gemini templates already use the `Read` tool for knowledge files.

2. **Agent per-batch overhead without gating**: ADR-006 defines Agent as optional isolation enhancement — the baseline is serial inline (all three platforms). But the Claude template at lines 196-198 mandates "滚动并发" Agent per (rule, batch) without a decision threshold. Each Agent independently sources `.scan_state` + reads `rule.md` — for small projects (e.g., 16 rules × avg 1.3 batches ≈ 21 batches), Agent spawn overhead exceeds the isolation benefit. OpenCode uses serial inline for all batch counts and achieves faster wall-clock time.

3. **Missing gating logic**: No threshold exists for when to use Agent vs serial inline. For scans with total batches < threshold, serial inline (like OpenCode) is faster and equally correct because the engine enforcement layer (verification-gate + coverage-gate) already guarantees per-rule discipline regardless of dispatch mode.

## Architecture Constraint

Tree-sitter indexes source ONCE → index.json contains all S1-S12 signals with `file:line` anchors → LLM reads source snippets via signal coordinates from partition-plan. Source files are **never** re-scanned regardless of dispatch mode. This is the engine guarantee documented in `docs/Root-Technology-Report.md` and `docs/Capability-Stacks.md`.

The efficiency problem is purely in the orchestration layer (knowledge loading + Agent scheduling), not in the engine. The engine's single-pass indexing + per-rule pre-filtering is already optimal.

## Impact

| Before | After |
|--------|-------|
| Engine Layer says `bash cat` for knowledge, Cross-Shell section says `Read` tool — contradiction | Engine Layer says `Read` tool for knowledge (consistent with OpenCode/Gemini), removes contradictory `bash cat` |
| Agent per-batch mandatory for all batch counts | Agent is optional: serial inline for total_batches ≤ 8, Agent fan-out for larger scans |
| No gating threshold — small scans pay Agent overhead | Decision logic reads `partition-plan.json` batch count, selects dispatch mode |
| Claude slower than OpenCode for equivalent scans | Claude matches or beats OpenCode wall-clock: serial for small, Agent parallelism for large |

## Performance Budget

- Knowledge loading: `Read` tool per knowledge file (same as OpenCode), no `bash cat` for text content
- Gating threshold: total_batches ≤ 8 → serial inline (baseline); total_batches > 8 → consider Agent per-batch (optional enhancement)
- Agent count cap: max 4 concurrent (respects Claude platform limits without overwhelming)
- Pilot batch always runs first (serial), regardless of dispatch mode — this is the ADR-006/CHANGE-002 safety gate
- Engine enforcement (verification-gate + coverage-gate) runs identically in both modes — recall/precision are dispatch-mode-independent

## Recall Guarantee

The gating threshold does NOT discard signals, skip rules, or reduce hypotheses. It only changes the dispatch mechanism: serial inline processes each (rule, batch) in the main context sequentially; Agent processes batches in isolated sub-contexts with bounded concurrency. Both modes:
- Use the same partition-plan.json (platform-independent)
- Execute the same Investigation Pipeline (Steps 5-8) per (rule, batch)
- Write the same artifacts under `workers/<rule_id>/<batch_id>/`
- Pass the same engine enforcement gates

The recall lower bound is defined by the signal matrix (S1-S12) + prescreener, not by the dispatch mode. The oracle (`verify-recall.py`) works identically for both modes.

## Implementation

1. Fix Claude template Engine Layer (line 86): remove `bash cat` reference, align with line 131's `Read` tool
2. Add gating logic: after Step 4, read `partition-plan.json` total batch count; if ≤ 8, use serial inline; if > 8, Agent is optional enhancement
3. Document the threshold rationale in dispatch-protocol.md
