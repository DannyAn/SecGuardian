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

  == --from-file mode ==
  Write the finding JSON to a file, then pass the path with --from-file:
    cat > /tmp/finding.json << 'FEOF'
    {"detector": "web.sql-injection", "severity": "Critical", "cwe": "CWE-89",
     "file": "src/app.py", "line": 42,
     "snippet": "...", "code_context": "...", "rationale": "...", "attack_scenario": "..."}
    FEOF
    python3 record-finding.py --from-file /tmp/finding.json --scan-dir .codeagent/scans/x/
        ''')

    # --from-file mode: make all args optional so standalone JSON works
    from_file_mode = '--from-file' in sys.argv
    required_mode = not from_file_mode

    # Core required fields
    p.add_argument('--command', default='',
                   choices=['secguard', 'secaudit', 'secreview'],
                   help='[logging only] Command type identifier')
    p.add_argument('--scan-dir', required=required_mode,
                   help='Scan output directory (parent of findings/)')
    p.add_argument('--detector', required=required_mode,
                   help='Detector name (e.g. web.sql-injection, audit.cryptography)')
    p.add_argument('--severity', required=required_mode,
                   choices=['Critical', 'High', 'Medium', 'Low', 'Info'])
    p.add_argument('--cwe', required=required_mode, help='CWE ID, e.g. CWE-89')
    p.add_argument('--file', required=required_mode, help='Source file path')
    p.add_argument('--line', required=required_mode, type=int, help='Line number')

    # Optional common fields
    p.add_argument('--end-line', type=int, default=None,
                   help='End line (for location.end_line)')
    p.add_argument('--function', default='', help='Function name')
    p.add_argument('--title', default='', help='Finding title / fix description')
    p.add_argument('--snippet', required=required_mode,
                   help='Code snippet (REQUIRED per engine_contract.md Rule B)')
    p.add_argument('--code-context', required=required_mode,
                   help='Code context (REQUIRED per engine_contract.md Rule B)')
    p.add_argument('--rationale', required=required_mode,
                   help='Judgment rationale (REQUIRED per engine_contract.md Rule B)')
    p.add_argument('--attack-scenario', required=required_mode,
                   help='Attack scenario (REQUIRED per engine_contract.md Rule B)')
    p.add_argument('--cvss', type=float, default=0.0,
                   help='CVSS score (0.0-10.0)')
    p.add_argument('--fix-before', default='', help='Vulnerable code')
    p.add_argument('--fix-after', default='', help='Fixed code')
    p.add_argument('--fix-before-file', default='',
                   help='[secaudit/secreview] File path containing vulnerable code (avoids shell quoting)')
    p.add_argument('--fix-after-file', default='',
                   help='[secaudit/secreview] File path containing fixed code (avoids shell quoting)')

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

    p.add_argument('--index-json', default='',
                   help='[anchor validation] Path to index.json for file+line cross-reference')
    
    p.add_argument('--from-file', nargs='?', default='', const='',
                   help='Read finding JSON from a file path (avoids CLI long-text overhead)')

    # ── Normalize CLI args: convert --underscore_name to --hyphen-name ──
    # AI agents naturally use Python-style underscore naming in shell commands.
    # This normalization ensures --code_context works the same as --code-context,
    # --attack_scenario the same as --attack-scenario, etc., for ALL args.
    normalized_argv = []
    for raw_arg in sys.argv[1:]:
        if raw_arg.startswith('--') and '_' in raw_arg:
            eq_pos = raw_arg.find('=')
            if eq_pos > 0:
                normalized_argv.append(raw_arg[:eq_pos].replace('_', '-') + raw_arg[eq_pos:])
            else:
                normalized_argv.append(raw_arg.replace('_', '-'))
        else:
            normalized_argv.append(raw_arg)

    args, unknown = p.parse_known_args(normalized_argv)

    # ── Reject unknown arguments (typo protection) ──
    # This catches --attack-scannerio (typo for --attack-scenario)
    # and any other misspelled or invented argument names.
    unknown_filtered = [a for a in unknown if not a.startswith('-')]
    unknown_opts = [a for a in unknown if a.startswith('-')]
    if unknown_opts:
        print("Deprecated: Unknown argument(s): {}".format(' '.join(unknown_opts)), file=sys.stderr)
        print("  These argument names were not recognized. Check spelling.", file=sys.stderr)
        sys.exit(4)


    # ── Reject --from-file without a file path argument ──
    if '--from-file' in sys.argv and not args.from_file:
        print("Deprecated: --from-file must be followed by a file path", file=sys.stderr)
        print("  Correct: --from-file=\"\$SCAN_DIR/findings/finding-{id}.json\"", file=sys.stderr)
        print("  Or:      --from-file \"\$SCAN_DIR/findings/finding-{id}.json\"", file=sys.stderr)
        print("  Wrong:   --from-file (alone)  --from-file is an argument, not a flag.", file=sys.stderr)
        sys.exit(2)

    # ── Reject placeholder scan_dir values ──
    # AI agents sometimes use SCAN_DIR_PLACEHOLDER as a literal instead of the real path.
    # This creates a SCAN_DIR_PLACEHOLDER directory in the project root — a user-facing bug.
    if 'PLACEHOLDER' in str(args.scan_dir).upper():
        print("PLACEHOLDER detected '{}' — must use actual scan directory".format(args.scan_dir), file=sys.stderr)

    # ── Read from file if --from-file (avoids CLI long-text overhead) ──
    if args.from_file:
        try:
            with open(args.from_file) as f:
                file_json = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Deprecated: --from-file error: {e}", file=sys.stderr)
            sys.exit(3)
        for field in ['command', 'detector', 'severity', 'cwe', 'file', 'function',
                       'title', 'snippet', 'code_context', 'rationale', 'attack_scenario',
                       'fix_before', 'fix_after', 'review_pass', 'review_focus',
                       'data_flow_path', 'skill_name', 'skill_category',
                       'scan_dir', 'index_json']:
            if field in file_json:
                setattr(args, field, file_json[field])
        if 'line' in file_json:
            args.line = int(file_json['line'])
        if 'end_line' in file_json:
            args.end_line = int(file_json['end_line'])
        if 'cvss' in file_json:
            args.cvss = float(file_json['cvss'])

    # ── Validate required fields (whether from CLI or stdin) ──
    required_fields = {
        'scan_dir': '--scan-dir / scan_dir',
        'detector': '--detector / detector',
        'severity': '--severity / severity',
        'cwe': '--cwe / cwe',
        'file': '--file / file',
        'line': '--line / line',
        'snippet': '--snippet / snippet',
        'code_context': '--code-context / code_context',
        'rationale': '--rationale / rationale',
        'attack_scenario': '--attack-scenario / attack_scenario',
    }
    missing = []
    for field, flag_name in required_fields.items():
        val = getattr(args, field, None)
        if val is None or (isinstance(val, str) and not val.strip()):
            missing.append(flag_name)
    if missing:
        print("Missing fields: {}".format(', '.join(missing)), file=sys.stderr)
        sys.exit(2)

    # Read fix from files if specified (avoids shell quoting issues with inline args)
    if args.fix_before_file and os.path.isfile(args.fix_before_file):
        with open(args.fix_before_file, 'r') as f:
            args.fix_before = f.read().rstrip('\n')
    if args.fix_after_file and os.path.isfile(args.fix_after_file):
        with open(args.fix_after_file, 'r') as f:
            args.fix_after = f.read().rstrip('\n')

    # ── Anchor cross-validation (engine_contract.md Rule A) ──
    if args.index_json and os.path.isfile(args.index_json):
        try:
            with open(args.index_json, 'r') as f:
                idx = json.load(f)
        except Exception as e:
            print(f"ANCHOR_WARN: Cannot read index.json ({e}) — skipping anchor validation", file=sys.stderr)
            idx = None

        if idx:
            files_list = idx.get('files') or []
            functions = idx.get('symbols', {}).get('functions') or []
            variables = idx.get('symbols', {}).get('variables') or []
            types_list = idx.get('symbols', {}).get('types') or []

            # Check 1: file exists in index
            file_in_index = any(args.file == f or args.file.endswith(f) or f.endswith(args.file)
                                for f in files_list)
            if not file_in_index:
                print("ANCHOR_FAIL: file '{}' not found in index.json files list".format(args.file), file=sys.stderr)
                print("  Index files: {}".format(files_list[:5]), file=sys.stderr)
                sys.exit(2)

            # Check 2: line falls within some symbol's range or file exists
            symbol_match = None
            for sym_list, sym_type in [(functions, 'function'), (variables, 'variable'), (types_list, 'type')]:
                for s in sym_list:
                    s_file = s.get('file', '')
                    s_start = s.get('start_line', 0)
                    s_end = s.get('end_line', s_start)
                    file_matches = (args.file == s_file or args.file.endswith(s_file) or s_file.endswith(args.file))
                    if file_matches and s_start <= args.line <= (s_end or s_start + 50):
                        symbol_match = (sym_type, s.get('name', ''))
                        break
                if symbol_match:
                    break

            if symbol_match:
                print("ANCHOR_OK: found in {} '{}' at {}:{}-{}".format(
                    symbol_match[0], symbol_match[1], args.file, args.line,
                    "validated"), file=sys.stderr)
            else:
                print("ANCHOR_INFO: line {} in '{}' is module/class-level (not in function symbol table)".format(
                    args.line, args.file), file=sys.stderr)
                print("  File verified in index. Finding recorded normally — anchor at file level.", file=sys.stderr)
    elif args.index_json:
        print("ANCHOR_WARN: --index-json '{}' not found — skipping anchor validation".format(args.index_json), file=sys.stderr)

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
                "before_code": args.fix_before_file or args.fix_before,
                "after_code": args.fix_after_file or args.fix_after
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

    # ── Idempotency guard: skip if same (detector:file:line:cwe) already recorded ──
    finding = clean_none(finding)
    fpath = os.path.join(dpath, fname)
    if os.path.exists(fpath):
        print(
            f"IDEMPOTENT_SKIP: findings/{ns_name}/{det_name}/{fname} "
            f"({args.severity}, {args.cwe}) — already recorded"
        )
        return 0

    with open(fpath, 'w', encoding='utf-8') as f:
        json.dump(finding, f, indent=2, ensure_ascii=False)

    print(
        f"RECORDED: findings/{ns_name}/{det_name}/{fname} "
        f"({args.severity}, {args.cwe})"
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
