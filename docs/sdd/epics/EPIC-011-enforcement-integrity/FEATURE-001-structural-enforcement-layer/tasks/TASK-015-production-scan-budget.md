# TASK-015: Enforce Production Scan Budget

## Goal

Remove the dominant token and wall-clock amplifiers observed in the real Claude C++ scan while preserving assignment provenance and mandatory gates.

## Done

- [x] Reject unproven callee/kind filtering after architecture review; preserve unknown signals.
- [x] Preserve 3-5 multi-hypothesis generation required by the Investigation Engine.
- [x] Add pilot-first rolling dispatch contract.
- [x] Ban dispatcher bulk preload, multi-rule tasks, polling, and manual totals.
- [x] Make gate failure an explicit terminal state.
- [x] Add real no-answer source -> index -> rule routing regression test.
- [x] Add deterministic engineer-facing CLI summary regression test.
- [x] Deploy and pass L1/L4.

## Verification

```bash
python3 scripts/partition-signals.py --self-test
bash scripts/self-check.sh
bash scripts/e2e-verify.sh --ci
```
