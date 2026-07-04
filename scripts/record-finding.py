#!/usr/bin/env python3
"""SecGuardian — Record a single finding (AI Agent helper)

Usage:
    python3 scripts/record-finding.py \\
        --scan-dir .codeagent/secguardian/secguard/scans/<scan-id> \\
        --detector web.sql-injection \\
        --severity Critical --cwe CWE-89 \\
        --file src/UserController.java --line 52

Output: findings/<ns>/<detector>/<sha12>_<file>-<line>.json
Prints: RECORDED: findings/<ns>/<det>/<fname>.json (severity, CWE)
"""

import argparse, json, os, hashlib, sys

def main():
    p = argparse.ArgumentParser(description='Record a single security finding')
    p.add_argument('--scan-dir', required=True)
    p.add_argument('--detector', required=True)
    p.add_argument('--severity', required=True, choices=['Critical','High','Medium','Low','Info'])
    p.add_argument('--cwe', required=True)
    p.add_argument('--file', required=True)
    p.add_argument('--line', required=True, type=int)
    p.add_argument('--function', default='')
    p.add_argument('--title', default='')
    p.add_argument('--snippet', default='')
    p.add_argument('--rationale', default='')
    p.add_argument('--attack-scenario', default='')
    p.add_argument('--cvss', type=float, default=0.0)
    p.add_argument('--fix-before', default='')
    p.add_argument('--fix-after', default='')
    args = p.parse_args()

    # Compute finding ID
    raw = f"{args.detector}:{args.file}:{args.line}:{args.cwe}"
    sha = hashlib.sha256(raw.encode()).hexdigest()[:12]
    slug = os.path.splitext(os.path.basename(args.file))[0]
    fname = f"{sha}_{slug}-{args.line}.json"
    ns, det = args.detector.split('.', 1)
    dpath = os.path.join(args.scan_dir, 'findings', ns, det)
    os.makedirs(dpath, exist_ok=True)

    finding = {
        "schema_version": "1.0",
        "finding": {
            "severity": args.severity, "cwe": args.cwe,
            "detector": args.detector, "file": args.file,
            "line": args.line, "function": args.function or None,
            "title": args.title,
            "location": {"file_path": args.file, "start_line": args.line,
                        "function_name": args.function or None, "snippet": args.snippet},
            "evidence": {"code_context": args.snippet,
                        "judgment_rationale": args.rationale},
            "impact": {"attack_scenario": args.attack_scenario,
                      "cvss_score": args.cvss},
            "fix": {"description": args.title,
                   "before_code": args.fix_before,
                   "after_code": args.fix_after}
        }
    }
    fpath = os.path.join(dpath, fname)
    with open(fpath, 'w') as f:
        json.dump(finding, f, indent=2)

    print(f"RECORDED: findings/{ns}/{det}/{fname} ({args.severity}, {args.cwe})")
    return 0

if __name__ == '__main__':
    sys.exit(main())
