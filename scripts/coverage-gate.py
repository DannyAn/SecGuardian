#!/usr/bin/env python3
"""Reconcile every partition assignment with a finding or dismissal."""
import argparse
import json
import os
import sys


def expected_assignments(plan):
    expected = set()
    for rule in plan.get("rules") or []:
        for batch in rule.get("batches") or []:
            expected.update(batch.get("assignment_ids") or [])
    return expected


def _load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def finding_assignments(scan_dir):
    assignments = set()
    root = os.path.join(scan_dir, "findings")
    if not os.path.isdir(root):
        return assignments
    for current, _dirs, files in os.walk(root):
        for name in files:
            data = _load_json(os.path.join(current, name)) if name.endswith(".json") else None
            finding = data.get("finding", data) if isinstance(data, dict) else {}
            rule_id, signal_id = finding.get("rule_id"), finding.get("signal_id")
            if rule_id and signal_id:
                assignments.add("%s:%s" % (rule_id, signal_id))
    return assignments


def dismissed_assignments(scan_dir):
    data = _load_json(os.path.join(scan_dir, "dismissed.json"))
    entries = data.get("dismissed", []) if isinstance(data, dict) else data
    assignments = set()
    for entry in entries or []:
        if not isinstance(entry, dict) or not entry.get("reason"):
            continue
        if entry.get("rule_id") and entry.get("signal_id"):
            assignments.add("%s:%s" % (entry["rule_id"], entry["signal_id"]))
    return assignments


def judged_suppressions(scan_dir):
    """Derive audited suppressions from canonical per-batch artifacts."""
    assignments = set()
    workers = os.path.join(scan_dir, "workers")
    if not os.path.isdir(workers):
        return assignments
    required = ("hypotheses.json", "evidence.json", "counter_evidence.json", "judge_verdict.json")
    for rule_id in os.listdir(workers):
        rule_dir = os.path.join(workers, rule_id)
        if not os.path.isdir(rule_dir):
            continue
        for batch_id in os.listdir(rule_dir):
            batch_dir = os.path.join(rule_dir, batch_id)
            if not os.path.isdir(batch_dir):
                continue
            artifacts = {name: _load_json(os.path.join(batch_dir, name)) for name in required}
            if not all(data is not None for data in artifacts.values()):
                continue
            judge = artifacts["judge_verdict.json"]
            verdicts = judge.get("verdicts", []) if isinstance(judge, dict) else []
            for verdict in verdicts:
                if not isinstance(verdict, dict) or not verdict.get("signal_id"):
                    continue
                conclusion = str(verdict.get("verdict") or verdict.get("conclusion") or "").upper()
                if conclusion in ("SUPPRESS", "SUPPRESSED", "SAFE"):
                    assignments.add("%s:%s" % (rule_id, verdict["signal_id"]))
    return assignments


def evaluate(plan, scan_dir):
    expected = expected_assignments(plan)
    findings = finding_assignments(scan_dir)
    dismissed = dismissed_assignments(scan_dir) | judged_suppressions(scan_dir)
    accounted = (findings | dismissed) & expected
    missing = sorted(expected - accounted)
    unknown = sorted((findings | dismissed) - expected)
    coverage = len(accounted) / len(expected) if expected else 1.0
    verdict = "PASSED" if not missing and not unknown else "BLOCKED"
    return {"expected_assignments": len(expected), "accounted_assignments": len(accounted),
            "coverage": round(coverage, 4), "missing": missing, "unknown": unknown,
            "verdict": verdict}


def self_test():
    import tempfile
    plan = {"rules": [{"batches": [{"assignment_ids": ["r:s1", "r:s2"]}]}]}
    scan = tempfile.mkdtemp()
    os.makedirs(os.path.join(scan, "findings", "r"))
    with open(os.path.join(scan, "findings", "r", "one.json"), "w") as f:
        json.dump({"finding": {"rule_id": "r", "signal_id": "s1"}}, f)
    assert evaluate(plan, scan)["verdict"] == "BLOCKED"
    with open(os.path.join(scan, "dismissed.json"), "w") as f:
        json.dump({"dismissed": [{"rule_id": "r", "signal_id": "s2", "reason": "guarded"}]}, f)
    result = evaluate(plan, scan)
    assert result["verdict"] == "PASSED" and result["coverage"] == 1.0
    print("OK - coverage-gate self-test passed")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan")
    parser.add_argument("--scan-dir")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.plan or not args.scan_dir:
        parser.error("--plan and --scan-dir are required")
    plan = _load_json(args.plan)
    if not isinstance(plan, dict):
        print("FATAL: cannot read partition plan", file=sys.stderr)
        return 2
    result = evaluate(plan, args.scan_dir)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print("Coverage gate: %s (%d/%d assignments)" %
              (result["verdict"], result["accounted_assignments"], result["expected_assignments"]))
    return 1 if result["verdict"] == "BLOCKED" else 0


if __name__ == "__main__":
    sys.exit(main())
