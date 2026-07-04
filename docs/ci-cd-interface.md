# CI/CD Interface Contract

> **Document**: CI/CD consumption protocol — CI is an artifact consumer, not an architecture participant.
> **Status**: Ratified. CI must NOT call engine internals, modify detector logic, or access index.json.
> **Updated**: 2026-07-04

---

## 1. Purpose

CI/CD is a **verification constraint layer** over scan artifacts.
It does not execute analysis. It does not control the pipeline.

CI/CD evaluates artifacts produced by the single pipeline (indexer → engine → renderer)
and makes gate decisions based on organizational security constraints.

---

## 2. Contract

### CI/CD MAY Consume

| Artifact | Format | Purpose |
|----------|--------|---------|
| `results.sarif` | SARIF 2.1.0 JSON | Finding severity count, gate compliance |
| `status.json` | JSON | PASSED / FAILED / WARN gate status |
| `summary.json` | JSON | Security score, score drift vs baseline |

### CI/CD MUST NOT

| Action | Reason |
|--------|--------|
| Call engine internals | CI is not a runtime |
| Modify detector logic | Detector logic is an architectural concern |
| Access index.json | index.json is engine-only (per engine contract Rule C) |
| Write to output directory | Output directory is pipeline-owned |
| Override scan mode | Scan mode is determined by developer intent |

---

## 3. Gate Decision Model

```
CI receives:
  results.sarif  → severity count → gate threshold check
  status.json    → PASSED/FAILED  → exit code
  summary.json   → security score → trend check

CI evaluates:
  score >= threshold?         → PASSED
  critical finding count 0?   → PASSED
  score drift <= tolerance?   → PASSED
  Any check fails             → FAILED

CI outputs:
  Exit code 0  → PASSED
  Exit code 1  → FAILED
```

The gate decision is computed from artifacts. CI does not re-execute analysis.

---

## 4. Pipeline Independence

CI does not change how the pipeline runs:

```
Developer (AI Agent):  trigger → pipeline → full output
CI (scheduled):        trigger → pipeline → SARIF + summary + status
```

Same pipeline. Same engine. Same indexer. Different artifact consumption.

---

## 5. Current State

CI/CD integration is not yet implemented. The artifacts are produced by
`render-report.py` and ready for CI consumption when a CI runner is configured.

Current readiness:
- ✅ results.sarif — conforms to SARIF 2.1.0
- ✅ status.json — contains PASSED/FAILED/WARN + exit code
- ✅ summary.json — contains security score + finding counts
- ⬜ CI runner — not yet implemented (expected: v0.14+)

---

## 6. Related Documents

- `internal/engine/engine_contract.md` — Engine produces findings
- `internal/output/output_contract.md` — Renderer produces formatted artifacts
- `knowledge/protocols/scan-output.md` — v5.0 output protocol spec
