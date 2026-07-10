#!/usr/bin/env python3
"""verify-recall.py — Ground-truth recall/precision oracle (EPIC-011 FEATURE-001 Pillar B).

The "beyond SAST" claim is only credible if recall (do we catch what we should?)
and precision (do we avoid what we shouldn't?) are MEASURED against an
independent ground truth, not self-reported by the LLM. This oracle reads an
expected-results.json ground truth and a findings.json (or findings dir) from an
actual scan, matches them, and reports recall / precision / F1 + a per-case diff.

This is the structural fix for F4 (verification theater): it replaces the
fabricated "all pipelines pass" check with a real detector-output vs ground-truth
comparison.

Usage:
  python3 verify-recall.py --expected examples/python-vuln-demo/expected-results.json \\
      --findings examples/python-vuln-demo/.codeagent/.../findings.json
  python3 verify-recall.py --self-test     # deterministic math assertions (TDD)
  python3 verify-recall.py --expected ... --findings <findings-dir>   # v5.0 dir
"""
import argparse
import json
import os
import sys

# A case is a "should report" (true positive expectation) only if its expected
# verdict normalizes to CONFIRMED. Everything else (no_finding / exempted /
# counter_evidence / suspected / EXCLUDE) is a "should NOT report" case — a
# finding landing there is a false positive.
CONFIRMED_KEYWORDS = ("confirmed",)


def normalize_verdict(expected_str):
    """Map a heterogeneous `expected` string to {confirmed, not_confirmed, suspected}."""
    s = str(expected_str).lower()
    if "confirmed" in s:
        return "confirmed"
    if "suspected" in s or "suspect" in s:
        return "suspected"
    return "not_confirmed"


def _basename(path):
    return os.path.basename(path) if path else ""


def _line_near(a, b, tol=2):
    try:
        return abs(int(a) - int(b)) <= tol
    except (TypeError, ValueError):
        return False


def _norm_func(v):
    """Normalize a function name; treat N/A / empty / None as missing."""
    if v is None:
        return ""
    s = str(v).strip()
    if s.lower() in ("n/a", "na", "none", "-", ""):
        return ""
    return s.lower()


def case_matches_finding(case, finding):
    """Does a ground-truth case match an actual finding?

    Matching precedence (file basename must match when both present):
      1. line within ±2 (strong)
      2. function name equal (strong)
      3. file basename equal + no conflicting line/function (weak, file-level)

    The weak file-level match is a deliberate fallback because v5.0
    findings_index frequently stores function="N/A" (recorder data gap). It is
    only used when neither strong signal is available, and is suppressed when
    both sides have a function that differs.
    """
    cf = _basename(case.get("file", ""))
    ff = _basename(finding.get("file", ""))
    if cf and ff and cf != ff:
        return False
    cfn = _norm_func(case.get("function"))
    ffn = _norm_func(finding.get("function"))
    cl = case.get("line")
    fl = finding.get("line")
    # strong: line near
    if cl is not None and fl is not None and _line_near(cl, fl):
        return True
    # strong: function equal
    if cfn and ffn and cfn == ffn:
        return True
    # conflicting function → definitely not the same site
    if cfn and ffn and cfn != ffn:
        return False
    # conflicting line (both present, not near) → not the same site
    if cl is not None and fl is not None and not _line_near(cl, fl):
        return False
    # weak: file basename agrees and no conflicting signal
    if cf and ff and cf == ff:
        return True
    return False


def load_findings(path):
    """Load findings from a findings.json (v4.0 list or v5.0 index), a single
    finding object, or a v5.0 findings directory."""
    if os.path.isdir(path):
        out = []
        for root, _dirs, files in os.walk(path):
            for fname in sorted(files):
                if not fname.endswith(".json"):
                    continue
                try:
                    with open(os.path.join(root, fname)) as f:
                        data = json.load(f)
                except (json.JSONDecodeError, OSError):
                    continue
                if isinstance(data, dict) and "finding" in data:
                    out.append(data["finding"])
                elif isinstance(data, dict) and "id" in data:
                    out.append(data)
        return out
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        # v5.0 findings.json is an INDEX (findings_index[]), not the findings
        # themselves — but each entry carries file/line/function/detector/title,
        # which is exactly what the oracle matches on.
        if "findings_index" in data and isinstance(data["findings_index"], list):
            return data["findings_index"]
        if "findings" in data:
            return data["findings"]
        if "finding" in data:
            return [data["finding"]]
    return []


def evaluate(cases, findings):
    """Compute recall/precision/F1 + per-case diff.

    recall   = confirmed cases with a matching finding / total confirmed
    precision = findings matching a confirmed case / total findings
               (findings on not_confirmed cases are false positives)
    """
    confirmed = [c for c in cases if normalize_verdict(c.get("expected", "")) == "confirmed"]
    not_conf = [c for c in cases if normalize_verdict(c.get("expected", "")) == "not_confirmed"]

    confirmed_hit = 0
    case_report = []
    for c in confirmed:
        hit = any(case_matches_finding(c, f) for f in findings)
        if hit:
            confirmed_hit += 1
        case_report.append({"id": c.get("id"), "file": c.get("file"),
                            "function": c.get("function"), "expected": "confirmed",
                            "matched": hit, "verdict": "TP" if hit else "FN"})

    fp_findings = []
    tp_findings = 0
    for f in findings:
        on_confirmed = any(case_matches_finding(c, f) for c in confirmed)
        if on_confirmed:
            tp_findings += 1
        else:
            fp_findings.append(f)

    total_confirmed = len(confirmed)
    total_findings = len(findings)
    recall = (confirmed_hit / total_confirmed) if total_confirmed else 0.0
    precision = (tp_findings / total_findings) if total_findings else 1.0
    f1 = (2 * recall * precision / (recall + precision)) if (recall + precision) else 0.0

    return {
        "total_cases": len(cases),
        "confirmed_cases": total_confirmed,
        "not_confirmed_cases": len(not_conf),
        "total_findings": total_findings,
        "true_positives": confirmed_hit,
        "false_negatives": total_confirmed - confirmed_hit,
        "false_positives": len(fp_findings),
        "recall": round(recall, 4),
        "precision": round(precision, 4),
        "f1": round(f1, 4),
        "per_case": case_report,
        "false_positive_findings": [
            {"file": f.get("file"), "line": f.get("line"),
             "function": f.get("function"), "detector": f.get("detector"),
             "title": f.get("title")} for f in fp_findings
        ],
    }


def self_test():
    """Deterministic assertions on the recall/precision math (TDD)."""
    cases = [
        {"id": "C1", "file": "a.c", "line": 10, "function": "vuln", "expected": "P3 confirmed — raw memcpy"},
        {"id": "C2", "file": "b.c", "line": 20, "function": "vuln2", "expected": "confirmed"},
        {"id": "C3", "file": "a.c", "line": 30, "function": "safe", "expected": "Detector EXCLUDE → 0 Finding"},
        {"id": "C4", "file": "a.c", "line": 40, "function": "safe2", "expected": "P1 exempted"},
    ]
    # Findings: 1 matches C1 (TP), 1 lands on C3's safe code (FP), C2 missed (FN)
    findings = [
        {"file": "a.c", "line": 11, "function": "vuln", "detector": "x", "title": "t"},   # matches C1 (line±2)
        {"file": "a.c", "line": 31, "function": "safe", "detector": "y", "title": "t"},   # lands on C3 (FP)
    ]
    r = evaluate(cases, findings)
    assert r["confirmed_cases"] == 2, r
    assert r["true_positives"] == 1, r
    assert r["false_negatives"] == 1, r
    assert r["false_positives"] == 1, r
    assert r["recall"] == 0.5, r
    assert r["precision"] == 0.5, r
    assert abs(r["f1"] - 0.5) < 1e-9, r

    # Empty findings on all-confirmed → recall 0, precision 1 (vacuous, no FP)
    r2 = evaluate([{"id": "C1", "file": "a.c", "line": 1, "function": "f", "expected": "confirmed"}], [])
    assert r2["recall"] == 0.0 and r2["precision"] == 1.0, r2

    # function-only match (no line)
    r3 = evaluate(
        [{"id": "C1", "file": "x.py", "function": "vulnerable_query", "expected": "confirmed"}],
        [{"file": "x.py", "line": 5, "function": "vulnerable_query"}],
    )
    assert r3["true_positives"] == 1, r3

    print("OK — verify-recall self-test passed (recall/precision/F1 math correct)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Ground-truth recall/precision oracle")
    ap.add_argument("--expected", help="expected-results.json ground truth")
    ap.add_argument("--findings", help="findings.json file or v5.0 findings directory")
    ap.add_argument("--self-test", action="store_true", help="run deterministic math assertions")
    ap.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not args.expected or not args.findings:
        ap.error("--expected and --findings are required (or use --self-test)")

    with open(args.expected) as f:
        gt = json.load(f)
    cases = gt.get("test_cases", gt.get("cases", []))
    if not cases:
        print("FATAL: no test_cases found in expected-results.json", file=sys.stderr)
        return 2
    findings = load_findings(args.findings)
    result = evaluate(cases, findings)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"Ground truth: {result['total_cases']} cases "
              f"({result['confirmed_cases']} confirmed, {result['not_confirmed_cases']} not_confirmed)")
        print(f"Actual findings: {result['total_findings']}")
        print(f"  TP={result['true_positives']}  FN={result['false_negatives']}  FP={result['false_positives']}")
        print(f"  recall={result['recall']}  precision={result['precision']}  f1={result['f1']}")
        missed = [c for c in result["per_case"] if c["verdict"] == "FN"]
        if missed:
            print(f"\nMissed confirmed cases (FN, recall loss):")
            for c in missed:
                print(f"  {c['id']} {c['file']}::{c['function']}")
        if result["false_positive_findings"]:
            print(f"\nFalse positives (findings on not_confirmed cases):")
            for f in result["false_positive_findings"]:
                print(f"  {f['file']}:{f['line']} {f['function']} [{f['detector']}] {f['title']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
