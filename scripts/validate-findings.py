#!/usr/bin/env python3
"""
前置工件验证脚本。

在调用渲染器之前执行。验证 findings 是否包含所有必需字段，并可选的检测规约交叉验证。

用法:
  python3 scripts/validate-findings.py --findings-dir <path>
  python3 scripts/validate-findings.py --findings-dir <path> --check-spec
"""
import argparse, json, os, sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED_ROOT_FIELDS = ['severity', 'detector', 'file', 'line', 'cwe']
REQUIRED_SEVERITIES = {'Critical', 'High', 'Medium', 'Low', 'Info'}
REQUIRED_LOCATION = ['file_path', 'start_line', 'snippet']
REQUIRED_EVIDENCE = ['code_context', 'judgment_rationale']
REQUIRED_IMPACT = ['attack_scenario']
REQUIRED_FIX = []  # fix optional (basic scan)
OPTIONAL_FIX = ['description', 'effort', 'effort_hours']

VALID_DETECTOR_PATTERN = 'namespace.name'  # Must contain a dot


def validate_finding(f, filepath):
    """Validate a single finding. Returns list of error messages."""
    errors = []

    for field in REQUIRED_ROOT_FIELDS:
        if field not in f or f[field] is None or (isinstance(f[field], str) and not f[field].strip()):
            errors.append(f"  ❌ missing root field: {field}")

    sev = f.get('severity')
    if sev and sev not in REQUIRED_SEVERITIES:
        errors.append(f"  ❌ invalid severity '{sev}' (must be Critical/High/Medium/Low/Info)")

    det = f.get('detector', '')
    if det and '.' not in det:
        errors.append(f"  ❌ detector '{det}' must contain a dot (use namespace.name format)")

    loc = f.get('location')
    if not isinstance(loc, dict):
        errors.append(f"  ❌ missing or invalid: location (must be a dict)")
    else:
        for field in REQUIRED_LOCATION:
            if field not in loc or not loc[field]:
                errors.append(f"  ❌ missing location.{field}")

    ev = f.get('evidence')
    if not isinstance(ev, dict):
        errors.append(f"  ❌ missing or invalid: evidence (must be a dict)")
    else:
        for field in REQUIRED_EVIDENCE:
            if field not in ev or not ev[field]:
                errors.append(f"  ❌ missing evidence.{field}")

    imp = f.get('impact')
    if not isinstance(imp, dict):
        errors.append(f"  ❌ missing or invalid: impact (must be a dict)")
    else:
        for field in REQUIRED_IMPACT:
            if field not in imp or not imp[field]:
                errors.append(f"  ❌ missing impact.{field}")

    fi = f.get('fix')
    if not isinstance(fi, dict):
        errors.append(f"  ❌ missing or invalid: fix (must be a dict)")
    else:
        for field in REQUIRED_FIX:
            if field not in fi or not fi[field]:
                errors.append(f"  ❌ missing fix.{field}")

    return errors


def parse_frontmatter_yaml(content: str) -> dict:
    """Parse simple YAML frontmatter (---...---) into a dict.
    Handles inline arrays [a, b, c] and scalar values. No YAML dependency needed.
    """
    if not content.startswith('---\n'):
        return {}
    lines = content.split('\n')
    end = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i
            break
    if end < 0:
        return {}
    data = {}
    for line in lines[1:end]:
        line = line.strip()
        if not line or ':' not in line:
            continue
        key, _, val = line.partition(':')
        key = key.strip()
        val = val.strip()
        if not key:
            continue
        if val.startswith('[') and val.endswith(']'):
            inner = val[1:-1]
            items = [x.strip().strip('"\'') for x in inner.split(',') if x.strip()]
            data[key] = items
        else:
            data[key] = val
    return data


def list_findings(findings_dir):
    """Print a human-readable summary table of all findings."""
    rows = []
    for root, dirs, files in sorted(os.walk(findings_dir)):
        for fname in sorted(files):
            if not fname.endswith('.json'):
                continue
            try:
                with open(os.path.join(root, fname)) as f:
                    data = json.load(f)
                finding = data.get('finding') if isinstance(data, dict) and 'finding' in data else data
                if not isinstance(finding, dict):
                    continue
                rows.append((
                    finding.get('severity', '?'),
                    finding.get('cwe', '?'),
                    finding.get('file', '?'),
                    finding.get('line', '?'),
                    finding.get('title', '?')
                ))
            except (json.JSONDecodeError, OSError):
                continue

    if not rows:
        print("  (no findings)")
        return

    # Align columns
    for sev, cwe, file, line, title in rows:
        sev_pad = sev.rjust(8)
        cwe_str = f"CWE-{cwe}" if cwe and not str(cwe).startswith('CWE-') else str(cwe)
        print(f"  {sev_pad} | {cwe_str} | {file}:{line} | {title}")
    print(f"\n  Total: {len(rows)} finding(s)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--findings-dir', required=True)
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument("--list", action="store_true",
                        help='Print a human-readable findings table summary after validation')
    args, _ = parser.parse_known_args()

    if not os.path.isdir(args.findings_dir):
        print(f"FATAL: findings directory not found: {args.findings_dir}")
        sys.exit(1)


    total_errors = 0
    total_findings = 0
    spec_errors = 0

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

            finding = data.get('finding') if isinstance(data, dict) and 'finding' in data else data
            if not isinstance(finding, dict) or 'detector' not in finding:
                print(f"  ❌ {filepath}: not a valid finding (missing 'finding' wrapper or 'detector' field)")
                total_errors += 1
                continue

            total_findings += 1
            struct_errors = validate_finding(finding, filepath)

            spec_mismatches = []

            if struct_errors or spec_mismatches:
                if not args.quiet:
                    lines = []
                    if struct_errors:
                        lines.append(f"  ❌ {finding.get('detector', 'unknown')}:")
                        lines.extend(struct_errors)
                    if spec_mismatches:
                        lines.append(f"  ❌ [SPEC] {finding.get('detector', 'unknown')}:")
                        for e in spec_mismatches:
                            lines.append(f'    {e.strip()}')
                    print('\n'.join(lines))
                total_errors += len(struct_errors) + len(spec_mismatches)
                spec_errors += len(spec_mismatches)

    parts = [f"{total_findings} finding(s)"]
    if total_errors:
        parts.append(f"{total_errors} validation error(s)")
    if spec_errors:
        parts.append(f"{spec_errors} spec violation(s)")

    if args.show_list:
        print(f"\n=== Findings list ===")
        list_findings(args.findings_dir)

    if total_errors > 0:
        print(f"\n❌ {', '.join(parts)}")
        print("   Fix the findings before calling the renderer.")
        sys.exit(1)
    else:
        print(f"✅ {', '.join(parts)}")
        sys.exit(0)


if __name__ == '__main__':
    main()
