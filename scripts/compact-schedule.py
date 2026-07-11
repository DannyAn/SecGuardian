#!/usr/bin/env python3
"""Generate compact batch schedule from partition-plan.json (FEATURE-007).

Output format: rule_id | batch_id | signal_count | rule_path
One line per nonempty batch.  Zero-signal batches are omitted.

Usage:
  python3 compact-schedule.py --plan partition-plan.json
  python3 compact-schedule.py --plan partition-plan.json --json   # JSON output
"""

import json
import sys


def self_test():
    import tempfile, os, io, contextlib
    plan = {
        "summary": {},
        "rules": [
            {"rule_id": "test.A", "rule_path": "/x/a.md", "batches": [
                {"batch_id": "batch-001", "signals": [{"callee": "malloc", "file": "a.c", "line": 1}]},
            ]},
            {"rule_id": "test.B", "rule_path": "/x/b.md", "batches": [
                {"batch_id": "batch-001", "signals": []},
            ]},
        ]
    }
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(plan, f)
        plan_path = f.name
    try:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            sys.argv = ["compact-schedule.py", "--plan", plan_path]
            main()
        output = buf.getvalue()
        assert "test.A" in output
        assert "test.B" not in output
        assert "batch-001" in output
    finally:
        os.unlink(plan_path)
    print("OK - compact-schedule self-test passed")
    return 0


def main():
    try:
        import argparse
        p = argparse.ArgumentParser()
        p.add_argument("--plan", default="")
        p.add_argument("--json", action="store_true")
        p.add_argument("--self-test", action="store_true")
        args = p.parse_args()

        if args.self_test:
            return self_test()

        if not args.plan:
            p.error("--plan is required (or use --self-test)")

        with open(args.plan) as f:
            plan = json.load(f)
    except FileNotFoundError:
        print(f"FATAL: partition plan not found: {args.plan}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as e:
        print(f"FATAL: invalid JSON in partition plan: {e}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr)
        return 2

    if args.json:
        batches = []
        for r in plan.get("rules", []):
            for b in r.get("batches", []):
                if len(b.get("signals", b.get("assignment_ids", []))) == 0:
                    continue
                batches.append({
                    "rule_id": r["rule_id"],
                    "batch_id": b["batch_id"],
                    "signal_count": len(b.get("signals", b.get("assignment_ids", []))),
                    "rule_path": r["rule_path"],
                })
        print(json.dumps({"batches": batches, "total": len(batches)}, indent=2))
    else:
        for r in plan.get("rules", []):
            for b in r.get("batches", []):
                n = len(b.get("signals", b.get("assignment_ids", [])))
                if n == 0:
                    continue
                print(f'{r["rule_id"]:35s} {b["batch_id"]:10s} {n:4d} sig  {r["rule_path"]}')


if __name__ == "__main__":
    sys.exit(main())
