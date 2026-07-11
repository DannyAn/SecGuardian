#!/usr/bin/env python3
"""Scan all judge_verdict.json files under workers/ and produce summary (FEATURE-007).

Usage:
  python3 scan-verdicts.py --scan-dir /path/to/scan
  python3 scan-verdicts.py --self-test
"""

import json
import os
import sys


def scan_verdicts(scan_dir):
    workers = os.path.join(scan_dir, "workers")
    if not os.path.isdir(workers):
        return {"error": f"workers directory not found: {workers}"}

    results = []
    for rule in sorted(os.listdir(workers)):
        rule_dir = os.path.join(workers, rule)
        if not os.path.isdir(rule_dir):
            continue
        for batch in sorted(os.listdir(rule_dir)):
            batch_dir = os.path.join(rule_dir, batch)
            if not os.path.isdir(batch_dir):
                continue
            jf = os.path.join(batch_dir, "judge_verdict.json")
            if not os.path.exists(jf):
                results.append({"rule": rule, "batch": batch, "error": "judge_verdict.json missing"})
                continue
            try:
                with open(jf) as f:
                    j = json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                results.append({"rule": rule, "batch": batch, "error": str(e)})
                continue

            if isinstance(j, list):
                j = {"verdicts": j}

            verdicts = j.get("verdicts", [])
            if not verdicts:
                verdicts = j.get("judgments", j.get("signal_results", []))

            confirmed = sum(1 for v in verdicts if str(v.get("verdict", "")).upper() == "CONFIRMED")
            suppressed = sum(1 for v in verdicts if str(v.get("verdict", "")).upper() in ("SUPPRESS", "SUPPRESSED", "SAFE"))
            unknown = len(verdicts) - confirmed - suppressed

            has_signal_id = all(v.get("signal_id") for v in verdicts) if verdicts else False

            results.append({
                "rule": rule,
                "batch": batch,
                "total_verdicts": len(verdicts),
                "confirmed": confirmed,
                "suppressed": suppressed,
                "unknown": unknown,
                "has_signal_id": has_signal_id,
            })

    total_confirmed = sum(r.get("confirmed", 0) for r in results)
    total_suppressed = sum(r.get("suppressed", 0) for r in results)
    total_unknown = sum(r.get("unknown", 0) for r in results)
    errors = [r for r in results if "error" in r]

    return {
        "batches": len(results),
        "total_confirmed": total_confirmed,
        "total_suppressed": total_suppressed,
        "total_unknown": total_unknown,
        "errors": len(errors),
        "details": results,
    }


def self_test():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        batch_dir = os.path.join(tmp, "workers", "test.rule", "batch-001")
        os.makedirs(batch_dir)
        verdict = {
            "rule_id": "test.rule",
            "batch_id": "batch-001",
            "verdicts": [
                {"signal_id": "sig-1", "verdict": "CONFIRMED", "file": "a.c", "line": 1, "judgment_matrix": {"Q1_x": True, "Q2_x": True, "Q3_x": False, "conclusion": "CONFIRMED"}},
                {"signal_id": "sig-2", "verdict": "SUPPRESS", "file": "a.c", "line": 2, "judgment_matrix": {"Q1_x": False, "Q2_x": False, "Q3_x": True, "conclusion": "SUPPRESS"}},
            ],
            "summary": {"confirmed": 1, "suppressed": 1},
        }
        with open(os.path.join(batch_dir, "judge_verdict.json"), "w") as f:
            json.dump(verdict, f)

        result = scan_verdicts(tmp)
        assert result["total_confirmed"] == 1
        assert result["total_suppressed"] == 1
        assert result["errors"] == 0
        assert result["batches"] == 1

    print("OK - scan-verdicts self-test passed")
    return 0


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--scan-dir")
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if args.self_test:
        return self_test()

    if not args.scan_dir:
        p.error("--scan-dir is required (or use --self-test)")

    result = scan_verdicts(args.scan_dir)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Batches: {result['batches']}")
        print(f"Confirmed: {result['total_confirmed']}, Suppressed: {result['total_suppressed']}, Unknown: {result['total_unknown']}")
        print(f"Errors: {result['errors']}")
        for d in result.get("details", []):
            if "error" in d:
                print(f"  ERROR {d['rule']}/{d['batch']}: {d['error']}")
            elif d.get("unknown", 0) > 0:
                print(f"  WARN {d['rule']}/{d['batch']}: {d['unknown']} unknown verdicts")


if __name__ == "__main__":
    sys.exit(main())
