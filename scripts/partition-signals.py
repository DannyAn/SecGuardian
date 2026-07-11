#!/usr/bin/env python3
"""Build a fail-closed, per-rule signal partition plan."""
import argparse
import hashlib
import json
import os
import re
import sys

SIGNAL_FIELDS = (
    "call_sites", "suspicious_expressions", "control_flow", "pointer_validations",
    "struct_inits", "variable_writes", "string_literals", "declarations",
    "value_constants", "config_patterns",
)
KEY_ALIASES = {"cat": "category"}


def parse_frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return None
    match = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
    if not match:
        return None
    result = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            result[key.strip()] = value.strip().strip('"').strip("'")
    return result


def _split_top_level(spec, separators):
    parts, start, depth = [], 0, 0
    for pos, char in enumerate(spec):
        depth += char == "["
        depth -= char == "]"
        if depth == 0 and char in separators:
            parts.append(spec[start:pos].strip())
            start = pos + 1
    parts.append(spec[start:].strip())
    return [part for part in parts if part]


def _parse_value(raw):
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'":
        return raw[1:-1]
    if raw.lower() in ("true", "false"):
        return raw.lower() == "true"
    return raw


def parse_signal_source(spec):
    """Parse unions (+ or |), comma alternatives, and AND predicates."""
    clauses = []
    for term in _split_top_level(spec.strip(), "+|"):
        match = re.fullmatch(r"(\w+)(?:\[(.*)\])?", term)
        if not match or match.group(1) not in SIGNAL_FIELDS:
            raise ValueError("unsupported signal_source term: %s" % term)
        predicates = []
        if match.group(2):
            for predicate in re.split(r"\s+AND\s+|\s*,\s*", match.group(2)):
                pm = re.fullmatch(r"(\w+)\s*=\s*(.+)", predicate.strip())
                if not pm:
                    raise ValueError("unsupported signal_source predicate: %s" % predicate)
                key = KEY_ALIASES.get(pm.group(1), pm.group(1))
                raw_value = _parse_value(pm.group(2))
                values = (raw_value.split("|") if isinstance(raw_value, str) else [raw_value])
                existing = next((item for item in predicates if item[0] == key), None)
                if existing:
                    existing[1].extend(value for value in values if value not in existing[1])
                else:
                    predicates.append((key, values))
        clauses.append((match.group(1), predicates))
    if not clauses:
        raise ValueError("empty signal_source")
    return clauses


def _matches(signal, predicates):
    return all("*" in values or signal.get(key) in values for key, values in predicates)


def _signal_id(field, signal):
    identity = {
        "field": field,
        "file": signal.get("file", ""),
        "line": signal.get("line", 0),
        "kind": signal.get("callee") or signal.get("kind") or signal.get("category") or "",
    }
    return "sig-" + hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()[:16]


def collect_rule_signals(index, clauses):
    collected = {}
    for field, predicates in clauses:
        for signal in index.get(field) or []:
            if not isinstance(signal, dict) or not _matches(signal, predicates):
                continue
            item = dict(signal)
            item["signal_field"] = field
            item["signal_id"] = _signal_id(field, signal)
            collected[item["signal_id"]] = item
    return list(collected.values())


def partition(index, rules, batch_size):
    if batch_size <= 0:
        raise ValueError("batch_size must be positive")
    plan_rules, covered = [], set()
    for rule in rules:
        clauses = parse_signal_source(rule.get("signal_source", ""))
        signals = collect_rule_signals(index, clauses)
        covered.update(signal["signal_id"] for signal in signals)
        batches = []
        for offset in range(0, len(signals), batch_size):
            batch_signals = signals[offset:offset + batch_size]
            batch_no = len(batches) + 1
            batches.append({
                "batch_id": "batch-%03d" % batch_no,
                "assignment_ids": ["%s:%s" % (rule["rule_id"], s["signal_id"]) for s in batch_signals],
                "signals": batch_signals,
            })
        plan_rules.append({
            "rule_id": rule["rule_id"], "rule_path": rule["rule_path"],
            "signal_source": rule["signal_source"],
            "signal_count": len(signals),
            "batch_count": len(batches), "batches": batches,
        })
    assignments = sum(rule["signal_count"] for rule in plan_rules)
    return {"schema_version": "2.0", "summary": {
        "unique_signals": len(covered), "partition_assignments": assignments,
        "rule_count": len(plan_rules), "batch_count": sum(r["batch_count"] for r in plan_rules),
        "batch_size": batch_size,
    }, "rules": plan_rules}


def load_rules(rules_dir):
    if not rules_dir or not os.path.isdir(rules_dir):
        raise ValueError("rules directory not found: %s" % rules_dir)
    rules = []
    for entry in sorted(os.listdir(rules_dir)):
        path = os.path.join(rules_dir, entry, "rule.md")
        if not os.path.isfile(path):
            continue
        frontmatter = parse_frontmatter(path)
        if not frontmatter or not frontmatter.get("signal_source"):
            raise ValueError("rule missing signal_source: %s" % path)
        rules.append({"rule_id": frontmatter.get("skill_id") or entry,
                      "rule_path": path, "signal_source": frontmatter["signal_source"]})
    if not rules:
        raise ValueError("no rules loaded from: %s" % rules_dir)
    return rules


def self_test():
    index = {"call_sites": [
        {"callee": "malloc", "category": "memory", "file": "a.c", "line": 1},
        {"callee": "system", "category": "exec", "file": "a.c", "line": 2}],
        "pointer_validations": [{"category": "param_check", "has_null_check": False,
                                  "is_dereferenced": True, "file": "a.c", "line": 3}],
        "string_literals": [{"value": "secret", "file": "a.c", "line": 4}]}
    rules = [
        {"rule_id": "buffer", "rule_path": "x", "signal_source": 'call_sites[cat="string", cat="memory"]'},
        {"rule_id": "must", "rule_path": "y", "signal_source": 'call_sites[cat="memory|io"]'},
        {"rule_id": "input", "rule_path": "z", "signal_source": 'call_sites[cat="exec"] | pointer_validations[cat="param_check" AND has_null_check=false AND is_dereferenced=true]'},
        {"rule_id": "secret", "rule_path": "q", "signal_source": 'call_sites[cat="crypto"]+string_literals'},
        {"rule_id": "all", "rule_path": "w", "signal_source": 'call_sites[cat="*"]'},
    ]
    plan = partition(index, rules, 1)
    by_id = {r["rule_id"]: r for r in plan["rules"]}
    assert by_id["buffer"]["signal_count"] == 1
    assert by_id["must"]["signal_count"] == 1
    assert by_id["input"]["signal_count"] == 2
    assert by_id["secret"]["signal_count"] == 1
    assert by_id["all"]["signal_count"] == 2
    assert plan["summary"]["partition_assignments"] == 7
    assert all("signal_id" in b["signals"][0] for r in plan["rules"] for b in r["batches"])
    print("OK - partition-signals self-test passed")
    return 0


def integration_test(index_path, rules_dir):
    """Prove a real no-answer index signal reaches the intended C++ rule."""
    with open(index_path, encoding="utf-8") as f:
        index = json.load(f)
    target = [signal for signal in index.get("call_sites", [])
              if str(signal.get("file", "")).endswith("src/p1_safecopy_wrapper.c")
              and signal.get("caller") == "process_user_data_unsafe"
              and signal.get("callee") == "memcpy"]
    assert len(target) == 1, "expected one anchored unsafe memcpy signal: %r" % target
    plan = partition(index, load_rules(rules_dir), 20)
    rules = {rule["rule_id"]: rule for rule in plan["rules"]}
    signal_id = _signal_id("call_sites", target[0])
    routed = [signal for batch in rules["memory.buffer_overflow"]["batches"]
              for signal in batch["signals"] if signal["signal_id"] == signal_id]
    assert len(routed) == 1, "unsafe memcpy did not reach memory.buffer_overflow"
    print("OK - real C++ index routes unsafe memcpy to memory.buffer_overflow")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--index")
    parser.add_argument("--rules-dir")
    parser.add_argument("--batch-size", type=int, default=20)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--integration-test", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if args.integration_test:
        if not args.index or not args.rules_dir:
            parser.error("--integration-test requires --index and --rules-dir")
        return integration_test(args.index, args.rules_dir)
    if not args.index or not args.rules_dir:
        parser.error("--index and --rules-dir are required")
    try:
        with open(args.index, encoding="utf-8") as f:
            plan = partition(json.load(f), load_rules(args.rules_dir), args.batch_size)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print("FATAL: %s" % error, file=sys.stderr)
        return 2
    print(json.dumps(plan, indent=2, ensure_ascii=False) if args.json else
          "Partition plan: %(rule_count)d rules, %(batch_count)d batches, %(partition_assignments)d assignments" % plan["summary"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
