#!/usr/bin/env python3
"""
SecGuardian Report Rendering Engine v1.0

Takes AI-generated findings.json + index.json and generates all 6 output files:
  report.md, results.sarif, summary.json, manifest.json, status.json, delta.json

Zero external dependencies — stdlib only.
Part of the SecGuardian Performance Refactoring (CodePlan: hashed-juggling-sutherland).

Usage:
  python3 render-report.py \\
    --findings .codeagent/<ns>/scans/<id>/findings.json \\
    --index .codeagent/<ns>/scans/<id>/index.json \\
    --output .codeagent/<ns>/scans/<id>/

CI mode:
  python3 render-report.py --ci \\
    --findings findings.json --index index.json --output ./output/   # v4.0 legacy
    --findings-dir findings/ --index index.json --output ./output/  # v5.0 directory tree

Copyright 2026 SecGuardian. Apache 2.0.
"""

import argparse
import json
import math
import os
import sys
import hashlib
import datetime
from string import Template
from collections import Counter, defaultdict

# ── Constants ───────────────────────────────────

def load_detector_index_from_files(detectors_dir=None):
    """Build detector -> {index, cwe} mapping from knowledge/guard-rules/*.md files.

    Dynamically reads detector files to avoid hardcoding the DETECTOR_RULE_INDEX.
    Falls back to builtin DETECTOR_RULE_INDEX_FALLBACK if files are unavailable.
    """
    if detectors_dir is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        detectors_dir = os.path.join(script_dir, "..", "knowledge", "guard-rules")

    if not os.path.isdir(detectors_dir):
        return None  # caller should use fallback

    index = {}
    detector_files = sorted(f for f in os.listdir(detectors_dir) if f.endswith('.md'))

    for i, fname in enumerate(detector_files):
        # Convert filename: memory-null-dereference.md -> memory.null-dereference
        name = fname[:-3]
        parts = name.split('-', 1)
        detector_name = f"{parts[0]}.{parts[1]}" if len(parts) == 2 else name

        # Parse CWE from file frontmatter
        cwe_list = []
        filepath = os.path.join(detectors_dir, fname)
        try:
            with open(filepath) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('cwe:') or line.startswith('CWE:'):
                        cwe_list = [c.strip() for c in line.split(':', 1)[1].split(',')
                                    if c.strip().startswith('CWE-')]
                        break
                    if line == '---' and cwe_list:
                        break  # past frontmatter
        except Exception:
            pass

        if not cwe_list:
            cwe_list = ["CWE-000"]

        index[detector_name] = {"index": i, "cwe": cwe_list}

    return index if index else None

# Try dynamic loading, fall back to builtin
_DYNAMIC_INDEX = load_detector_index_from_files()

if _DYNAMIC_INDEX:
    DETECTOR_RULE_INDEX = _DYNAMIC_INDEX
else:
    DETECTOR_RULE_INDEX = {
    "system.command-injection":        {"index": 0,  "cwe": ["CWE-77", "CWE-94"]},
    "web.sql-injection":               {"index": 1,  "cwe": ["CWE-89"]},
    "crypto.hardcoded-secrets":        {"index": 2,  "cwe": ["CWE-798"]},
    "crypto.weak-crypto-algorithm":    {"index": 3,  "cwe": ["CWE-327"]},
    "crypto.insufficient-key-length":  {"index": 4,  "cwe": ["CWE-326"]},
    "web.ssrf":                        {"index": 5,  "cwe": ["CWE-918"]},
    "system.path-traversal":           {"index": 6,  "cwe": ["CWE-22"]},
    "web.xss":                         {"index": 7,  "cwe": ["CWE-79"]},
    "web.jwt-misuse":                  {"index": 8,  "cwe": ["CWE-347"]},
    "web.csrf":                        {"index": 9,  "cwe": ["CWE-352"]},
    "web.auth-bypass":                 {"index": 10, "cwe": ["CWE-287"]},
    "web.idor":                        {"index": 11, "cwe": ["CWE-639"]},
    "web.xxe":                         {"index": 12, "cwe": ["CWE-611"]},
    "web.input-validation":            {"index": 13, "cwe": ["CWE-20"]},
    "web.unrestricted-upload":         {"index": 14, "cwe": ["CWE-434"]},
    "web.missing-authorization":       {"index": 15, "cwe": ["CWE-862"]},
    "web.missing-authentication":      {"index": 16, "cwe": ["CWE-306"]},
    "web.open-redirect":               {"index": 17, "cwe": ["CWE-601"]},
    "web.resource-exhaustion":         {"index": 18, "cwe": ["CWE-400"]},
    "web.ssti":                        {"index": 19, "cwe": ["CWE-1336"]},
    "web.nosql-injection":             {"index": 20, "cwe": ["CWE-943"]},
    "web.code-injection":              {"index": 21, "cwe": ["CWE-94"]},
    "web.deserialization":             {"index": 22, "cwe": ["CWE-502"]},
    "web.excessive-data-exposure":     {"index": 23, "cwe": ["CWE-200"]},
    "web.mass-assignment":             {"index": 24, "cwe": ["CWE-915"]},
    "web.prototype-pollution":         {"index": 25, "cwe": ["CWE-1321"]},
    "crypto.password-storage":         {"index": 26, "cwe": ["CWE-256"]},
    "crypto.weak-random":              {"index": 27, "cwe": ["CWE-338"]},
    "crypto.custom-crypto":            {"index": 28, "cwe": ["CWE-327"]},
    "crypto.tls-version":              {"index": 29, "cwe": ["CWE-326"]},
    "crypto.aes-ecb-mode":             {"index": 30, "cwe": ["CWE-327"]},
    "crypto.hardcoded-iv":             {"index": 31, "cwe": ["CWE-329"]},
    "concurrency.data-race":           {"index": 32, "cwe": ["CWE-362"]},
    "concurrency.deadlock":            {"index": 33, "cwe": ["CWE-833"]},
    "concurrency.race-condition":      {"index": 34, "cwe": ["CWE-362"]},
    "concurrency.thread-unsafe-signal": {"index": 35, "cwe": ["CWE-364"]},
    "resource.file-leak":              {"index": 36, "cwe": ["CWE-404"]},
    "resource.socket-leak":            {"index": 37, "cwe": ["CWE-404"]},
    "resource.memory-leak":            {"index": 38, "cwe": ["CWE-401"]},
    "resource.lock-misuse":            {"index": 39, "cwe": ["CWE-667"]},
    "resource.file-double-close":      {"index": 40, "cwe": ["CWE-675"]},
    "resource.file-use-after-close":    {"index": 41, "cwe": ["CWE-416"]},
    "resource.refcount-misuse":        {"index": 42, "cwe": ["CWE-911"]},
    "error.debug-mode-production":     {"index": 43, "cwe": ["CWE-489"]},
    "error.exception-swallow":         {"index": 44, "cwe": ["CWE-390"]},
    "error.log-sensitive-data":        {"index": 45, "cwe": ["CWE-532"]},
    "error.panic-to-client":           {"index": 46, "cwe": ["CWE-209"]},
    "error.stack-trace-leak":          {"index": 47, "cwe": ["CWE-209"]},
    "error.unified-error-format":      {"index": 48, "cwe": ["CWE-209"]},
    "memory.buffer-overflow":          {"index": 49, "cwe": ["CWE-120"]},
    "memory.heap-buffer-overflow":     {"index": 50, "cwe": ["CWE-122"]},
    "memory.use-after-free":           {"index": 51, "cwe": ["CWE-416"]},
    "memory.double-free":              {"index": 52, "cwe": ["CWE-415"]},
    "memory.null-dereference":         {"index": 53, "cwe": ["CWE-476"]},
    "memory.memory-leak":              {"index": 54, "cwe": ["CWE-401"]},
    "memory.integer-overflow":         {"index": 55, "cwe": ["CWE-190"]},
    "memory.format-string":            {"index": 56, "cwe": ["CWE-134"]},
    "memory.off-by-one":               {"index": 57, "cwe": ["CWE-193"]},
    "memory.oob-read":                 {"index": 58, "cwe": ["CWE-125"]},
    "memory.uninitialized-memory":     {"index": 59, "cwe": ["CWE-457"]},
    "memory.bad-cast":                 {"index": 60, "cwe": ["CWE-704"]},
    "memory.mismatched-free":          {"index": 61, "cwe": ["CWE-762"]},
    "system.insecure-permissions":     {"index": 62, "cwe": ["CWE-732"]},
    "system.insecure-temp-file":       {"index": 63, "cwe": ["CWE-377"]},
    "system.privilege-escalation":     {"index": 64, "cwe": ["CWE-269"]},
    "system.secrets-detection":        {"index": 65, "cwe": ["CWE-798"]},
    "system.symlink-attack":           {"index": 66, "cwe": ["CWE-61"]},
    "system.toctou":                   {"index": 67, "cwe": ["CWE-367"]},
}  # DETECTOR_RULE_INDEX_FALLBACK — used only when detector files unavailable

# ── Helpers ─────────────────────────────────────

def load_json(path):
    """Load and return JSON file. Exit with message on failure."""
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {path}: {e}", file=sys.stderr)
        sys.exit(1)

def safe_len(obj):
    """安全获取长度: None -> 0, list -> len(list)"""
    return len(obj) if isinstance(obj, (list, dict, str)) else 0

def calc_score(findings):
    """Calculate security score from findings list.
    
    Uses exponential decay formula to avoid bottoming out at 0:
    score = 100 * exp(-0.2*Crit - 0.1*High - 0.04*Med - 0.01*Low)
    
    This preserves granularity even for high-severity scans:
    - 0 findings     → 100
    - 1 Crit         → ~82
    - 3 Crit + 5 High → ~47
    - 9 Crit + 5 High + 3 Med → ~26
    - 15 Crit        → ~5
    """
    weights = {"Critical": 0.2, "High": 0.1, "Medium": 0.04, "Low": 0.01, "Info": 0}
    penalty = sum(weights.get(f["severity"], 0) for f in findings)
    return max(0, round(100 * math.exp(-penalty)))

def calc_grade(score):
    if score >= 80: return "A"
    if score >= 55: return "B"
    if score >= 35: return "C"
    if score >= 15: return "D"
    return "F"

def _ensure_fields(f):
    """Normalize finding fields: fill in defaults for all renderer-required fields.

    Different command types (secguard/secaudit/secreview) produce findings with
    different field structures. This function ensures the renderer never crashes
    with KeyError regardless of what fields the agent includes.
    """
    # Root-level required fields with fallbacks
    if not f.get('file'):
        loc = f.get('location', {})
        f['file'] = loc.get('file_path', 'unknown') if isinstance(loc, dict) else 'unknown'
    if not f.get('line') and f.get('line') != 0:
        loc = f.get('location', {})
        f['line'] = loc.get('start_line', 0) if isinstance(loc, dict) else 0
    f.setdefault('severity', 'Medium')
    f.setdefault('cwe', 'CWE-000')
    f.setdefault('detector', 'unknown')
    f.setdefault('title', f.get('fix_summary', 'Security Finding'))
    f.setdefault('function', (f.get('location') or {}).get('function_name', 'N/A'))

    # Nested field defaults
    ev = f.setdefault('evidence', {})
    ev.setdefault('judgment_rationale', 'N/A')
    ev.setdefault('code_context', 'N/A')

    imp = f.setdefault('impact', {})
    imp.setdefault('attack_scenario', 'N/A')
    if imp.get('cvss_score') is None:
        imp['cvss_score'] = 0.0

    fi = f.setdefault('fix', {})
    fi.setdefault('before_code', 'N/A')
    fi.setdefault('after_code', 'N/A')
    # 别名映射: 兼容 agent 可能使用的非标准字段名
    loc = f.get('location')
    if isinstance(loc, dict):
        if 'file' in loc and 'file_path' not in loc:
            loc['file_path'] = loc['file']
        if 'code_snippet' in loc and 'snippet' not in loc:
            loc['snippet'] = loc['code_snippet']
    ev = f.get('evidence')
    if isinstance(ev, dict):
        pass  # evidence names are standard
    fi = f.get('fix')
    if isinstance(fi, dict):
        if 'code_before' in fi and 'before_code' not in fi:
            fi['before_code'] = fi['code_before']
        if 'code_after' in fi and 'after_code' not in fi:
            fi['after_code'] = fi['code_after']
    fi.setdefault('description', f.get('fix_summary', 'N/A'))

    return f

def severity_emoji(severity):
    return {"Critical": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🔵", "Info": "⚪"}.get(severity, "⚪")

def fingerprint(finding):
    """Generate SARIF partialFingerprints.primary."""
    raw = f"{finding['file']}:{finding['line']}:{finding['detector']}"
    return hashlib.sha256(raw.encode()).hexdigest()

def indent(text, spaces=4):
    """Indent multi-line text by spaces."""
    prefix = " " * spaces
    return "\n".join(prefix + line if line.strip() else "" for line in text.split("\n"))

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load_findings_from_tree(findings_dir):
    """Load all finding files from a v5.0 directory tree.

    Walks findings/<namespace>/<detector>/<finding-id>.json
    Returns list of finding dicts (same format as v4.0 findings.json['findings']).
    """
    findings = []
    if not os.path.isdir(findings_dir):
        print(f"ERROR: Findings directory not found: {findings_dir}", file=sys.stderr)
        sys.exit(1)
    for root, dirs, files in sorted(os.walk(findings_dir)):
        for fname in sorted(files):
            if fname.endswith('.json'):
                filepath = os.path.join(root, fname)
                try:
                    with open(filepath) as f:
                        data = json.load(f)
                except (json.JSONDecodeError, FileNotFoundError) as e:
                    print(f"WARNING: Skipping invalid finding file {filepath}: {e}", file=sys.stderr)
                    continue
                # Support {"finding": {...}} wrapper (v5.0) and bare Finding object
                if isinstance(data, dict) and 'finding' in data:
                    findings.append(_ensure_fields(data['finding']))
                elif isinstance(data, dict) and 'id' in data:
                    findings.append(_ensure_fields(data))
                else:
                    print(f"WARNING: Skipping {filepath} — missing 'finding' wrapper or 'id' field", file=sys.stderr)
    return findings

# ── Quality Gate (secaudit Step 4b) ─────────────

def validate_finding_4segment(f, max_retries=0):
    """
    Validate a single finding against the 4-segment protocol.
    Returns (is_valid, missing_fields).
    """
    missing = []

    # 1. Location
    loc = f.get("location", {})
    if not loc.get("file_path"): missing.append("location.file_path")
    if not loc.get("start_line"): missing.append("location.start_line")
    # 4-segment standard accepts "function" as alias, null is OK
    if not loc.get("snippet"): missing.append("location.snippet")

    # 2. Evidence
    ev = f.get("evidence", {})
    if not ev.get("code_context"): missing.append("evidence.code_context")
    if not ev.get("judgment_rationale"): missing.append("evidence.judgment_rationale")

    # 3. Impact
    imp = f.get("impact", {})
    if not imp.get("attack_scenario"): missing.append("impact.attack_scenario")
    if imp.get("cvss_score") is None: missing.append("impact.cvss_score")

    # 4. Fix
    fi = f.get("fix", {})
    # fix.description is optional — use fix_summary instead
    if not fi.get("before_code"): missing.append("fix.before_code")
    if not fi.get("after_code"): missing.append("fix.after_code")

    return len(missing) == 0, missing

def quality_gate_report(findings):
    """
    Run quality gate on all findings. Returns (passed, report_lines).
    - passed: True if all findings complete
    - report_lines: list of issue descriptions
    """
    issues = []
    for f in findings:
        ok, missing = validate_finding_4segment(f)
        if not ok:
            issues.append(f"  ❌ {f.get('_seq', 0)}: missing {', '.join(missing)}")

    if issues:
        header = [f"### ⚠️ Quality Gate: {len(issues)} finding(s) incomplete", ""]
        return False, header + issues
    return True, ["### ✅ Quality Gate: all findings complete ✓", ""]

# ── Report Generators ───────────────────────────

def generate_report_md(findings_data):
    """Generate complete report.md content."""
    findings = findings_data.get("findings", [])
    cmd = findings_data["command"]
    score = calc_score(findings)
    grade = calc_grade(score)

    by_sev = Counter(f["severity"] for f in findings)
    scope = findings_data.get("scope", {})
    detectors = findings_data.get("detectors", {})
    lang = findings_data.get("language", "unknown")
    good = findings_data.get("good_patterns", [])

    # Report header
    start = findings_data.get("started_at", "unknown")
    lines = []
    cmd_title = {"secguard": "Security Scan", "secaudit": "Security Audit", "secreview": "Security Review"}

    lines.append(f"# SecGuardian {cmd_title.get(cmd, 'Security')} Report\n")
    lines.append(f"> **Scan ID**: `{findings_data['scan_id']}` | **Language**: {lang} | **Date**: {start[:10]}")
    lines.append(f"> **Path**: `{findings_data.get('path', '')}` | **Mode**: {findings_data.get('mode', 'full')}")
    lines.append(f"> **Duration**: {findings_data.get('duration_ms', 0)}ms\n")
    lines.append("---\n")

    # §1 Scan Metadata (simplified)
    lines.append("## §1 Scan Metadata\n")
    if scope:
        duration_ms = findings_data.get('duration_ms', 0)
        lines.extend([
            f"| Files scanned | {scope.get('files', 'N/A')} |",
            f"| Lines scanned | {scope.get('lines', 'N/A')} |",
            f"| Functions analyzed | {scope.get('functions', 'N/A')} |",
            f"| Detectors executed | {detectors.get('executed', 'N/A')} |",
            f"| Scan duration | {duration_ms}ms |",
        ])
    lines.append('')

    # §2 Findings Inventory
    lines.append("---\n")
    lines.append("## §2 Findings Inventory\n")
    by_file = defaultdict(list)
    for f in findings:
        by_file[f["file"]].append(f)
    for filepath in sorted(by_file.keys()):
        file_findings = by_file[filepath]
        plural = "s" if len(file_findings) > 1 else ""
        lines.append(f"### {filepath} ({len(file_findings)} finding{plural})\n")
        lines.append("| # | Severity | CWE | Detector | Line | Fix |")
        lines.append("|-----------|----------|-----|----------|------|-----|")
        for f in file_findings:
            sev_emoji = severity_emoji(f["severity"])
            lines.append(f"| #{f.get('_seq', 0)} | {sev_emoji} {f['severity']} | {f['cwe']} | {f['detector']} | {f['line']} | {f.get('fix_summary', f['title'])} |")
        lines.append("")

    # §3 Detailed Findings
    lines.append("---\n")
    lines.append("## §3 Detailed Findings\n")
    groups = defaultdict(list)
    for f in findings:
        groups[f["detector"]].append(f)

    group_num = 0
    for detector in sorted(groups.keys()):
        group_num += 1
        lines.append(f"### §3.{group_num} {detector}\n")
        for f in groups[detector]:
            sev_emoji = severity_emoji(f["severity"])
            loc = f.get("location", {})
            ev = f.get("evidence", {})
            imp = f.get("impact", {})
            fix = f.get("fix", {})

            lines.append(f"#### {sev_emoji} #{f.get('_seq', 0)} — {f['title']}\n")
        lines.append(f"| Field | Detail |")
        lines.append(f"|-------|--------|")
        lines.append(f"| **Severity** | {sev_emoji} {f['severity']} |")
        lines.append(f"| **CWE** | [{f['cwe']}](https://cwe.mitre.org/data/definitions/{f['cwe'].replace('CWE-','')}.html) |")
        lines.append(f"| **Detector** | `{f['detector']}` |")
        lines.append(f"| **File** | `{loc.get('file_path', f['file'])}:{loc.get('start_line', f['line'])}` |")
        lines.append(f"| **Function** | `{loc.get('function_name', f.get('function', 'N/A'))}` |")
        lines.append("")

        # 📍 Location
        lines.append("##### 📍 Location\n")
        snippet = loc.get("snippet", "")
        if snippet:
            lines.append("```" + lang)
            lines.append(snippet)
            lines.append("```\n")

        # 📋 Evidence
        lines.append("##### 📋 Evidence\n")
        lines.append(f"**Code Context:**\n```{lang}\n{ev.get('code_context', 'N/A')}\n```\n")
        lines.append(f"**Judgment:** {ev.get('judgment_rationale', 'N/A')}\n")

        data_flow = ev.get("data_flow_path", [])
        if data_flow:
            lines.append("**Data Flow Path:**")
            # data_flow_path 可以是：
            #   1) [{"step":"source","file":"a.c","line":1,"description":"d"}, ...]  (v4 协议 dict 列表)
            #   2) "malloc → buf → return → leak"  (v5 协议简化字符串)
            if isinstance(data_flow, str):
                lines.append(f"  {data_flow}")
                lines.append("")
                continue
            for step in data_flow:
                if isinstance(step, str):
                    lines.append(f"  {step}")
                    continue
                step_label = {"source": "SOURCE", "propagation": "→ PROPAGATION", "sink": "→ SINK"}
                prefix = step_label.get(step.get("step", ""), "  ")
                lines.append(f"  {prefix}: {step.get('file','')}:{step.get('line','')} — {step.get('description','')}")
            lines.append("")

        # ⚠️ Impact
        lines.append("##### ⚠️ Impact\n")
        lines.append(f"**Attack Scenario:** {imp.get('attack_scenario', 'N/A')}\n")
        cvss = imp.get("cvss_score")
        if cvss is not None:
            lines.append(f"**CVSS 3.1 Score:** {cvss}/10")
            vec = imp.get("cvss_vector", "")
            if vec:
                lines.append(f"**CVSS Vector:** `{vec}`")
        lines.append(f"**Exploit Conditions:** {imp.get('exploit_conditions', 'N/A')}\n")

        # 🔧 Fix
        lines.append("##### 🔧 Fix\n")
        lines.append(f"{fix.get('description', 'N/A')}\n")
        lines.append("**Before:**\n```" + lang)
        lines.append(fix.get("before_code", "N/A"))
        lines.append("```\n")
        lines.append("**After:**\n```" + lang)
        lines.append(fix.get("after_code", "N/A"))
        lines.append("```\n")

        effort = fix.get("effort_hours")
        if effort is not None:
            lines.append(f"**Estimated Effort:** {effort} hours | **Verification:** {fix.get('verification_method', 'N/A')}\n")

        lines.append("---\n")

    # §4 Remediation Roadmap
    lines.append("## §4 Remediation Roadmap\n")

    phases = {"Critical": ("🔴 Immediate (Block Deploy)", []),
              "High": ("🟠 This Sprint", []),
              "Medium": ("🟡 Next Sprint", []),
              "Low": ("🔵 Backlog", []),
              "Info": ("⚪ Future Consideration", [])}

    for f in findings:
        phases[f["severity"]][1].append(f)

    for sev, (label, items) in phases.items():
        if items:
            lines.append(f"### Phase: {label}\n")
            for item in items:
                lines.append(f"- **#{item.get('_seq', 0)}** — {item.get('fix_summary', item['title'])}")
            lines.append("")

    # §5 Appendix
    lines.append("---\n")
    lines.append("## §5 Appendix\n")

    if good:
        lines.append("### Good Patterns Found\n")
        lines.append("| Pattern | Location | Description |")
        lines.append("|---------|----------|-------------|")
        for gp in good:
            lines.append(f"| `{gp['name']}` | `{gp['file']}:{gp['line']}` | {gp['description']} |")
        lines.append("")

    lines.append("### Detector Coverage\n")
    lines.append(f"- Matched: {detectors.get('matched', 'N/A')}")
    lines.append(f"- Executed: {detectors.get('executed', 'N/A')}")
    if detectors.get("namespaces_used"):
        lines.append(f"- Namespaces: {', '.join(detectors['namespaces_used'])}")
    lines.append("")

    commit = findings_data.get("git_commit", "unknown")
    lines.append(f"\n*Report generated by SecGuardian Renderer v1.0 | Scan ID: {findings_data['scan_id']} | Commit: {commit}*\n")

    return "\n".join(lines)

def generate_sarif(findings_data):
    """Generate SARIF 2.1.0 JSON from findings."""
    findings = findings_data.get("findings", [])
    scan_id = findings_data["scan_id"]
    cmd = findings_data["command"]

    tool_name = {"secguard": "SecGuardian secguard", "secaudit": "SecGuardian secaudit", "secreview": "SecGuardian secreview"}

    # Build rules from detectors used
    used_detectors = set(f["detector"] for f in findings)
    rules = []
    for det in sorted(used_detectors):
        info = DETECTOR_RULE_INDEX.get(det, {"cwe": ["CWE-000"]})
        # Handle both dotted ("audit.x") and bare ("attack-surface") detector names
        det_parts = det.split(".")
        det_name = det_parts[1] if len(det_parts) > 1 else det_parts[0]
        rules.append({
            "id": det,
            "name": "".join(part.capitalize() for part in det_name.split("-")),
            "shortDescription": {"text": f"Security finding: {det}"},
            "helpUri": f"https://cwe.mitre.org/data/definitions/{info['cwe'][0].replace('CWE-','')}.html",
            "properties": {"cwe": info["cwe"]}
        })

    results = []
    for f in findings:
        loc = f.get("location", {})
        ev = f.get("evidence", {})
        imp = f.get("impact", {})
        fix = f.get("fix", {})
        sarif = f.get("sarif_specific", {})

        # Build message.text (one-line)
        msg_text = (f"📍 {f['file']}:{f['line']} {f.get('function', '')} "
                    f"[{f['severity']}] {f['cwe']}: {f['title']}")

        # Build message.markdown (full 4-segment)
        msg_md_parts = []
        if loc.get("snippet"):
            msg_md_parts.append(f"### 📍 Location\n```\n{loc['snippet']}\n```")
        if ev.get("judgment_rationale"):
            msg_md_parts.append(f"### 📋 Evidence\n{ev['judgment_rationale']}")
        if imp.get("attack_scenario"):
            msg_md_parts.append(f"### ⚠️ Impact\n{imp['attack_scenario']}\nCVSS: {imp.get('cvss_score', 'N/A')}/10")
        if fix.get("description"):
            msg_md_parts.append(f"### 🔧 Fix\n{fix['description']}")
        msg_md = "\n\n".join(msg_md_parts)

        # Build relatedLocations (data flow)
        related = []
        data_flow = ev.get("data_flow_path", [])
        if isinstance(data_flow, str):
            related.append({
                "physicalLocation": {"artifactLocation": {"uri": f["file"]}},
                "message": {"text": data_flow}
            })
        else:
            for step in data_flow:
                if isinstance(step, str):
                    related.append({
                        "physicalLocation": {"artifactLocation": {"uri": f["file"]}},
                        "message": {"text": step}
                    })
                    continue
                related.append({
                    "physicalLocation": {
                    "artifactLocation": {"uri": step["file"]},
                    "region": {"startLine": step["line"]}
                },
                "message": {"text": step.get("description", step["step"])}
            })

        # Build fixes
        fixes = []
        if fix.get("before_code") and fix.get("after_code"):
            fixes.append({
                "description": {"text": fix.get("description", "Apply security fix")},
                "fileChanges": [{
                    "artifactLocation": {"uri": f["file"]},
                    "replacements": [{
                        "deletedRegion": {"startLine": loc.get("start_line", f["line"]),
                                         "endLine": loc.get("end_line", f["line"])},
                        "insertedContent": {"text": fix["after_code"]}
                    }]
                }]
            })

        result = {
            "ruleId": f["detector"],
            "ruleIndex": DETECTOR_RULE_INDEX.get(f["detector"], {}).get("index", 0),
            "level": "error" if f["severity"] in ("Critical", "High") else "warning" if f["severity"] == "Medium" else "note",
            "message": {
                "text": msg_text,
                "markdown": msg_md
            },
            "locations": [{
                "physicalLocation": {
                    "artifactLocation": {"uri": f["file"]},
                    "region": {"startLine": loc.get("start_line", f["line"]),
                              "endLine": loc.get("end_line", f["line"])}
                }
            }],
            "partialFingerprints": {"primary": fingerprint(f)},
            "properties": {
                "findingId": f.get("_sha", ""),
                "seq": f.get("_seq", 0),
                "severity": f["severity"],
                "cwe": f["cwe"],
                "confidence": sarif.get("confidence", "medium"),
                "cvss": imp.get("cvss_score", 0),
                "impact": imp.get("attack_scenario", "")[:200],
                "effort": fix.get("effort_hours", 0),
                "risk_of_fix": sarif.get("risk_of_fix", "low"),
                "verification": fix.get("verification_method", ""),
                "detector_namespace": sarif.get("detector_namespace", f["detector"])
            }
        }

        if related:
            result["relatedLocations"] = related
        if fixes:
            result["fixes"] = fixes

        results.append(result)

    return {
        "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {
                "driver": {
                    "name": tool_name.get(cmd, "SecGuardian"),
                    "version": "3.0",
                    "informationUri": "https://github.com/secguardian/secguardian",
                    "rules": rules
                }
            },
            "results": results,
            "invocations": [{
                "startTimeUtc": findings_data.get("started_at", now_iso()),
                "endTimeUtc": findings_data.get("completed_at", now_iso()),
                "executionSuccessful": True
            }]
        }]
    }

def _load_verification_files(output_dir):
    """Load dismissed.json and verification-audit.json if they exist (v6.0+)."""
    dismissed_path = os.path.join(output_dir, "dismissed.json")
    audit_path = os.path.join(output_dir, "verification-audit.json")
    dismissed = None
    audit = None
    if os.path.isfile(dismissed_path):
        dismissed = load_json(dismissed_path)
    if os.path.isfile(audit_path):
        audit = load_json(audit_path)
    return dismissed, audit

def generate_summary(findings_data):
    """Generate summary.json."""
    findings = findings_data.get("findings", [])
    by_sev = Counter(f["severity"] for f in findings)
    by_detector = Counter(f["detector"] for f in findings)
    by_file = Counter(f["file"] for f in findings)
    scope = findings_data.get("scope", {})
    detectors = findings_data.get("detectors", {})
    score = calc_score(findings)
    output_dir = findings_data.get("_output_dir", "")

    summary = {
        "scan_id": findings_data["scan_id"],
        "command": findings_data["command"],
        "path": findings_data.get("path", ""),
        "mode": findings_data.get("mode", "full"),
        "language": findings_data.get("language", "unknown"),
        "timing": {
            "started": findings_data.get("started_at", ""),
            "completed": findings_data.get("completed_at", ""),
            "duration_ms": findings_data.get("duration_ms", 0)
        },
        "scope": scope,
        "findings_by_severity": {k: by_sev.get(k, 0) for k in ["Critical", "High", "Medium", "Low", "Info"]},
        "total_findings": len(findings),
        "findings_by_category": dict(by_detector.most_common()),
        "files_with_issues": {k: v for k, v in by_file.most_common()},
        "detectors_matched": detectors.get("matched", 0),
        "detectors_executed": detectors.get("executed", 0),
        "security_score": score,
        "score_max": 100,
        "score_grade": calc_grade(score),
        "renderer_version": "1.1"
    }

    # v6.0: add verification data if available
    dismissed, _ = _load_verification_files(output_dir)
    if dismissed:
        summary["verification"] = {
            "dismissed_total": dismissed["summary"]["dismissed_by_p1"]
                             + dismissed["summary"]["dismissed_by_p2"]
                             + dismissed["summary"]["dismissed_by_p3"],
            "certified": dismissed["summary"]["certified"],
            "dismissed_by_round": {
                "p1_semantic": dismissed["summary"]["dismissed_by_p1"],
                "p2_counter_evidence": dismissed["summary"]["dismissed_by_p2"],
                "p3_court": dismissed["summary"]["dismissed_by_p3"]
            }
        }

    return summary

def generate_manifest(findings_data):
    """Generate manifest.json."""
    findings = findings_data.get("findings", [])
    detectors = findings_data.get("detectors", {})

    return {
        "scan_id": findings_data["scan_id"],
        "protocol_version": "2.0",
        "renderer_version": "1.0",
        "created": findings_data.get("completed_at", now_iso()),
        "duration_ms": findings_data.get("duration_ms", 0),
        "path": findings_data.get("path", ""),
        "mode": findings_data.get("mode", "full"),
        "filters": findings_data.get("filters", ["all"]),
        "language": findings_data.get("language", "unknown"),
        "command": findings_data["command"],
        "detectors": detectors,
        "scope": findings_data.get("scope", {}),
        "findings": [
            {
                "seq": f.get("_seq", 0),
                "sha": f.get("_sha", ""),
                "severity": f["severity"],
                "cwe": f["cwe"],
                "detector": f["detector"],
                "file": f["file"],
                "line": f["line"]
            }
            for f in findings
        ]
    }

def generate_status(findings_data, ci_mode=False):
    """Generate status.json with CI gate criteria. v6.0: supports confidence-weighted scoring."""
    findings = findings_data.get("findings", [])
    by_sev = Counter(f["severity"] for f in findings)
    score = calc_score(findings)

    crit = by_sev.get("Critical", 0)
    high = by_sev.get("High", 0)
    medium = by_sev.get("Medium", 0)

    gate_criteria = {"max_critical": 0, "max_high": 0, "max_medium": 5}
    violations = []
    if crit > 0: violations.append(f"{crit} Critical findings (threshold: 0)")
    if high > 0: violations.append(f"{high} High findings (threshold: 0)")
    if medium > gate_criteria["max_medium"]: violations.append(f"{medium} Medium findings (threshold: {gate_criteria['max_medium']})")

    passed = len(violations) == 0

    result = {
        "scan_id": findings_data["scan_id"],
        "status": "completed",
        "gate_result": "PASSED" if passed else "FAILED",
        "gate_criteria": gate_criteria,
        "gate_violations": violations,
        "security_score": score,
        "grade": calc_grade(score),
        "exit_code": 0 if passed else 1,
        "recommendation": ("Ready for deployment" if passed else
                          "Immediate remediation required — fix all Critical and High findings before deployment")
    }

    # v6.0: add verification summary if available
    output_dir = findings_data.get("_output_dir", "")
    dismissed, _ = _load_verification_files(output_dir)
    if dismissed:
        total = dismissed["summary"]["total_findings"]
        cert = dismissed["summary"]["certified"]
        result["verification"] = {
            "findings_total": total,
            "certified": cert,
            "dismissed": total - cert,
            "convergence_rate": f"{(total - cert) / total * 100:.0f}%" if total > 0 else "N/A"
        }

    return result

def generate_delta(findings_data, output_dir):
    """Generate delta.json comparing with previous scan (if latest symlink exists)."""
    latest_link = os.path.join(os.path.dirname(output_dir.rstrip('/')), "latest")
    prev = None
    if os.path.islink(latest_link):
        prev_dir = os.path.realpath(latest_link)
        prev_manifest = os.path.join(prev_dir, "manifest.json")
        if os.path.isfile(prev_manifest):
            prev = load_json(prev_manifest)

    current_findings = findings_data.get("findings", [])

    if prev and "findings" in prev:
        prev_ids = {f.get("sha", f.get("_sha", "")) for f in prev["findings"]}
        curr_ids = {f.get("_sha", f.get("sha", "")) for f in current_findings}

        new_ids = curr_ids - prev_ids
        fixed_ids = prev_ids - curr_ids
        still_open = curr_ids & prev_ids

        return {
            "scan_id": findings_data["scan_id"],
            "previous_scan_id": prev.get("scan_id", "unknown"),
            "comparison": {
                "new_findings": len(new_ids),
                "fixed_findings": len(fixed_ids),
                "still_open": len(still_open),
                "total_current": len(current_findings),
                "total_previous": len(prev["findings"])
            },
            "new_finding_ids": sorted(new_ids),  # SHA prefixes
            "fixed_finding_ids": sorted(fixed_ids)  # SHA prefixes
        }
    else:
        return {
            "scan_id": findings_data["scan_id"],
            "comparison": {
                "note": "First scan — no previous data for delta comparison",
                "total_current": len(current_findings)
            }
        }

def render_executive_summary(findings_data, output_dir):
    """Generate human/executive-summary.md — unified entry point.
    
    One page with: score, severity breakdown, detector×file cross-table,
    risk concentration (file×count), Top-3 Critical, navigation guide.
    """

    import os
    
    findings = findings_data.get("findings", [])
    if not findings:
        return
    
    score = findings_data.get("security_score", 0)
    grade = findings_data.get("score_grade", "F")
    scan_id = findings_data.get("scan_id", "N/A")
    path_val = findings_data.get("path", "N/A")
    language = findings_data.get("language", "N/A")
    scope = findings_data.get("scope", {}) or {}
    
    # Calculate severity distribution from raw findings

    sev_count = Counter(f.get("severity", "Info") for f in findings)
    total = len(findings)
    
    # Calculate score if not present (same formula as calc_score)
    if score == 0 and total > 0:
        c = sev_count.get("Critical", 0)
        h = sev_count.get("High", 0)
        m = sev_count.get("Medium", 0)
        l = sev_count.get("Low", 0)
        score = max(0, min(100, 100 - (c * 25 + h * 10 + m * 3 + l * 1)))
        if score >= 90: grade = "A"
        elif score >= 75: grade = "B"
        elif score >= 60: grade = "C"
        elif score >= 40: grade = "D"
        else: grade = "F"
    
    # Detector cross-table: detector → set(file)
    detector_files = {}
    detector_count = Counter()
    for f in findings:
        det = f.get("detector", "unknown")
        detector_files.setdefault(det, set()).add(f.get("file", ""))
        detector_count[det] += 1
    
    # Risk concentration: file → count
    file_count = Counter(f.get("file", "") for f in findings)
    total_findings = len(findings)
    
    # Top-3 Critical/High
    def severity_sort_key(f):
        order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
        return order.get(f.get("severity", "Info"), 99)
    sorted_findings = sorted(findings, key=severity_sort_key)
    top3 = sorted_findings[:3]
    
    # Severity emoji
    sev_emoji = {"Critical": "🔴", "High": "🟠", "Medium": "🟡", "Low": "🔵", "Info": "⚪"}
    
    lines = [
        "# SecGuardian 安全扫描精要",
        "",
        f"> **扫描**: `{scan_id}` | **项目**: `{path_val}` | **语言**: {language}",
        "",
        "## 安全态势",
        "",
        "| 指标 | 值 |",
        "|------|-----|",
        f"| 安全评分 | **{score}/100 — {grade}** |",
        f"| 扫描文件 | {scope.get('files', 0)} 个文件 |",
        f"| 总发现数 | {total} |",
        "",
        "### 严重度分布",
        "",
        "| 严重度 | 数量 |",
        "|--------|------|",
    ]
    for s in ["Critical", "High", "Medium", "Low"]:
        emoji = sev_emoji.get(s, "")
        count = sev_count.get(s, 0)
        if count > 0:
            lines.append(f"| {emoji} {s} | {count} |")
    
    # Detector cross-table (Top-5)
    if len(detector_files) > 1:
        lines.extend(["", "### 发现分布（检测器 × 文件，Top-5）", "",
                       "| 检测器 | 发现数 | 涉及文件 |",
                       "|--------|--------|---------|"])
        sorted_dets = sorted(detector_files.items(),
                            key=lambda x: len(x[1]), reverse=True)[:5]
        for det, files in sorted_dets:
            lines.append(f"| `{det}` | {detector_count[det]} | {', '.join(sorted(files)[:3])}{'...' if len(files) > 3 else ''} |")
    
    # Risk concentration (Top-5)
    if len(file_count) > 1:
        lines.extend(["", "### 风险集中度（文件 × 发现数，Top-5）", "",
                       "| 文件 | 发现数 | 占比 |",
                       "|------|--------|------|"])
        top_files = sorted(file_count.items(), key=lambda x: -x[1])[:5]
        for filepath, count in top_files:
            pct = round(count / total_findings * 100) if total_findings > 0 else 0
            lines.append(f"| `{filepath}` | {count} | {pct}% |")
    
    # Top-3 Critical/High
    if top3:
        lines.extend(["", "### Top 3 风险", "",
                       "| # | 文件:行 | 严重度 | 标题 |",
                       "|----|---------|--------|------|"])
        for f in top3:
            sev_label = f.get("severity", "")
            emoji = sev_emoji.get(sev_label, "")
            finding_id = f"#{f.get('_seq', 0)}" 
            file_line = f"{f.get('file', '')}:{f.get('line', '')}"
            title = f.get("title", "")
            lines.append(f"| {finding_id} | `{file_line}` | {emoji} {sev_label} | {title} |")
    
    # Navigation guide
    lines.extend(["", "---", "",
                   "**下一步（按角色）：**", "",
                   "- 👨‍💻 工程师 → `report.md §3.x` 按检测器集中修复一类问题",
                   "- 📋 查看完整报告 → `report.md`",
                   "- 🤖 AI 自动修复 → `ai/remediation-pack.json`",
                   "- 👔 管理层查看 → `dashboard.html`",
                   ""])
    
    human_dir = os.path.join(output_dir, "human")
    os.makedirs(human_dir, exist_ok=True)
    out_path = os.path.join(human_dir, "executive-summary.md")
    with open(out_path, "w") as f:
        f.write("\n".join(lines))
    print(f"  ✓ human/executive-summary.md ({len(lines)} lines)")

def render_remediation_pack(findings, findings_meta, output_dir):
    """Generate ai/remediation-pack.json — AI-consumable remediation pack.
    
    findings: list of finding dicts
    findings_meta: dict with scan_id, command, etc.
    Each remediation entry includes root_cause, fix_strategy, before/after code,
    and related_findings (AI-tagged + auto-detected same function/file).
    """
    import os, json
    
    if not findings:
        return
    
    # Build (file, function) index
    func_index = defaultdict(list)
    for i, f in enumerate(findings):
        key = (f.get("file", ""), f.get("function", ""))
        func_index[key].append(i)
    
    remediations = []
    for i, f in enumerate(findings):
        finding_id = f"#{f.get('_seq', 0)}"
        
        # AI-tagged relationships
        related = []
        for rel in f.get("relationships", []):
            if isinstance(rel, dict):
                rid = rel.get("finding_id", "")
            else:
                rid = str(rel)
            if rid and rid not in related:
                related.append(rid)
        
        # Auto-detect: same function
        key = (f.get("file", ""), f.get("function", ""))
        for j in func_index.get(key, []):
            if j != i:
                rid = findings[j].get("id", "")
                if rid and rid not in related:
                    related.append(rid)
        
        rem = {
            "finding_id": f"#{f.get('_seq', 0)}",
            "title": f.get("title", ""),
            "severity": f.get("severity", ""),
            "cwe": f.get("cwe", ""),
            "detector": f.get("detector", ""),
            "affected_files": [f.get("file", "")],
            "root_cause": f.get("evidence", {}).get("judgment_rationale", ""),
            "fix_strategy": f.get("fix", {}).get("description", ""),
            "safe_patch_guidance": [],
            "before_code": f.get("fix", {}).get("before_code", ""),
            "after_code": f.get("fix", {}).get("after_code", ""),
            "effort_hours": f.get("fix", {}).get("effort_hours", 0),
            "verification": f.get("fix", {}).get("verification_method", ""),
            "related_findings": related[:10]
        }
        remediations.append(rem)
    
    pack = {
        "version": "1.0",
        "scan_id": findings_meta.get("scan_id", "N/A"),
        "remediations": remediations
    }
    
    ai_dir = os.path.join(output_dir, "ai")
    os.makedirs(ai_dir, exist_ok=True)
    out_path = os.path.join(ai_dir, "remediation-pack.json")
    with open(out_path, "w") as f:
        json.dump(pack, f, indent=2, ensure_ascii=False)
    print(f"  ✓ ai/remediation-pack.json ({len(remediations)} remediations)")

def render_dashboard(findings_data, output_dir):
    """Generate dashboard.html — management dashboard from executive-summary data.
    NOT a copy of report.md. Shows score, severity, risk concentration, top risks only.
    No code blocks, no evidence chains, no per-finding details.
    """
    import os

    findings = findings_data.get("findings", [])
    if not findings:
        return

    scope = findings_data.get("scope", {}) or {}
    scan_id = findings_data.get("scan_id", "N/A")
    path_val = findings_data.get("path", "N/A")
    language = findings_data.get("language", "N/A")
    duration_ms = findings_data.get("duration_ms", 0)
    detectors = findings_data.get("detectors", {})

    score = findings_data.get("security_score", 0)
    grade = findings_data.get("score_grade", "F")
    if score == 0 and findings:
        c = sum(1 for f in findings if f.get("severity") == "Critical")
        h = sum(1 for f in findings if f.get("severity") == "High")
        m = sum(1 for f in findings if f.get("severity") == "Medium")
        l = sum(1 for f in findings if f.get("severity") == "Low")
        score = max(0, min(100, 100 - (c*25 + h*10 + m*3 + l*1)))
        grade = "A" if score >= 90 else "B" if score >= 75 else "C" if score >= 60 else "D" if score >= 40 else "F"

    sev_emoji = {"Critical":"\U0001f534","High":"\U0001f7e0","Medium":"\U0001f7e1","Low":"\U0001f535","Info":"\u26aa"}

    def esc(t):
        if t is None: return ""
        return str(t).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

    sev_count = Counter(f.get("severity", "Info") for f in findings)

    # Detector x file cross-table
    det_files = {}
    for f in findings:
        d = f.get("detector", "unknown")
        det_files.setdefault(d, set()).add(f.get("file", ""))
    det_count = Counter(f.get("detector", "") for f in findings)

    # Risk concentration
    file_count = Counter(f.get("file", "") for f in findings)
    total = len(findings)

    # Top 3 critical
    top3 = sorted(findings, key=lambda x: {"Critical":0,"High":1}.get(x.get("severity",""), 9))[:3]

    css = """<style>
      *{box-sizing:border-box;margin:0;padding:0}
      body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
           background:#f5f7fa;color:#1a1a2e;padding:40px 20px}
      .card{background:#fff;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,.1);
            padding:24px;margin-bottom:20px;max-width:960px;margin-left:auto;margin-right:auto}
      h1{font-size:24px;color:#1d3557;margin-bottom:4px}
      .meta{color:#6c757d;font-size:14px;margin-bottom:20px}
      .score{text-align:center;padding:20px}
      .score-value{font-size:48px;font-weight:bold;color:#1d3557}
      .score-grade{font-size:20px;color:#6c757d}
      table{border-collapse:collapse;width:100%;margin:12px 0}
      th,td{border:1px solid #dee2e6;padding:8px 12px;text-align:left;font-size:14px}
      th{background:#f8f9fa;font-weight:600}
      tr:nth-child(even){background:#f8f9fa}
      .severity-critical{color:#e63946;font-weight:bold}
      .severity-high{color:#e76f51;font-weight:bold}
      h2{font-size:18px;color:#1d3557;margin:24px 0 12px;padding-bottom:6px;border-bottom:2px solid #e63946}
      .nav{display:flex;gap:12px;flex-wrap:wrap;margin-top:24px}
      .nav a{background:#1d3557;color:#fff;padding:8px 16px;border-radius:6px;
             text-decoration:none;font-size:14px;font-weight:500}
      .nav a:hover{background:#457b9d}
    </style>"""

    p = []
    p.append("<!DOCTYPE html><html><head><meta charset=UTF-8><title>SecGuardian Dashboard</title>" + css + "</head><body>")

    # Header
    p.append('<div class="card">')
    p.append("<h1>SecGuardian Security Dashboard</h1>")
    p.append(f'<p class="meta">Scan ID: {esc(scan_id)} | Project: {esc(path_val)} | Language: {esc(language)} | Duration: {duration_ms}ms</p>')
    p.append("</div>")

    # Score
    p.append('<div class="card"><div class="score">')
    p.append(f'<div class="score-value">{score}/100</div>')
    p.append(f'<div class="score-grade">Grade {esc(grade)}</div>')
    p.append("</div></div>")

    # Severity
    p.append('<div class="card"><h2>Severity Breakdown</h2><table>')
    p.append("<tr><th>Severity</th><th>Count</th></tr>")
    for s in ["Critical","High","Medium","Low"]:
        c = sev_count.get(s, 0)
        if c > 0:
            emoji = sev_emoji.get(s,"")
            cls = f"severity-{s.lower()}"
            p.append(f'<tr><td class="{cls}">{emoji} {s}</td><td>{c}</td></tr>')
    p.append("</table></div>")

    # Detector cross-table
    if len(det_files) > 1:
        p.append('<div class="card"><h2>Findings by Detector</h2><table>')
        p.append("<tr><th>Detector</th><th>Findings</th><th>Files</th></tr>")
        for d in sorted(det_files.keys(), key=lambda x: len(det_files[x]), reverse=True)[:5]:
            p.append(f"<tr><td>{esc(d)}</td><td>{det_count[d]}</td><td>{len(det_files[d])}</td></tr>")
        p.append("</table></div>")

    # Risk concentration
    if len(file_count) > 1:
        p.append('<div class="card"><h2>Risk Concentration (Top Files)</h2><table>')
        p.append("<tr><th>File</th><th>Findings</th><th>%</th></tr>")
        for fpath, cnt in sorted(file_count.items(), key=lambda x: -x[1])[:5]:
            pct = round(cnt / total * 100) if total > 0 else 0
            p.append(f"<tr><td><code>{esc(fpath)}</code></td><td>{cnt}</td><td>{pct}%</td></tr>")
        p.append("</table></div>")

    # Top 3
    if top3:
        p.append('<div class="card"><h2>Top Risks</h2><table>')
        p.append("<tr><th>ID</th><th>Severity</th><th>File</th><th>Title</th></tr>")
        for f in top3:
            sev = f.get("severity","")
            emoji = sev_emoji.get(sev,"")
            cls = f"severity-{sev.lower()}"
            p.append(f'<tr><td class="finding-id">{esc(f.get("id",""))}</td>'
                     f'<td class="{cls}">{emoji} {sev}</td>'
                     f'<td>{esc(f.get("file",""))}:{f.get("line","")}</td>'
                     f'<td>{esc(f.get("title",""))}</td></tr>')
        p.append("</table></div>")

    # Scan info
    p.append('<div class="card"><p class="meta">Generated by SecGuardian | Detectors: ' +
             f'{detectors.get("matched",0)} matched, {detectors.get("executed",0)} executed' +
             " | This dashboard shows only high-level metrics. For detailed findings, open report.md</p></div>")
    p.append("</body></html>")

    html = "".join(p)
    out_path = os.path.join(output_dir, "dashboard.html")
    with open(out_path, "w") as f:
        f.write(html)
    print(f"  \u2713 dashboard.html ({len(html)} bytes)")

# ── Main ────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="SecGuardian Report Rendering Engine v1.0",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --findings findings.json --index index.json --output ./output/
  %(prog)s --ci --findings findings.json --index index.json --output ./output/
  %(prog)s --format sarif --findings findings.json --output ./output/
        """
    )
    parser.add_argument("--findings", required=False, help="Path to findings.json (v4.0 monolithic, legacy)")
    parser.add_argument("--findings-dir",
                        help="Path to v5.0 findings/ directory tree (overrides --findings)")
    parser.add_argument("--index", help="Path to index.json (optional, for scope stats)")
    parser.add_argument("--output", required=True, help="Output directory for generated files")
    parser.add_argument("--ci", action="store_true", help="CI mode: set exit_code in status.json")
    parser.add_argument("--format", choices=["all", "report", "sarif", "summary", "manifest", "status", "delta"],
                        default="all", help="Generate only specific files (default: all)")
    parser.add_argument("--command",
                        help="Command name (secguard/secaudit/secreview). Overrides findings_data.")
    parser.add_argument("--quality-gate", action="store_true", default=True,
                        help="Run 4-segment quality gate validation (default: on)")
    parser.add_argument("--no-quality-gate", action="store_false", dest="quality_gate",
                        help="Skip quality gate validation")
    args = parser.parse_args()

    # Validate: at least one of --findings or --findings-dir must be provided
    if not args.findings and not args.findings_dir:
        print("ERROR: Either --findings (v4.0) or --findings-dir (v5.0) must be provided", file=sys.stderr)
        sys.exit(1)

    # Load findings — support v5.0 directory tree or v4.0 monolithic JSON
    if args.findings_dir:
        # v5.0: load from directory tree
        findings = load_findings_from_tree(args.findings_dir)
        findings_data = {
            "schema_version": "1.0",
            "scan_id": "unknown",
            "command": args.command or "secguard",
            "started_at": "",
            "completed_at": "",
            "findings": findings,
        }
        # Try to load scan metadata from findings.json (same name as v4.0, now lightweight index)
        index_path = os.path.join(args.output, "findings.json")
        if os.path.isfile(index_path):
            index_meta = load_json(index_path)
            for key in ["scan_id", "command", "started_at", "completed_at",
                         "duration_ms", "path", "mode", "filters", "language",
                         "scope", "detectors", ]:
                if key in index_meta and key not in ("findings_index", "summary"):
                    findings_data[key] = index_meta[key]
            if "scope" in index_meta and (not findings_data.get("scope") or findings_data["scope"].get("files", 0) == 0):
                findings_data["scope"] = index_meta["scope"]
        # --command always wins over what the AI or validate-findings wrote
        if args.command:
            findings_data["command"] = args.command
    else:
        # v4.0: load monolithic findings.json
        findings_data = load_json(args.findings)

    # Merge index.json scope if provided
    if args.index:
        index_data = load_json(args.index)
        if "scope" not in findings_data or not findings_data["scope"]:
            findings_data["scope"] = {
                "files": len(index_data.get("files", [])),
                "lines": 0,  # indexer doesn't count lines
                "functions": safe_len(index_data.get("symbols", {}).get("functions", [])),
                "call_edges": safe_len(index_data.get("call_graph", {}).get("edges", []))
            }

    # Ensure output dir
    os.makedirs(args.output, exist_ok=True)

    findings = findings_data.get("findings", [])

    # Sort findings: severity desc → file → line asc
    sev_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Info": 4}
    findings.sort(key=lambda f: (sev_order.get(f.get("severity", "Medium"), 5),
                                  f.get("file", ""),
                                  f.get("line", 0)))
    # Compute SHA identity and sequential number for each finding
    for i, f in enumerate(findings):
        identity = f"{f.get('detector','')}:{f.get('file','')}:{f.get('line',0)}:{f.get('cwe','')}"
        sha = hashlib.sha256(identity.encode()).hexdigest()[:12]
        f['_seq'] = i + 1
        f['_sha'] = sha

    # Quality gate (for secaudit)
    gate_warnings = []
    if args.quality_gate and findings_data["command"] == "secaudit":
        passed, gate_warnings = quality_gate_report(findings)
        if not passed:
            print(f"⚠️  Quality Gate: {len([w for w in gate_warnings if w.startswith('  ❌')])} findings incomplete")

    files_generated = []

    def write_json(filename, data):
        path = os.path.join(args.output, filename)
        with open(path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        files_generated.append(filename)
        print(f"  ✓ {filename}")

    # Generate requested files
    fmt = args.format

    if fmt in ("all", "report"):
        report = generate_report_md(findings_data)
        # Prepend quality gate warnings for secaudit
        if gate_warnings and findings_data["command"] == "secaudit":
            report = "\n".join(gate_warnings) + "\n\n" + report
        path = os.path.join(args.output, "report.md")
        with open(path, "w") as f:
            f.write(report)
        files_generated.append("report.md")
        print(f"  ✓ report.md ({len(report)} bytes)")

    if fmt in ("all", "report"):
        render_executive_summary(findings_data, args.output)
    if fmt in ("all", "report"):
        render_remediation_pack(findings, findings_data, args.output)

    if fmt in ("all", "report"):
        render_dashboard(findings_data, args.output)

    if fmt in ("all", "sarif"):
        sarif = generate_sarif(findings_data)
        write_json("results.sarif", sarif)

    if fmt in ("all", "summary"):
        summary = generate_summary(findings_data)
        write_json("summary.json", summary)

    if fmt in ("all", "manifest"):
        manifest = generate_manifest(findings_data)
        write_json("manifest.json", manifest)

    if fmt in ("all", "status"):
        status = generate_status(findings_data, ci_mode=args.ci)
        write_json("status.json", status)
        if args.ci and status["exit_code"] != 0:
            print(f"\n  ⚠️  CI Gate FAILED — exit code {status['exit_code']}")

    if fmt in ("all", "delta"):
        delta = generate_delta(findings_data, args.output)
        write_json("delta.json", delta)

    # Create latest symlink
    scans_dir = os.path.dirname(args.output.rstrip('/'))
    if scans_dir:
        latest_link = os.path.join(scans_dir, "latest")
        scan_dir_name = os.path.basename(args.output.rstrip('/'))
        if os.path.islink(latest_link) or not os.path.exists(latest_link):
            if os.path.islink(latest_link):
                os.unlink(latest_link)
            os.symlink(scan_dir_name, latest_link)
            print(f"  ✓ latest → {scan_dir_name}")

    print(f"\n✅ Generated {len(files_generated)} files in {args.output}")
    if gate_warnings and findings_data["command"] == "secaudit":
        print("⚠️  Quality gate warnings present — see report.md header for details")

    # ── Auto-generate findings.json (v5.0 findings-dir mode) ────
    # Eliminates AI needing to remember the findings.json schema.
    # Only runs in v5.0 mode (--findings-dir, not legacy --findings).
    if args.findings_dir and findings:
        findings_idx = []
        for idx, f in enumerate(findings, 1):
            det = f.get('detector', '')
            file_ = f.get('file', '')
            line = f.get('line', 0)
            cwe = f.get('cwe', '')
            raw = f"{det}:{file_}:{line}:{cwe}"
            sha = hashlib.sha256(raw.encode()).hexdigest()[:12]
            slug = os.path.splitext(os.path.basename(file_))[0]
            ns = det.split('.')[0]
            det_name = det.split('.', 1)[1] if '.' in det else ''
            findings_idx.append({
                "seq": idx, "sha": sha,
                "severity": f.get('severity', ''),
                "cwe": cwe, "detector": det,
                "file": file_, "line": line,
                "function": f.get('function', '') or '',
                "title": f.get('title', '') or '',
                "path": f"findings/{ns}/{det_name}/{sha}_{slug}-{line}.json"
            })
        index_meta = {
            "scan_id": findings_data.get("scan_id", "unknown"),
            "command": findings_data.get("command", args.command or "secguard"),
            "path": findings_data.get("path", ""),
            "mode": findings_data.get("mode", "full"),
            "language": findings_data.get("language", ""),
            "timing": {
                "started": findings_data.get("started_at", ""),
                "completed": findings_data.get("completed_at", ""),
                "duration_ms": findings_data.get("duration_ms", 0)
            },
            "scope": findings_data.get("scope", {}),
            "detectors": findings_data.get("detectors", {}),
            "findings_index": findings_idx
        }
        findings_json_path = os.path.join(args.output, "findings.json")
        with open(findings_json_path, 'w', encoding='utf-8') as fout:
            json.dump(index_meta, fout, indent=2, ensure_ascii=False)
        print(f"  \u2713 findings.json ({len(findings)} findings in index)")

if __name__ == "__main__":
    main()
