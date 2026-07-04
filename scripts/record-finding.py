#!/usr/bin/env python3
"""SecGuardian — Record a single finding (AI Agent helper)
Supports secguard, secaudit, and secreview command schemas.

Usage:
    # secguard — basic fields
    python3 record-finding.py --command secguard --detector web.sql-injection ...

    # secaudit — +data-flow-path, +secaudit_specific
    python3 record-finding.py --command secaudit --detector audit.input-validation \
        --data-flow-path "..." --skill-name input-validation ...

    # secreview — +secreview_specific
    python3 record-finding.py --command secreview --detector web.sql-injection \
        --review-pass vulnerability_detection \
        --review-focus input-validation,injection-prevention ...

Output: findings/<ns>/<detector>/<sha12>_<file>-<line>.json
Prints: RECORDED: findings/<ns>/<det>/<fname>.json (severity, CWE)
"""

import argparse, json, os, hashlib, sys


def clean_none(obj):
    """Remove keys with None value from dicts/lists recursively."""
    if isinstance(obj, dict):
        return {k: clean_none(v) for k, v in obj.items() if v is not None}
    if isinstance(obj, list):
        return [clean_none(v) for v in obj]
    return obj


def main():
    p = argparse.ArgumentParser(
        description='Record a single security finding (secguard/secaudit/secreview)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''Examples:
  secguard:  --command secguard  --detector web.sql-injection --severity Critical --cwe CWE-89 --file src/a.py --line 42
  secaudit:  --command secaudit  --detector audit.cryptography --severity High --cwe CWE-327 --file src/crypto.py --line 15 --skill-name cryptography
  secreview: --command secreview --detector memory.buffer-overflow --severity High --cwe CWE-120 --file src/buf.c --line 88 --review-pass vulnerability_detection
        ''')

    # Core required fields
    p.add_argument('--command', default='',
                   choices=['secguard', 'secaudit', 'secreview'],
                   help='[logging only] Command type identifier')
    p.add_argument('--scan-dir', required=True,
                   help='Scan output directory (parent of findings/)')
    p.add_argument('--detector', required=True,
                   help='Detector name (e.g. web.sql-injection, audit.cryptography)')
    p.add_argument('--severity', required=True,
                   choices=['Critical', 'High', 'Medium', 'Low', 'Info'])
    p.add_argument('--cwe', required=True, help='CWE ID, e.g. CWE-89')
    p.add_argument('--file', required=True, help='Source file path')
    p.add_argument('--line', required=True, type=int, help='Line number')

    # Optional common fields
    p.add_argument('--end-line', type=int, default=None,
                   help='End line (for location.end_line)')
    p.add_argument('--function', default='', help='Function name')
    p.add_argument('--title', default='', help='Finding title / fix description')
    p.add_argument('--snippet', default='', help='Code snippet')
    p.add_argument('--code-context', default='',
                   help='Code context (defaults to --snippet value)')
    p.add_argument('--rationale', default='', help='Judgment rationale')
    p.add_argument('--attack-scenario', default='',
                   help='Attack scenario description')
    p.add_argument('--cvss', type=float, default=0.0,
                   help='CVSS score (0.0-10.0)')
    p.add_argument('--fix-before', default='', help='Vulnerable code')
    p.add_argument('--fix-after', default='', help='Fixed code')

    # secaudit-specific
    p.add_argument('--data-flow-path', default='',
                   help='[secaudit] Source -> Propagation -> Sink path')
    p.add_argument('--skill-name', default='',
                   help='[secaudit] Audit skill name (e.g. input-validation)')
    p.add_argument('--skill-category', default='',
                   help='[secaudit] Skill category (e.g. domain)')
    p.add_argument('--analysis-paths', type=int, default=0,
                   help='[secaudit] Number of analysis paths')
    p.add_argument('--complete-chains', type=int, default=0,
                   help='[secaudit] Number of complete data-flow chains')

    # secreview-specific
    p.add_argument('--review-pass', default='',
                   help='[secreview] Review pass name')
    p.add_argument('--review-focus', default='',
                   help='[secreview] Comma-separated review focus areas')

    args = p.parse_args()

    # ── Compute finding ID ──────────────────────
    raw = f"{args.detector}:{args.file}:{args.line}:{args.cwe}"
    sha = hashlib.sha256(raw.encode()).hexdigest()[:12]
    slug = os.path.splitext(os.path.basename(args.file))[0]
    fname = f"{sha}_{slug}-{args.line}.json"
    det_parts = args.detector.split('.', 1)
    ns_name = det_parts[0]
    det_name = det_parts[1] if len(det_parts) > 1 else ''

    # ── Build output path ──────────────────────
    dpath = os.path.join(args.scan_dir, 'findings', ns_name, det_name)
    os.makedirs(dpath, exist_ok=True)

    # ── Build finding dict ──────────────────────
    code_ctx = args.code_context or args.snippet

    finding = {
        "schema_version": "1.0",
        "finding": {
            "severity": args.severity,
            "cwe": args.cwe,
            "detector": args.detector,
            "file": args.file,
            "line": args.line,
            "function": args.function or None,
            "title": args.title,
            "location": {
                "file_path": args.file,
                "start_line": args.line,
                "end_line": args.end_line,
                "function_name": args.function or None,
                "snippet": args.snippet
            },
            "evidence": {
                "code_context": code_ctx or None,
                "judgment_rationale": args.rationale or None
            },
            "impact": {
                "attack_scenario": args.attack_scenario or None,
                "cvss_score": args.cvss or None
            },
            "fix": {
                "description": args.title,
                "before_code": args.fix_before,
                "after_code": args.fix_after
            }
        }
    }

    # ── secaudit: evidence.data_flow_path + secaudit_specific ─
    if args.data_flow_path:
        finding["finding"]["evidence"]["data_flow_path"] = args.data_flow_path
    secaudit_specific = {}
    if args.skill_name:
        secaudit_specific["skill_name"] = args.skill_name
    if args.skill_category:
        secaudit_specific["skill_category"] = args.skill_category
    if args.analysis_paths:
        secaudit_specific["analysis_paths"] = args.analysis_paths
    if args.complete_chains:
        secaudit_specific["complete_chains"] = args.complete_chains
    if secaudit_specific:
        finding["finding"]["secaudit_specific"] = secaudit_specific

    # ── secreview: secreview_specific ──────────────────────
    if args.review_pass:
        focus_list = (
            [x.strip() for x in args.review_focus.split(',') if x.strip()]
            if args.review_focus else []
        )
        finding["finding"]["secreview_specific"] = {
            "review_pass": args.review_pass,
            "review_focus": focus_list
        }

    # ── Write file ──────────────────────────────────
    finding = clean_none(finding)
    fpath = os.path.join(dpath, fname)
    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(finding, f, indent=2, ensure_ascii=False)

    print(
        f"RECORDED: findings/{ns_name}/{det_name}/{fname} "
        f"({args.severity}, {args.cwe})"
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
