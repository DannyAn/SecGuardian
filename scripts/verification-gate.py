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
    """Load findings from the findings/ directory tree (NOT findings.json summary index).

    Findings from findings.json lack provenance fields (rule_id/batch_id/signal_id),
    so we resolve from the per-finding JSON files under findings/.
    """
    if not scan_dir or not os.path.isdir(scan_dir):
        return []
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

    # Anchor paths by normalized suffix, never basename alone (common.c collisions are common).
    normalized = os.path.normpath(ffile)
    anchor_pass = any(normalized == os.path.normpath(f) or
                      normalized.endswith(os.sep + os.path.normpath(f)) or
                      os.path.normpath(f).endswith(os.sep + normalized)
                      for f in files_set) if files_set else False
    # symbol coverage (informational)
    symbol_covered = bool(file_b and fline and line_in_function(file_b, fline, functions))
    # severity canonical
    severity_pass = sev in VALID_SEVERITIES
    artifact_pass, qmatrix_pass = audit_provenance(finding, scan_dir)

    checks = {
        "anchor": "pass" if anchor_pass else "fail",
        "severity": "pass" if severity_pass else "fail",
        "symbol_covered": "yes" if symbol_covered else "no",
        "artifacts": "pass" if artifact_pass else "fail",
        "qmatrix": "pass" if qmatrix_pass else "fail",
    }
    verdict = "confirmed" if all((anchor_pass, severity_pass, artifact_pass, qmatrix_pass)) else "needs_review"
    raw = "{}|{}|{}".format(finding.get("sha", ""), verdict, "|".join(checks[k] for k in sorted(checks)))
    signature = hashlib.sha256(raw.encode()).hexdigest()[:16]
    return verdict, checks, signature


def _load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def audit_provenance(finding, scan_dir):
    """Require all batch artifacts and a consistent Judge verdict for this signal."""
    rule_id, batch_id, signal_id = (finding.get("rule_id"), finding.get("batch_id"),
                                     finding.get("signal_id"))
    if not all((rule_id, batch_id, signal_id)):
        return False, False
    batch_dir = os.path.join(scan_dir, "workers", rule_id, batch_id)
    required = ("hypotheses.json", "evidence.json", "counter_evidence.json", "judge_verdict.json")
    artifacts = {name: _load_json(os.path.join(batch_dir, name)) for name in required}
    if not all(data is not None for data in artifacts.values()):
        return False, False
    judge = artifacts["judge_verdict.json"]
    verdicts = judge.get("verdicts", []) if isinstance(judge, dict) else []
    for item in verdicts:
        if not isinstance(item, dict) or item.get("signal_id") != signal_id:
            continue
        if item.get("file") != finding.get("file") or int(item.get("line", 0)) != int(finding.get("line", 0)):
            continue
        conclusion = str(item.get("verdict") or item.get("conclusion") or "").upper()
        matrix = item.get("judgment_matrix") or {}
        q1, q3 = _qval(matrix, "Q1_"), _qval(matrix, "Q3_")
        return conclusion == "CONFIRMED", (q1 is not None and q3 is not None and
                                            _qmatrix_consistent(conclusion, q1, q3))
    return True, False


def _artifact_signal_ids(data):
    ids, stack = set(), [data]
    while stack:
        item = stack.pop()
        if isinstance(item, dict):
            if item.get("signal_id"):
                ids.add(item["signal_id"])
            stack.extend(item.values())
        elif isinstance(item, list):
            stack.extend(item)
    return ids


def _planned_signal_ids(plan_path, rule_id, batch_id):
    plan = _load_json(plan_path)
    for rule in (plan or {}).get("rules", []):
        if rule.get("rule_id") != rule_id:
            continue
        for batch in rule.get("batches", []):
            if batch.get("batch_id") == batch_id:
                return {s.get("signal_id") for s in batch.get("signals", []) if s.get("signal_id")}
    return set()


def audit_batch(scan_dir, rule_id, batch_id, plan_path=None):
    """Validate canonical pilot artifacts before expensive fan-out."""
    batch_dir = os.path.join(scan_dir, "workers", rule_id, batch_id)
    required = ("hypotheses.json", "evidence.json", "counter_evidence.json", "judge_verdict.json")
    artifacts = {name: _load_json(os.path.join(batch_dir, name)) for name in required}
    missing = [name for name, data in artifacts.items() if data is None]
    judge = artifacts["judge_verdict.json"]
    verdicts = judge.get("verdicts", []) if isinstance(judge, dict) else []
    invalid = []
    expected_ids = _planned_signal_ids(plan_path, rule_id, batch_id) if plan_path else set()
    gaps = {}
    if expected_ids:
        for name, data in artifacts.items():
            missing_ids = sorted(expected_ids - _artifact_signal_ids(data))
            if missing_ids:
                gaps[name] = missing_ids
    for item in verdicts:
        if not isinstance(item, dict) or not item.get("signal_id"):
            invalid.append("missing signal_id")
            continue
        matrix = item.get("judgment_matrix") or {}
        q1, q3 = _qval(matrix, "Q1_"), _qval(matrix, "Q3_")
        conclusion = str(item.get("verdict") or item.get("conclusion") or "").upper()
        if q1 is None or q3 is None or not _qmatrix_consistent(conclusion, q1, q3):
            invalid.append(item.get("signal_id"))
    return {"rule_id": rule_id, "batch_id": batch_id, "missing": missing,
            "verdict_count": len(verdicts), "invalid_verdicts": invalid,
            "artifact_signal_gaps": gaps,
            "verdict": "PASSED" if not missing and verdicts and not invalid and not gaps else "BLOCKED"}


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
    # Q-matrix consistency audit (F7): load workers/*/judge_verdict.json and
    # flag verdicts whose conclusion contradicts Q1/Q3 (Q1=true defect, Q3=true
    # mitigation). Closes the TASK-006 stub — Judge self-report becomes
    # engine-verifiable.
    qm = audit_qmatrix(scan_dir)
    return {
        "total": len(findings),
        "confirmed": counts["confirmed"],
        "needs_review": counts["needs_review"],
        "findings": per_finding,
        "qmatrix_checked": qm["checked"],
        "qmatrix_inconsistencies": qm["inconsistencies"],
    }


def audit_qmatrix(scan_dir):
    """Scan workers/*/judge_verdict.json for Q-matrix/conclusion inconsistencies.

    Canonical polarity (dispatch-protocol.md, F7 fix):
      CONFIRMED  requires Q1=true (defect) AND Q3=false (no mitigation)
      SUPPRESS/SAFE requires Q1=false OR Q3=true
    Q1 = any judgment_matrix key starting "Q1_" (defect, true=danger).
    Q3 = any key starting "Q3_" (mitigation, true=safe). Q2 ignored (severity).
    """
    checked = 0
    inconsistencies = []
    if not scan_dir:
        return {"checked": 0, "inconsistencies": inconsistencies}
    workers_dir = os.path.join(scan_dir, "workers")
    verdict_files = []
    if os.path.isdir(workers_dir):
        for _root, _dirs, files in os.walk(workers_dir):
            for fn in files:
                if fn == "judge_verdict.json":
                    verdict_files.append(os.path.join(_root, fn))
    # also scan-level judge_verdict.json
    jv = os.path.join(scan_dir, "judge_verdict.json")
    if os.path.isfile(jv):
        verdict_files.append(jv)
    for vf in verdict_files:
        try:
            with open(vf) as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError):
            continue
        verdicts = data.get("verdicts") if isinstance(data, dict) else data
        if not isinstance(verdicts, list):
            continue
        for v in verdicts:
            if not isinstance(v, dict):
                continue
            jm = v.get("judgment_matrix") or {}
            conclusion = str(v.get("conclusion") or v.get("verdict") or "").upper()
            q1 = _qval(jm, "Q1_")  # defect (true=danger)
            q3 = _qval(jm, "Q3_")  # mitigation (true=safe)
            if q1 is None or q3 is None:
                continue  # no Q-matrix to check (rule may lack one — skip)
            checked += 1
            consistent = _qmatrix_consistent(conclusion, q1, q3)
            if not consistent:
                inconsistencies.append({
                    "file": vf, "rule": data.get("rule") if isinstance(data, dict) else None,
                    "hypothesis": v.get("hypothesis_id"),
                    "conclusion": conclusion, "Q1_defect": q1, "Q3_mitigation": q3,
                    "reason": "conclusion contradicts Q1/Q3 (F7 polarity)",
                })
    return {"checked": checked, "inconsistencies": inconsistencies}


def _qval(jm, prefix):
    """Return the bool value of the first judgment_matrix key with prefix, or None."""
    for k, val in jm.items():
        if str(k).startswith(prefix):
            return bool(val)
    return None


def _qmatrix_consistent(conclusion, q1, q3):
    """Q1=true defect, Q3=true mitigation. CONFIRMED needs Q1 & !Q3; SUPPRESS needs !Q1 | Q3."""
    if conclusion == "CONFIRMED":
        return q1 and not q3
    if conclusion in ("SUPPRESS", "SAFE"):
        return (not q1) or q3
    # SUSPICIOUS / unknown — not a hard contradiction, treat as consistent
    return True


def self_test():
    import tempfile
    idx = {"files": ["src/app.c"],
           "symbols": {"functions": [{"file": "src/app.c", "start_line": 10, "end_line": 20}]}}
    scan = tempfile.mkdtemp()
    batch = os.path.join(scan, "workers", "r", "batch-001")
    os.makedirs(batch)
    for name in ("hypotheses.json", "evidence.json", "counter_evidence.json"):
        with open(os.path.join(batch, name), "w") as out:
            json.dump({"signal_id": "s1"}, out)
    with open(os.path.join(batch, "judge_verdict.json"), "w") as out:
        json.dump({"verdicts": [{"signal_id": "s1", "file": "src/app.c", "line": 15,
                   "verdict": "CONFIRMED", "judgment_matrix": {"Q1_defect": True, "Q3_mitigated": False}}]}, out)
    # confirmed: valid anchor + canonical severity + complete provenance
    f_ok = {"sha": "aaa", "file": "src/app.c", "line": 15, "severity": "High", "detector": "x", "cwe": "CWE-120",
            "rule_id": "r", "batch_id": "batch-001", "signal_id": "s1"}
    # needs_review: file not in index
    f_badfile = dict(f_ok, sha="bbb", file="other.c", line=1)
    # needs_review: non-canonical severity (bypassed recorder)
    f_badsev = dict(f_ok, sha="ccc", line=12, severity="blocker")
    res = evaluate(idx, [f_ok, f_badfile, f_badsev], scan)
    assert res["confirmed"] == 1, res
    assert res["needs_review"] == 2, res
    assert res["findings"]["aaa"]["verdict"] == "confirmed", res["findings"]["aaa"]
    assert res["findings"]["aaa"]["checks"]["artifacts"] == "pass", res["findings"]["aaa"]
    assert res["findings"]["bbb"]["checks"]["anchor"] == "fail", res["findings"]["bbb"]
    assert res["findings"]["ccc"]["checks"]["severity"] == "fail", res["findings"]["ccc"]
    # signatures are stable
    assert len(res["findings"]["aaa"]["signature"]) == 16, res
    # Q-matrix consistency audit (F7)
    import tempfile
    qm_dir = tempfile.mkdtemp()
    wd = os.path.join(qm_dir, "workers", "memory_buffer_overflow")
    os.makedirs(wd)
    # inconsistent: CONFIRMED but Q1=false (no defect) → contradiction
    # consistent: CONFIRMED with Q1=true,Q3=false
    # inconsistent: SUPPRESS with Q1=true,Q3=false (should be CONFIRMED)
    # consistent: SUPPRESS with Q1=false
    import json as _j
    _j.dump({"rule": "buffer_overflow", "verdicts": [
        {"hypothesis_id": "H1", "verdict": "CONFIRMED",
         "judgment_matrix": {"Q1_buffer_too_small": False, "Q2_external_input": True, "Q3_bounds_check_exists": False, "conclusion": "CONFIRMED"}},
        {"hypothesis_id": "H2", "verdict": "CONFIRMED",
         "judgment_matrix": {"Q1_buffer_too_small": True, "Q2_external_input": True, "Q3_bounds_check_exists": False, "conclusion": "CONFIRMED"}},
        {"hypothesis_id": "H3", "verdict": "SAFE",
         "judgment_matrix": {"Q1_buffer_too_small": True, "Q2_external_input": False, "Q3_bounds_check_exists": False, "conclusion": "SUPPRESS"}},
        {"hypothesis_id": "H4", "verdict": "SAFE",
         "judgment_matrix": {"Q1_buffer_too_small": False, "Q2_external_input": False, "Q3_bounds_check_exists": True, "conclusion": "SUPPRESS"}},
    ]}, open(os.path.join(wd, "judge_verdict.json"), "w"))
    qm = audit_qmatrix(qm_dir)
    assert qm["checked"] == 4, qm
    assert qm["inconsistencies"] and len(qm["inconsistencies"]) == 2, qm  # H1 + H3 inconsistent
    print("OK — verification-gate self-test passed (anchor/severity/signature + Q-matrix)")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Per-finding semantic gate (F3 structural fix)")
    ap.add_argument("--index", help="index.json")
    ap.add_argument("--scan-dir", help="scan output directory")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--rule-id", help="scope validation to one pilot rule")
    ap.add_argument("--batch-id", help="scope validation to one pilot batch")
    ap.add_argument("--plan", help="partition plan for per-signal artifact coverage")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if not args.index or not args.scan_dir:
        ap.error("--index and --scan-dir are required (or use --self-test)")

    if bool(args.rule_id) != bool(args.batch_id):
        ap.error("--rule-id and --batch-id must be used together")
    if args.rule_id:
        result = audit_batch(args.scan_dir, args.rule_id, args.batch_id, args.plan)
        print(json.dumps(result, indent=2) if args.json else
              "Pilot gate: %s (%s/%s)" % (result["verdict"], args.rule_id, args.batch_id))
        return 0 if result["verdict"] == "PASSED" else 1

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
    # A structurally unverified finding makes the scan incomplete. Fail closed;
    # the renderer must never turn this partial set into an authoritative report.
    return 1 if result["needs_review"] > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
