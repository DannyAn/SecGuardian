#!/usr/bin/env python3
"""
前置工件验证脚本。

在调用渲染器之前执行。验证 findings 是否包含所有必需字段。
若任一 finding 不完整，exit 1 并报告具体缺失字段。

用法: python3 scripts/validate-findings.py --findings-dir <path>
"""
import argparse, json, os, sys

REQUIRED_ROOT_FIELDS = ['id', 'severity', 'detector', 'file', 'line', 'cwe']
REQUIRED_SEVERITIES = {'Critical', 'High', 'Medium', 'Low', 'Info'}
REQUIRED_LOCATION = ['file_path', 'start_line', 'snippet']
REQUIRED_EVIDENCE = ['code_context', 'judgment_rationale']
REQUIRED_IMPACT = ['attack_scenario']
REQUIRED_FIX = ['before_code', 'after_code']
OPTIONAL_FIX = ['description', 'effort', 'effort_hours']

VALID_DETECTOR_PATTERN = 'namespace.name'  # Must contain a dot


def validate_finding(f, filepath):
    """Validate a single finding. Returns list of error messages."""
    errors = []

    # Root-level required fields
    for field in REQUIRED_ROOT_FIELDS:
        if field not in f or f[field] is None or (isinstance(f[field], str) and not f[field].strip()):
            errors.append(f"  ❌ missing root field: {field}")

    # Severity must be valid
    sev = f.get('severity')
    if sev and sev not in REQUIRED_SEVERITIES:
        errors.append(f"  ❌ invalid severity '{sev}' (must be Critical/High/Medium/Low/Info)")

    # Detector must contain a dot
    det = f.get('detector', '')
    if det and '.' not in det:
        errors.append(f"  ❌ detector '{det}' must contain a dot (use namespace.name format)")

    # Location
    loc = f.get('location')
    if not isinstance(loc, dict):
        errors.append(f"  ❌ missing or invalid: location (must be a dict)")
    else:
        for field in REQUIRED_LOCATION:
            if field not in loc or not loc[field]:
                errors.append(f"  ❌ missing location.{field}")

    # Evidence
    ev = f.get('evidence')
    if not isinstance(ev, dict):
        errors.append(f"  ❌ missing or invalid: evidence (must be a dict)")
    else:
        for field in REQUIRED_EVIDENCE:
            if field not in ev or not ev[field]:
                errors.append(f"  ❌ missing evidence.{field}")

    # Impact
    imp = f.get('impact')
    if not isinstance(imp, dict):
        errors.append(f"  ❌ missing or invalid: impact (must be a dict)")
    else:
        for field in REQUIRED_IMPACT:
            if field not in imp or not imp[field]:
                errors.append(f"  ❌ missing impact.{field}")

    # Fix
    fi = f.get('fix')
    if not isinstance(fi, dict):
        errors.append(f"  ❌ missing or invalid: fix (must be a dict)")
    else:
        for field in REQUIRED_FIX:
            if field not in fi or not fi[field]:
                errors.append(f"  ❌ missing fix.{field}")

    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--findings-dir', required=True)
    parser.add_argument('--quiet', action='store_true')
    args = parser.parse_args()

    if not os.path.isdir(args.findings_dir):
        print(f"FATAL: findings directory not found: {args.findings_dir}")
        sys.exit(1)

    total_errors = 0
    total_findings = 0

    for root, dirs, files in sorted(os.walk(args.findings_dir)):
        for fname in sorted(files):
            if not fname.endswith('.json'):
                continue
            filepath = os.path.join(root, fname)
            try:
                with open(filepath) as f:
                    data = json.load(f)
            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"  ❌ {filepath}: invalid JSON ({e})")
                total_errors += 1
                continue

            # Extract finding (support both wrapper and bare format)
            finding = data.get('finding') if isinstance(data, dict) and 'finding' in data else data

            if not isinstance(finding, dict) or 'id' not in finding:
                print(f"  ❌ {filepath}: not a valid finding (missing 'finding' wrapper or 'id' field)")
                total_errors += 1
                continue

            total_findings += 1
            errors = validate_finding(finding, filepath)
            if errors:
                if not args.quiet:
                    print(f"  ❌ {finding.get('id', 'unknown')}:")
                    for e in errors:
                        print(e)
                total_errors += len(errors)

    if total_errors > 0:
        print(f"\n❌ {total_errors} validation error(s) in {total_findings} finding(s)")
        print("   Fix the findings before calling the renderer.")
        sys.exit(1)
    else:
        print(f"✅ {total_findings} finding(s) fully validated, 0 errors")
        sys.exit(0)


if __name__ == '__main__':
    main()
