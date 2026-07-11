# TASK-014: Close Secguard End-to-End Integrity

## Goal

Make the Claude C/C++ secguard path fail closed from initialization through rendering and prove detector output against the no-answers benchmark.

## Done

- [x] Preserve explicit language and persist canonical rules/scripts paths.
- [x] Package partition, verification, and coverage gates.
- [x] Parse every C++ `signal_source` or fail with a diagnostic.
- [x] Assign stable signal, rule, and batch identities.
- [x] Require per-batch Investigation artifacts for confirmed findings.
- [x] Reconcile coverage against partition assignments and block incomplete scans.
- [ ] Complete the C++ no-answers oracle ground truth and run a real Claude scan.

## Files Changed

- `commands/claude/secguard.md`
- `skills/secguard/cpp/SKILL.md`
- `scripts/init-scan.sh`
- `scripts/package.sh`
- `scripts/partition-signals.py`
- `scripts/coverage-gate.py`
- `scripts/verification-gate.py`
- `scripts/record-finding.py`
- `scripts/e2e-verify.sh`

## Verification

```bash
bash scripts/self-check.sh
bash scripts/ci-check.sh
bash scripts/e2e-verify.sh --ci
```
