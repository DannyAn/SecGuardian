#!/usr/bin/env python3
"""partition-signals.py — Per-rule signal partitioning (EPIC-011 FEATURE-006, M3).

Embodies the dispatch architecture (ADR-006): per-rule isolated tasks are only
affordable because the ENGINE pre-filters signals per rule. This tool reads the
index signals + the rule registry (rule.md frontmatter signal_source) and emits
a platform-neutral partition plan: {rule: [batch1, batch2, ...]}.

The command template (Claude/OpenCode) consumes this plan and dispatches one
isolated task per (rule, batch) — never dumping all rules/signals to the LLM at
once (concern #1) and never re-scanning the codebase per rule (concern #3).

Usage:
  python3 partition-signals.py --index <index.json> --rules-dir <.../cpp/rules> [--batch-size 20]
  python3 partition-signals.py --self-test
"""
import argparse
import json
import os
import re
import sys

# signal_source field → index.json field. (call_sites etc. are top-level lists.)
SIGNAL_FIELDS = (
    "call_sites", "suspicious_expressions", "control_flow", "pointer_validations",
    "struct_inits", "variable_writes", "string_literals", "declarations",
    "value_constants", "config_patterns",
)
# filter-key aliases (rule frontmatter uses short keys; index uses full names)
KEY_ALIASES = {"cat": "category"}


def parse_frontmatter(path):
    """Return {skill_id, signal_source} from a rule.md frontmatter (tolerant)."""
    try:
        with open(path) as f:
            text = f.read()
    except OSError:
        return None
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
    if not m:
        return None
    fm = m.group(1)
    out = {}
    for line in fm.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def parse_signal_source(spec):
    """'call_sites[cat="memory"]' -> ('call_sites', 'category', 'memory').
    'suspicious_expressions' -> ('suspicious_expressions', None, None)."""
    spec = spec.strip()
    m = re.match(r"^(\w+)(?:\[(\w+)\s*=\s*\"([^\"]+)\"\])?$", spec)
    if not m:
        return None, None, None
    field, key, val = m.group(1), m.group(2), m.group(3)
    if key:
        key = KEY_ALIASES.get(key, key)
    return field, key, val


def signal_matches(sig, key, val):
    if key is None:
        return True
    return str(sig.get(key, "")) == val


def collect_rule_signals(index, field, key, val):
    sigs = index.get(field) or []
    return [s for s in sigs if signal_matches(s, key, val)]


def batchify(items, size):
    if size <= 0:
        return [items]
    return [items[i:i + size] for i in range(0, len(items), size)] or ([] if not items else [items])


def partition(index, rules, batch_size):
    """rules = list of {rule_id, rule_path, signal_source}. Returns plan dict."""
    total_signals = sum(len(index.get(f) or []) for f in SIGNAL_FIELDS)
    partitioned = 0
    plan_rules = []
    for r in rules:
        field, key, val = parse_signal_source(r.get("signal_source", ""))
        if field not in SIGNAL_FIELDS:
            continue  # rule with unknown/empty signal_source — skip (no engine signal)
        sigs = collect_rule_signals(index, field, key, val)
        batches = batchify(sigs, batch_size)
        partitioned += len(sigs)
        plan_rules.append({
            "rule_id": r["rule_id"],
            "rule_path": r["rule_path"],
            "signal_source": r.get("signal_source", ""),
            "signal_count": len(sigs),
            "batch_count": len(batches),
            "batches": batches,
        })
    # unpartitioned = signals not matched by any rule (for coverage accounting)
    unpartitioned = total_signals - partitioned
    return {
        "summary": {
            "total_signals": total_signals,
            "partitioned_signals": partitioned,
            "unpartitioned_signals": unpartitioned,
            "rule_count": len(plan_rules),
            "batch_count": sum(r["batch_count"] for r in plan_rules),
            "batch_size": batch_size,
        },
        "rules": plan_rules,
    }


def load_rules(rules_dir):
    rules = []
    if not rules_dir or not os.path.isdir(rules_dir):
        return rules
    for entry in sorted(os.listdir(rules_dir)):
        rp = os.path.join(rules_dir, entry, "rule.md")
        if not os.path.isfile(rp):
            continue
        fm = parse_frontmatter(rp)
        if not fm:
            continue
        rid = fm.get("skill_id") or fm.get("name") or entry
        rules.append({"rule_id": rid, "rule_path": rp, "signal_source": fm.get("signal_source", "")})
    return rules


def self_test():
    import tempfile
    index = {
        "call_sites": [
            {"callee": "malloc", "category": "memory", "file": "a.c", "line": 1},
            {"callee": "system", "category": "system", "file": "a.c", "line": 2},
        ],
        "suspicious_expressions": [
            {"kind": "assignment_in_condition", "file": "a.c", "line": 3},
            {"kind": "operator_precedence", "file": "a.c", "line": 4},
        ],
    }
    rules = [
        {"rule_id": "memory.null", "rule_path": "x", "signal_source": 'call_sites[cat="memory"]'},
        {"rule_id": "semantic.assignment_in_condition", "rule_path": "y",
         "signal_source": 'suspicious_expressions[kind="assignment_in_condition"]'},
    ]
    plan = partition(index, rules, batch_size=10)
    assert plan["summary"]["total_signals"] == 4, plan["summary"]
    assert plan["summary"]["partitioned_signals"] == 2, plan["summary"]
    assert plan["summary"]["unpartitioned_signals"] == 2, plan["summary"]  # system call + operator_precedence
    by_id = {r["rule_id"]: r for r in plan["rules"]}
    assert by_id["memory.null"]["signal_count"] == 1, by_id["memory.null"]
    assert by_id["semantic.assignment_in_condition"]["signal_count"] == 1, by_id
    # batch_size 1 -> each signal its own batch
    plan1 = partition(index, rules, batch_size=1)
    assert all(r["batch_count"] == r["signal_count"] for r in plan1["rules"]), plan1
    # cat→category alias works (memory rule got the memory call_site, not system)
    assert by_id["memory.null"]["batches"][0][0]["callee"] == "malloc", by_id["memory.null"]
    print("OK — partition-signals self-test passed (per-rule grouping + batching + alias)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Per-rule signal partitioning (M3)")
    ap.add_argument("--index", help="index.json")
    ap.add_argument("--rules-dir", help="dir of rule subfolders (e.g. skills/secguard/cpp/rules)")
    ap.add_argument("--batch-size", type=int, default=20)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if not args.index or not args.rules_dir:
        ap.error("--index and --rules-dir are required (or use --self-test)")

    with open(args.index) as f:
        index = json.load(f)
    rules = load_rules(args.rules_dir)
    plan = partition(index, rules, args.batch_size)

    if args.json:
        print(json.dumps(plan, indent=2, ensure_ascii=False))
    else:
        s = plan["summary"]
        print("Partition plan: %d rules, %d batches (size %d)" %
              (s["rule_count"], s["batch_count"], s["batch_size"]))
        print("  signals: %d total, %d partitioned, %d unpartitioned" %
              (s["total_signals"], s["partitioned_signals"], s["unpartitioned_signals"]))
        for r in plan["rules"]:
            print("  %s: %d signals / %d batches" % (r["rule_id"], r["signal_count"], r["batch_count"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
