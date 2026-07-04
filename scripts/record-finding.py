#!/usr/bin/env python3
"""SecGuardian — Record a single finding (AI Agent helper)

Usage:
    python3 scripts/record-finding.py \
        --scan-dir .codeagent/secguardian/secguard/scans/<scan-id> \
        --detector web.sql-injection \
        --severity Critical --cwe CWE-89 \
        --file src/UserController.java --line 52 \
        --function searchUser \
        --snippet "..." \
        --fix-before "..." --fix-after "..."

Outputs: finding JSON file to findings/<ns>/<detector>/<sha12>_<file>-<line>.json
Prints: finding ID and path to stdout
"""

import argparse, json, os, hashlib, sys

def main():
    parser = argparse.ArgumentParser(description='Record a single security finding')
    parser.add_argument('--scan-dir', required=True, help='Scan output directory')
    parser.add_argument('--detector', required=True, help='Namespace.name (e.g. web.sql-injection)')
    parser.add_argument('--severity', required=True, choices=['Critical','High','Medium','Low','Info'])
    parser.add_argument('--cwe', required=True, help='CWE identifier (e.g. CWE-89)')
    parser.add_argument('--file', required=True, help='Source file path')
    parser.add_argument('--line', required=True, type=int, help='Line number')
    parser.add_argument('--function', default='', help='Function name')
    parser.add_argument('--title', default='', help='Finding title')
    parser.add_argument('--snippet', default='', help='Code snippet')
    parser.add_argument('--rationale', default='', help='Judgment rationale')
    parser.add_argument('--attack-scenario', default='', help='Attack scenario')
    parser.add_argument('--cvss', type=float, default=0.0, help='CVSS score')
    parser.add_argument('--fix-before', default='', help='Before code')
    parser.add_argument('--fix-after', default='', help='After code')
    
    args = parser.parse_args()
    
    # Compute finding ID
    raw = f"{args.detector}:{args.file}:{args.line}:{args.cwe}"
    sha = hashlib.sha256(raw.encode()).hexdigest()[:12]
    file_slug = os.path.splitext(os.path.basename(args.file))[0]
    fname = f"{sha}_{file_slug}-{args.line}.json"
    
    ns, det = args.detector.split('.', 1)
    findings_dir = os.path.join(args.scan_dir, 'findings', ns, det)
    os.makedirs(findings_dir, exist_ok=True)
    
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
                "function_name": args.function or None,
                "snippet": args.snippet
            },
            "evidence": {
                "code_context": args.snippet,
                "judgment_rationale": args.rationale
            },
            "impact": {
                "attack_scenario": args.attack_scenario,
                "cvss_score": args.cvss
            },
            "fix": {
                "description": args.title,
                "before_code": args.fix_before,
                "after_code": args.fix_after
            }
        }
    }
    
    fpath = os.path.join(findings_dir, fname)
    with open(fpath, 'w') as f:
        json.dump(finding, f, indent=2)
    
    rel_path = f"findings/{ns}/{det}/{fname}"
    print(f"RECORDED: {rel_path} ({args.severity}, CWE-{args.cwe.split('-')[1]})")
    return 0

if __name__ == '__main__':
    sys.exit(main())
