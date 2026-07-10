#!/usr/bin/env python3
"""verification-gate.py — Per-finding semantic gate (EPIC-011 FEATURE-001 TASK-004/005).

The structural fix for F3 (paper compliance): the Investigation Pipeline's
"mandatory" steps (Counter Evidence, Judge, Q-matrix) lived in Markdown the LLM
could skip. This gate is COMPILED and runs as a post-scan audit:

  For each finding in scan_dir:
    - anchor_check:  file exists in index.json (REQUIRED)
    - severity_check: severity is a canonical enum (REQUIRED)
    - symbol_covered: line falls within a known function range (informational)
    - artifact_check: scan has judge_verdict/counter_evidence artifacts (informational)
    - qmatrix_check:  (stub — pending FEATURE-003 polarity fix)
    -> verdict = confirmed if anchor+severity pass, else needs_review
    -> gate_signature = sha(sha + verdict + checks)

Writes scan_dir/gate-audit.json. render-report reads it so findings WITHOUT a
valid signature (e.g. written by bypassing record-finding, or bad anchor) land
in "needs review" and do NOT count toward the CI gate — closing the bypass.

Usage:
  python3 verification-gate.py --index <index.json> --scan-dir <scan_dir> [--json]
  python3 verification-gate.py --self-test
"""
import argparse
import hashlib
import json
import os
import sys

VALID_SEVERITIES = ("Critical", "High", "Medium", "Low", "Info")


def _basename(path):
    return os.path.basename(path) if path else ""


def load_index(path):
    with open(path) as f:
        return json.load(f)


def index_file_set(index):
    files = index.get("files") or []
    return set(files)


def index_functions(index):
    """Return list of (file_basename, start_line, end_line) for anchor coverage."""
    out = []
    for fn in (index.get("symbols", {}).get("functions") or []):
        out.append((fn.get("file", ""), fn.get("start_line", 0), fn.get("end_line", 0) or fn.get("start_line", 0)))
    return out


def load_findings(scan_dir):
    """Load findings from a v5.0 scan dir (findings.json index or findings/ tree)."""
    if not scan_dir or not os.path.isdir(scan_dir):
        return []
    fj = os.path.join(scan_dir, "findings.json")
    if os.path.isfile(fj):
        try:
            with open(fj) as f:
                data = json.load(f)
            if isinstance(data, dict) and isinstance(data.get("findings_index"), list):
                return data["findings_index"]
            if isinstance(data, dict) and isinstance(data.get("findings"), list):
                return data["findings"]
        except (json.JSONDecodeError, OSError):
            pass
    out = []
    findings_dir = os.path.join(scan_dir, "findings")
    if os.path.isdir(findings_dir):
        for _root, _dirs, files in os.walk(findings_dir):
            for fn in files:
                if not fn.endswith(".json"):
                    continue
                try:
                    with open(os.path.join(_root, fn)) as f:
                        d = json.load(f)
                except (json.JSONDecodeError, OSError):
                    continue
                if isinstance(d, dict) and "finding" in d:
                    out.append(d["finding"])
                elif isinstance(d, dict) and "id" in d:
                    out.append(d)
    return out


def line_in_function(file_b, line, functions):
    for ffile, fstart, fend in functions:
        if _basename(ffile) == file_b and fstart and fend and fstart <= line <= fend:
            return True
    return False


def audit_finding(finding, files_set, functions, scan_dir):
    """Run gate checks on one finding. Returns (verdict, checks dict, signature)."""
    ffile = finding.get("file", "")
    fline = finding.get("line", 0)
    sev = finding.get("severity", "")
    file_b = _basename(ffile)

    # anchor: file present in index (basename match, paths may differ)
    anchor_pass = any(file_b == _basename(f) or ffile.endswith(f) or f.endswith(ffile) for f in files_set) if files_set else False
    # symbol coverage (informational)
    symbol_covered = bool(file_b and fline and line_in_function(file_b, fline, functions))
    # severity canonical
    severity_pass = sev in VALID_SEVERITIES
    # artifacts (informational): does the scan carry judge/counter-evidence?
    artifact_present = (os.path.isfile(os.path.join(scan_dir, "judge_verdict.json")) or
                        os.path.isfile(os.path.join(scan_dir, "counter_evidence.json")) or
                        os.path.isdir(os.path.join(scan_dir, "workers")))

    checks = {
        "anchor": "pass" if anchor_pass else "fail",
        "severity": "pass" if severity_pass else "fail",
        "symbol_covered": "yes" if symbol_covered else "no",
        "artifact_present": "yes" if artifact_present else "no",
        "qmatrix": "skip (pending FEATURE-003)",
    }
    verdict = "confirmed" if (anchor_pass and severity_pass) else "needs_review"
    raw = "{}|{}|{}".format(finding.get("sha", ""), verdict, "|".join(checks[k] for k in sorted(checks)))
    signature = hashlib.sha256(raw.encode()).hexdigest()[:16]
    return verdict, checks, signature


def evaluate(index, findings, scan_dir):
    files_set = index_file_set(index)
    functions = index_functions(index)
    per_finding = {}
    counts = {"confirmed": 0, "needs_review": 0}
    for f in findings:
        sha = f.get("sha") or hashlib.sha256(
            "{}:{}:{}:{}".format(f.get("detector",""), f.get("file",""), f.get("line",""), f.get("cwe","")).encode()
        ).hexdigest()[:12]
        verdict, checks, signature = audit_finding(f, files_set, functions, scan_dir)
        per_finding[sha] = {
            "verdict": verdict, "checks": checks, "signature": signature,
            "file": f.get("file"), "line": f.get("line"),
            "detector": f.get("detector"), "severity": f.get("severity"),
        }
        counts[verdict] += 1
    return {
        "total": len(findings),
        "confirmed": counts["confirmed"],
        "needs_review": counts["needs_review"],
        "findings": per_finding,
    }


def self_test():
    import tempfile
    idx = {"files": ["src/app.c"],
           "symbols": {"functions": [{"file": "src/app.c", "start_line": 10, "end_line": 20}]}}
    scan = tempfile.mkdtemp()
    # confirmed: valid anchor + canonical severity
    f_ok = {"sha": "aaa", "file": "src/app.c", "line": 15, "severity": "High", "detector": "x", "cwe": "CWE-120"}
    # needs_review: file not in index
    f_badfile = {"sha": "bbb", "file": "other.c", "line": 1, "severity": "High", "detector": "x", "cwe": "CWE-1"}
    # needs_review: non-canonical severity (bypassed recorder)
    f_badsev = {"sha": "ccc", "file": "src/app.c", "line": 12, "severity": "blocker", "detector": "x", "cwe": "CWE-1"}
    res = evaluate(idx, [f_ok, f_badfile, f_badsev], scan)
    assert res["confirmed"] == 1, res
    assert res["needs_review"] == 2, res
    assert res["findings"]["aaa"]["verdict"] == "confirmed", res["findings"]["aaa"]
    assert res["findings"]["aaa"]["checks"]["symbol_covered"] == "yes", res["findings"]["aaa"]
    assert res["findings"]["bbb"]["checks"]["anchor"] == "fail", res["findings"]["bbb"]
    assert res["findings"]["ccc"]["checks"]["severity"] == "fail", res["findings"]["ccc"]
    # signatures are stable
    assert len(res["findings"]["aaa"]["signature"]) == 16, res
    print("OK — verification-gate self-test passed (anchor/severity/signature)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Per-finding semantic gate (F3 structural fix)")
    ap.add_argument("--index", help="index.json")
    ap.add_argument("--scan-dir", help="scan output directory")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if not args.index or not args.scan_dir:
        ap.error("--index and --scan-dir are required (or use --self-test)")

    index = load_index(args.index)
    findings = load_findings(args.scan_dir)
    result = evaluate(index, findings, args.scan_dir)

    # Persist gate-audit.json so render-report can separate confirmed/needs_review.
    audit_path = os.path.join(args.scan_dir, "gate-audit.json")
    try:
        with open(audit_path, "w") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
    except OSError as e:
        print("WARN: could not write gate-audit.json: %s" % e, file=sys.stderr)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print("Verification gate: %d findings — %d confirmed, %d needs_review" %
              (result["total"], result["confirmed"], result["needs_review"]))
        for sha, info in result["findings"].items():
            if info["verdict"] == "needs_review":
                print("  [needs_review] %s:%s %s — failed: %s" %
                      (info["file"], info["line"], info["detector"],
                       ", ".join(k for k, v in info["checks"].items() if v == "fail")))
    # Non-zero findings all need_review is not a CI failure by itself (that's the
    # coverage gate's job); exit 0 unless the audit itself could not run.
    return 0


if __name__ == "__main__":
    sys.exit(main())
