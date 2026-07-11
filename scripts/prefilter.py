#!/usr/bin/env python3
"""Deterministic signal pre-filter (FEATURE-007 P2).

Consumes index.json variable-level data (pointer_validations, alloc_free,
variable_writes, taint_flows, declarations) and applies conservative
per-rule filtering rules.  Only high-confidence safe signals are removed;
any uncertainty keeps the signal for LLM investigation.

Usage:
  python3 prefilter.py --index index.json --rule buffer_overflow [--json]
  python3 prefilter.py --self-test
"""

import json
import sys


def prefilter_null_dereference(index, call_sites):
    """Filter malloc/calloc/realloc calls whose return value is NULL-checked
    before dereference.  Conservative: only filters when pointer_validations
    explicitly records has_null_check=true AND is_dereferenced=true."""
    filtered, kept, reasons = [], [], []
    for cs in call_sites:
        if cs.get("callee") not in ("malloc", "calloc", "realloc"):
            kept.append(cs)
            continue
        # Find pointer_validations for the caller function
        fn = cs.get("caller", "")
        file = cs.get("file", "")
        validations = [pv for pv in index.get("pointer_validations", [])
                       if pv.get("function") == fn and pv.get("file") == file]
        checked = any(pv.get("has_null_check") and pv.get("is_dereferenced") for pv in validations)
        if checked:
            reasons.append({"signal_id": cs.get("signal_id", ""), "reason": "null_check+verified"})
            filtered.append(cs)
        else:
            kept.append(cs)
    return filtered, kept, reasons


def prefilter_double_free(index, call_sites):
    """Filter free() calls in functions that have only a single free() call.
    A function with only one free() cannot be a double-free.  Conservative:
    only filters when the function scope is unambiguous."""
    from collections import Counter
    fn_free_count = Counter()
    for cs in call_sites:
        if cs.get("callee") in ("free", "delete"):
            key = (cs.get("file", ""), cs.get("caller", ""))
            fn_free_count[key] += 1

    filtered, kept, reasons = [], [], []
    for cs in call_sites:
        if cs.get("callee") not in ("free", "delete"):
            kept.append(cs)
            continue
        key = (cs.get("file", ""), cs.get("caller", ""))
        if fn_free_count[key] < 2:
            reasons.append({"signal_id": cs.get("signal_id", ""),
                           "reason": f"single_free_in_{cs.get('caller','?')}"})
            filtered.append(cs)
        else:
            kept.append(cs)
    return filtered, kept, reasons


def prefilter_memory_leak(index, call_sites):
    """Filter malloc calls that have a matching free in alloc_free pairs.
    Conservative: only filters when the alloc/free pair is explicit."""
    alloc_free = index.get("alloc_free", {}).get("pairs", [])
    # Build set of (file, alloc_line) that have free sites
    paired = set()
    for pair in alloc_free:
        paired.add((pair.get("alloc_file", ""), pair.get("alloc_line", 0)))

    filtered, kept, reasons = [], [], []
    for cs in call_sites:
        if cs.get("callee") not in ("malloc", "calloc", "realloc"):
            kept.append(cs)
            continue
        if (cs.get("file", ""), cs.get("line", 0)) in paired:
            reasons.append({"signal_id": cs.get("signal_id", ""),
                           "reason": f"has_matching_free"})
            filtered.append(cs)
        else:
            kept.append(cs)
    return filtered, kept, reasons


def prefilter_command_injection(index, call_sites):
    """Deprioritize system/popen calls whose arguments are NOT in taint_flows.
    Does NOT filter — only marks as low-priority.  Even constant-argument
    system() calls may be dangerous (e.g., hardcoded paths with injection)."""
    taint_sinks = set()
    for tf in index.get("taint_flows", []):
        taint_sinks.add((tf.get("file", ""), tf.get("sink_line", 0)))

    filtered, kept, reasons = [], [], []
    for cs in call_sites:
        if cs.get("callee") not in ("system", "popen", "exec", "CreateProcess"):
            kept.append(cs)
            continue
        if (cs.get("file", ""), cs.get("line", 0)) in taint_sinks:
            kept.append(cs)  # Tainted source — keep
        else:
            kept.append(cs)  # Keep but marked low-priority (conservative)
            reasons.append({"signal_id": cs.get("signal_id", ""),
                           "reason": "low_priority_no_taint_evidence"})
    return filtered, kept, reasons


def self_test():
    """TDD self-test: verify prefilter conservativeness and correctness."""
    errors = []

    # Mock index with known vulnerabilities
    index = {
        "pointer_validations": [
            {"function": "safe_handler", "file": "a.c", "variable": "ptr",
             "has_null_check": True, "is_dereferenced": True},
            {"function": "unsafe_handler", "file": "a.c", "variable": "buf",
             "has_null_check": False, "is_dereferenced": True},
        ],
        "alloc_free": {
            "pairs": [
                {"alloc_func": "malloc", "alloc_file": "a.c", "alloc_line": 10,
                 "free_sites": [{"line": 20}]},
            ]
        },
        "taint_flows": [
            {"file": "a.c", "sink_line": 25, "sink": "system",
             "source": "param:cmd", "tainted_var": "cmd"},
        ],
    }
    call_sites = [
        {"callee": "malloc", "caller": "safe_handler", "file": "a.c", "line": 5,
         "signal_id": "sig-safe-malloc"},
        {"callee": "malloc", "caller": "unsafe_handler", "file": "a.c", "line": 15,
         "signal_id": "sig-unsafe-malloc"},
        {"callee": "free", "caller": "single_free_fn", "file": "a.c", "line": 8,
         "signal_id": "sig-single-free"},
        {"callee": "free", "caller": "double_free_fn", "file": "a.c", "line": 10,
         "signal_id": "sig-df-1"},
        {"callee": "free", "caller": "double_free_fn", "file": "a.c", "line": 12,
         "signal_id": "sig-df-2"},
        {"callee": "malloc", "caller": "paired_fn", "file": "a.c", "line": 10,
         "signal_id": "sig-paired-malloc"},
        {"callee": "malloc", "caller": "leak_fn", "file": "a.c", "line": 30,
         "signal_id": "sig-leak-malloc"},
        {"callee": "system", "caller": "tainted_cmd", "file": "a.c", "line": 25,
         "signal_id": "sig-tainted-system"},
        {"callee": "system", "caller": "safe_cmd", "file": "a.c", "line": 35,
         "signal_id": "sig-safe-system"},
    ]

    # T1: null_dereference — safe_handler's malloc is checked → filtered
    nd_calls = [c for c in call_sites if c["callee"] in ("malloc", "calloc", "realloc")]
    filtered, kept, _ = prefilter_null_dereference(index, nd_calls)
    assert any(c["signal_id"] == "sig-safe-malloc" for c in filtered), "T1: safe_handler malloc should be filtered"
    assert any(c["signal_id"] == "sig-unsafe-malloc" for c in kept), "T1: unsafe_handler malloc should be kept"

    # T2: double_free — single free → filtered, two frees in same fn → kept
    df_calls = [c for c in call_sites if c["callee"] in ("free", "delete")]
    filtered, kept, _ = prefilter_double_free(index, df_calls)
    assert any(c["signal_id"] == "sig-single-free" for c in filtered), "T2: single free should be filtered"
    assert any(c["signal_id"] == "sig-df-1" for c in kept), "T2: double_free_fn free should be kept"
    assert any(c["signal_id"] == "sig-df-2" for c in kept), "T2: double_free_fn free should be kept"

    # T3: memory_leak — paired malloc → filtered, unpaired → kept
    ml_calls = [c for c in call_sites if c["callee"] in ("malloc", "calloc", "realloc")]
    filtered, kept, _ = prefilter_memory_leak(index, ml_calls)
    assert any(c["signal_id"] == "sig-paired-malloc" for c in filtered), "T3: paired malloc should be filtered"
    assert any(c["signal_id"] == "sig-leak-malloc" for c in kept), "T3: unpaired malloc should be kept"

    # T4: command_injection — tainted system kept, untainted kept but flagged
    ci_calls = [c for c in call_sites if c["callee"] in ("system", "popen", "exec")]
    _, kept, reasons = prefilter_command_injection(index, ci_calls)
    assert len(kept) == 2, "T4: all system calls should be kept (conservative)"
    assert len(reasons) == 1, "T4: one system call should have low_priority flag"
    assert reasons[0]["reason"] == "low_priority_no_taint_evidence"

    print("OK - prefilter self-test passed (null_deref, double_free, memory_leak, cmd_injection)")
    return 0


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--index")
    parser.add_argument("--rule", choices=["null_dereference", "double_free", "memory_leak", "command_injection"])
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if not args.index or not args.rule:
        parser.error("--index and --rule are required (or use --self-test)")

    with open(args.index) as f:
        index = json.load(f)

    call_sites = index.get("call_sites", [])
    prefilter_fn = {
        "null_dereference": prefilter_null_dereference,
        "double_free": prefilter_double_free,
        "memory_leak": prefilter_memory_leak,
        "command_injection": prefilter_command_injection,
    }[args.rule]

    filtered, kept, reasons = prefilter_fn(index, call_sites)
    result = {
        "rule": args.rule,
        "total": len(call_sites),
        "filtered": len(filtered),
        "kept": len(kept),
        "reasons": reasons,
    }
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"{args.rule}: {result['total']} signals → {result['filtered']} filtered, {result['kept']} kept")


if __name__ == "__main__":
    sys.exit(main())
