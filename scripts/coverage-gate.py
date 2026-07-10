#!/usr/bin/env python3
"""coverage-gate.py — Signal-coverage floor gate (EPIC-011 FEATURE-001 TASK-007).

This is the STRUCTURAL fix for F8 (batch-suppression): the production failure
where the indexer found 1358 signals and the LLM suppressed all of them to
"safe sampling", producing 0 findings and a 100/100 PASSED score that let
Critical issues ship.

The Markdown protocol said "don't suppress everything" — but Markdown is
LLM-ignoreable. This gate is COMPILED and runs at scan level:

  coverage = (findings + dismissed_with_reason) / signals_count
  if signals_count > 0 and investigated == 0 and no dismissed reasons:
      -> BLOCKED (batch-suppression detected) -> CI exit 1
  elif floor > 0 and coverage < floor:
      -> BLOCKED -> CI exit 1
  else:
      -> PASSED

A 0-finding scan is only legitimate if (a) there were 0 signals to investigate,
or (b) every suppressed signal is accounted for in dismissed.json with a reason.

Usage:
  python3 coverage-gate.py --index <index.json> --scan-dir <scan_dir> [--floor 0]
  python3 coverage-gate.py --self-test
"""
import argparse
import json
import os
import sys


def count_signals(index):
    """Count investigation-worthy signals the LLM should have looked at.

    Uses the POST-prescreener signal counts stored in index.json (the indexer
    runs the prescreener before writing the context, so call_sites etc. are
    already the filtered set the LLM received).
    """
    if not isinstance(index, dict):
        return 0
    fields = (
        "call_sites",          # S1 — memory/injection/resource drivers
        "control_flow",        # S7 — guard/return/error-check signals
        "pointer_validations", # S8 — unchecked dereferences
        "struct_inits",        # S9 — uninitialized fields
        "variable_writes",     # S10 — tainted writes
    )
    n = 0
    for f in fields:
        v = index.get(f)
        if isinstance(v, list):
            n += len(v)
    return n


def count_findings(scan_dir):
    """Count recorded findings in a v5.0 scan dir (findings/ tree or findings.json index)."""
    if not scan_dir or not os.path.isdir(scan_dir):
        return 0
    # v5.0 findings.json index
    fj = os.path.join(scan_dir, "findings.json")
    if os.path.isfile(fj):
        try:
            with open(fj) as f:
                data = json.load(f)
            if isinstance(data, dict) and isinstance(data.get("findings_index"), list):
                return len(data["findings_index"])
            if isinstance(data, dict) and isinstance(data.get("findings"), list):
                return len(data["findings"])
        except (json.JSONDecodeError, OSError):
            pass
    # fallback: walk findings/ tree
    findings_dir = os.path.join(scan_dir, "findings")
    n = 0
    if os.path.isdir(findings_dir):
        for _root, _dirs, files in os.walk(findings_dir):
            n += sum(1 for fn in files if fn.endswith(".json"))
    return n


def count_dismissed_with_reason(scan_dir):
    """Count dismissed signals that carry a reason (legitimate suppression).

    dismissed.json is the protocol artifact where the LLM must explain EACH
    suppressed signal. Entries without a reason don't count — a blanket
    "all safe" with no per-signal justification is exactly batch-suppression.
    """
    if not scan_dir:
        return 0
    dj = os.path.join(scan_dir, "dismissed.json")
    if not os.path.isfile(dj):
        return 0
    try:
        with open(dj) as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return 0
    entries = data
    if isinstance(data, dict):
        entries = data.get("dismissed") or data.get("entries") or data.get("items") or []
    if not isinstance(entries, list):
        return 0
    return sum(1 for e in entries if isinstance(e, dict) and e.get("reason"))


def evaluate(signals_count, findings_count, dismissed_count, floor=0.0):
    """Decide the coverage gate verdict. Returns (verdict, coverage, detail)."""
    investigated = findings_count + dismissed_count
    coverage = (investigated / signals_count) if signals_count > 0 else 1.0
    if signals_count == 0:
        return "PASSED", coverage, "no signals to investigate"
    if investigated == 0:
        return ("BLOCKED", coverage,
                "batch-suppression: %d signals, 0 findings, 0 dismissed-with-reason" % signals_count)
    if floor > 0 and coverage < floor:
        return ("BLOCKED", coverage,
                "coverage %.2f%% below floor %.2f%% (%d/%d investigated)" %
                (coverage * 100, floor * 100, investigated, signals_count))
    return ("PASSED", coverage,
            "%d/%d signals investigated (%.2f%%)" % (investigated, signals_count, coverage * 100))


def self_test():
    """Deterministic assertions (TDD)."""
    # batch-suppression: signals>0, 0 findings, 0 dismissed -> BLOCKED
    v, c, _ = evaluate(100, 0, 0)
    assert v == "BLOCKED", v
    assert c == 0.0, c
    # some findings -> PASSED (floor=0)
    v, _, _ = evaluate(100, 5, 0)
    assert v == "PASSED", v
    # all dismissed WITH reason -> PASSED (legitimate suppression)
    v, _, _ = evaluate(100, 0, 100)
    assert v == "PASSED", v
    # dismissed WITHOUT reason don't count -> still BLOCKED
    # (count_dismissed_with_reason filters; here evaluate sees dismissed_count=0)
    v, _, _ = evaluate(100, 0, 0)
    assert v == "BLOCKED", v
    # no signals -> PASSED
    v, _, _ = evaluate(0, 0, 0)
    assert v == "PASSED", v
    # floor enforced
    v, _, _ = evaluate(100, 1, 0, floor=0.1)
    assert v == "BLOCKED", v  # 1% < 10%
    v, _, _ = evaluate(100, 20, 0, floor=0.1)
    assert v == "PASSED", v  # 20% >= 10%
    print("OK — coverage-gate self-test passed (batch-suppression detection correct)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Signal-coverage floor gate (F8 structural fix)")
    ap.add_argument("--index", help="index.json from the indexer")
    ap.add_argument("--scan-dir", help="scan output directory (findings + dismissed.json)")
    ap.add_argument("--floor", type=float, default=0.0,
                    help="coverage floor 0..1 (default 0 = only block 0-investigated)")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not args.index or not args.scan_dir:
        ap.error("--index and --scan-dir are required (or use --self-test)")

    try:
        with open(args.index) as f:
            index = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        print("FATAL: cannot read index.json: %s" % e, file=sys.stderr)
        return 2

    signals = count_signals(index)
    findings = count_findings(args.scan_dir)
    dismissed = count_dismissed_with_reason(args.scan_dir)
    verdict, coverage, detail = evaluate(signals, findings, dismissed, args.floor)

    result = {
        "signals_count": signals,
        "findings_count": findings,
        "dismissed_with_reason": dismissed,
        "investigated": findings + dismissed,
        "coverage": round(coverage, 4),
        "floor": args.floor,
        "verdict": verdict,
        "detail": detail,
    }
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("Coverage gate: %s" % verdict)
        print("  signals=%d  findings=%d  dismissed(reason)=%d  coverage=%.2f%%" %
              (signals, findings, dismissed, coverage * 100))
        print("  %s" % detail)
    # BLOCKED -> exit 1 (CI fails); PASSED -> exit 0
    return 1 if verdict == "BLOCKED" else 0


if __name__ == "__main__":
    sys.exit(main())
