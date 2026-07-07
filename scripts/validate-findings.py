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
REQUIRED_FIX = ['before_code', 'after_code']
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


def check_spec(f, spec):
    """Cross-check a finding against its Detection Spec. Returns list of errors."""
    errors = []
    det = f.get('detector', '')
    spec_det = spec.get('detector', '')
    short_det = det.split('.')[-1] if '.' in det else det
    spec_short = spec_det.split('.')[-1] if '.' in spec_det else spec_det

    if short_det != spec_short:
        errors.append(f"  ❌ [SPEC] detector mismatch: finding='{det}' spec='{spec_det}'")
        return errors

    spec_severity = spec.get('severity')
    if spec_severity and f.get('severity'):
        # Frontmatter severity is lowercase (e.g., 'critical'); finding is capitalized (e.g., 'Critical')
        f_sev = f['severity'].lower()
        s_sev = str(spec_severity).lower()
        if f_sev != s_sev:
            errors.append(f"  ❌ [SPEC] severity mismatch: finding='{f['severity']}' spec='{spec_severity}' ({spec_det})")

    spec_cwe = spec.get('cwe')
    if spec_cwe and f.get('cwe'):
        f_cwes = [c.strip() for c in str(f['cwe']).replace('，', ',').split(',') if c.strip()]
        s_cwes = [c.strip() for c in str(spec_cwe).replace('，', ',').split(',') if c.strip()]

        def norm(c):
            c = c.upper()
            return c if c.startswith('CWE-') else f'CWE-{c}'

        f_norm = [norm(c) for c in f_cwes]
        s_norm = [norm(c) for c in s_cwes]
        if not any(fc == sc for fc in f_norm for sc in s_norm):
            errors.append(f"  ❌ [SPEC] CWE mismatch: finding='{f['cwe']}' spec='{spec_cwe}' ({spec_det})")

    for field in spec.get('required_evidence', []):
        ev = f.get('evidence', {})
        if field not in ev or not ev[field]:
            errors.append(f"  ❌ [SPEC] missing required evidence '{field}' ({spec_det})")

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


def load_specs_from_dir(rules_dir: str) -> dict:
    """Load Detection Specs from .md files by parsing YAML frontmatter.

    Works for guard-rules, audit-rules, and review-rules.
    Returns {detector: spec} dict indexed by full detector name.
    """
    specs = {}
    if not os.path.isdir(rules_dir):
        return specs

    dirname = os.path.basename(rules_dir)
    for fname in sorted(os.listdir(rules_dir)):
        if not fname.endswith('.md'):
            continue
        path = os.path.join(rules_dir, fname)
        try:
            with open(path, encoding='utf-8') as f:
                content = f.read()
        except (OSError, UnicodeDecodeError):
            continue

        fm = parse_frontmatter_yaml(content)
        if not fm:
            continue

        # Construct full detector name based on rule type
        detector = fm.get('detector', '')
        if dirname == 'guard-rules':
            # Filename convention: <namespace>-<detector>.md
            # Frontmatter has short detector name, construct full: <namespace>.<detector>
            namespace = fname.split('-')[0]
            full_det = f"{namespace}.{detector}" if detector else ''
        elif dirname == 'audit-rules':
            name = fm.get('name', '')
            full_det = f"domain.{name}" if name else ''
        elif dirname == 'review-rules':
            full_det = detector
        else:
            continue

        if not full_det:
            continue

        spec = {
            'detector': full_det,
            'severity': fm.get('severity', ''),
            'cwe': fm.get('cwe', ''),
            'required_evidence': fm.get('required_evidence', []),
        }
        specs[full_det] = spec
        short = full_det.split('.')[-1] if '.' in full_det else full_det
        if short != full_det:
            specs[short] = spec

    return specs


def load_all_specs() -> dict:
    """Load specs from guard-rules, audit-rules, and review-rules. Returns merged dict."""
    specs = {}
    for subdir in ['guard-rules', 'audit-rules', 'review-rules']:
        d = os.path.join(PROJECT_ROOT, 'knowledge', subdir)
        specs.update(load_specs_from_dir(d))
    return specs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--findings-dir', required=True)
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--check-spec', action='store_true',
                        help='Enable Detection Spec cross-validation against guard-rules/audit-rules/review-rules')
    args, _ = parser.parse_known_args()

    if not os.path.isdir(args.findings_dir):
        print(f"FATAL: findings directory not found: {args.findings_dir}")
        sys.exit(1)

    specs = load_all_specs() if args.check_spec else {}
    if args.check_spec:
        unique = set(s.get('detector') for s in specs.values())
        if not unique:
            print("  ⚠  No detection specs found — spec check disabled")
            args.check_spec = False
        else:
            print(f"  ✓ Loaded {len(unique)} detection specs from guard-rules/audit-rules/review-rules")

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
            if args.check_spec:
                det = finding.get('detector', '')
                spec = specs.get(det)
                if spec:
                    spec_mismatches = check_spec(finding, spec)

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

    if total_errors > 0:
        print(f"\n❌ {', '.join(parts)}")
        print("   Fix the findings before calling the renderer.")
        sys.exit(1)
    else:
        print(f"✅ {', '.join(parts)}")
        sys.exit(0)


if __name__ == '__main__':
    main()
