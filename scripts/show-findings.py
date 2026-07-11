#!/usr/bin/env python3
"""Query findings from scan directory (replaces inline python3 -c + find loops).

Usage:
  python3 show-findings.py --scan-dir <dir>                          # list all
  python3 show-findings.py --scan-dir <dir> --detector memory.buffer  # filter
  python3 show-findings.py --scan-dir <dir> --severity Critical       # filter
  python3 show-findings.py --scan-dir <dir> --summary                 # counts only
  python3 show-findings.py --scan-dir <dir> --file src/parser.c       # filter
  python3 show-findings.py --self-test
"""

import json
import os
import sys


def load_findings(scan_dir):
    findings_dir = os.path.join(scan_dir, "findings")
    if not os.path.isdir(findings_dir):
        return []
    results = []
    for root, _dirs, files in os.walk(findings_dir):
        for fn in files:
            if not fn.endswith(".json"):
                continue
            try:
                with open(os.path.join(root, fn)) as f:
                    d = json.load(f)
            except (json.JSONDecodeError, OSError):
                continue
            if isinstance(d, dict) and "finding" in d:
                results.append(d["finding"])
            elif isinstance(d, dict) and "id" in d:
                results.append(d)
    return results


def query(findings, detector=None, severity=None, file_pattern=None):
    result = []
    for f in findings:
        if detector and detector not in f.get("detector", ""):
            continue
        if severity and f.get("severity", "") != severity:
            continue
        if file_pattern and file_pattern not in f.get("file", ""):
            continue
        result.append(f)
    return result


def self_test():
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        fd = os.path.join(tmp, "findings", "memory", "buffer_overflow")
        os.makedirs(fd)
        finding = {
            "id": "test-001",
            "detector": "memory.buffer_overflow",
            "severity": "Critical",
            "cwe": "CWE-120",
            "file": "src/parser.c",
            "line": 20,
            "title": "strcpy overflow",
        }
        with open(os.path.join(fd, "a1b2_parser-20.json"), "w") as f:
            json.dump(finding, f)

        findings = load_findings(tmp)
        assert len(findings) == 1, f"expected 1 finding, got {len(findings)}"

        q = query(findings, detector="buffer")
        assert len(q) == 1

        q = query(findings, severity="Critical")
        assert len(q) == 1

        q = query(findings, file_pattern="parser.c")
        assert len(q) == 1

        q = query(findings, detector="sql")
        assert len(q) == 0

    print("OK - show-findings self-test passed")
    return 0


def main():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--scan-dir", default="")
    p.add_argument("--detector", default="")
    p.add_argument("--severity", default="")
    p.add_argument("--file", default="")
    p.add_argument("--summary", action="store_true")
    p.add_argument("--self-test", action="store_true")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    if args.self_test:
        return self_test()

    if not args.scan_dir:
        p.error("--scan-dir is required (or use --self-test)")

    try:
        findings = load_findings(args.scan_dir)
    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr)
        return 2

    results = query(findings, args.detector or None, args.severity or None, args.file or None)

    if args.summary:
        from collections import Counter
        by_sev = Counter(f.get("severity", "?") for f in results)
        by_det = Counter(f.get("detector", "?") for f in results)
        print(f"Total findings: {len(results)}")
        print(f"By severity: {dict(by_sev)}")
        print(f"By detector: {dict(by_det)}")
    elif args.json:
        print(json.dumps([{k: f.get(k) for k in ("detector", "severity", "cwe", "file", "line", "title")} for f in results], indent=2))
    else:
        for f in results:
            print(f'{f.get("severity", "?"):10s} {f.get("detector", "?"):35s} {f.get("file", "?"):30s} L{f.get("line", "?")}  {f.get("title", "")[:60]}')


if __name__ == "__main__":
    sys.exit(main())
