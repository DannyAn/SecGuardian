#!/usr/bin/env python3
"""
Generate Detection Spec for all rule types: guard-rules, audit-rules, review-rules.

For each .md file:
  guard-rules:  Parse frontmatter (detector/severity/CWE) + Detection Patterns
                → spec: {namespace}.{detector}, severity, CWE, CVSS, target_functions, patterns
  audit-rules:  Parse frontmatter (name/topic) → derive severity/CWE from topic
                → spec: domain.{name}, topic, implied severity/CWE
  review-rules: Parse language name from filename + anti-pattern table
                → spec: review.{lang}, anti-patterns, max severity

Each file gets a ## Detection Spec JSON block injected.

Idempotent: if spec marker already present, updates in-place.

Usage:
  python3 scripts/generate-detection-specs.py
  python3 scripts/generate-detection-specs.py --dry-run
"""
import argparse, json, os, re, sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NAMESPACE_MAP = {
    'memory': 'memory', 'concurrency': 'concurrency', 'crypto': 'crypto',
    'web': 'web', 'system': 'system', 'error': 'error', 'resource': 'resource',
}
CVSS_MAP = {'critical': 9.8, 'high': 7.5, 'medium': 5.5, 'low': 3.5}
NAMESPACE_CVSS_MOD = {'memory': 0.0, 'concurrency': 0.0, 'crypto': 0.0,
                      'web': 0.3, 'system': 0.0, 'error': -1.0, 'resource': 0.0}
AUDIT_TOPIC_MAP = {
    'web': {'severity': 'High', 'cwe': 'CWE-200', 'cvss': 7.5},
    'crypto': {'severity': 'Critical', 'cwe': 'CWE-310', 'cvss': 9.1},
    'infra': {'severity': 'Medium', 'cwe': 'CWE-000', 'cvss': 5.5},
    'network': {'severity': 'High', 'cwe': 'CWE-000', 'cvss': 7.5},
    'config': {'severity': 'Medium', 'cwe': 'CWE-000', 'cvss': 5.5},
    'auth': {'severity': 'Critical', 'cwe': 'CWE-287', 'cvss': 9.8},
    'data': {'severity': 'High', 'cwe': 'CWE-200', 'cvss': 7.5},
    'log': {'severity': 'Medium', 'cwe': 'CWE-532', 'cvss': 5.5},
    'dependency': {'severity': 'High', 'cwe': 'CWE-1104', 'cvss': 7.5},
}


def parse_frontmatter(content: str) -> tuple[dict, int]:
    if not content.startswith('---'):
        return {}, 0
    lines = content.split('\n')
    end = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == '---':
            end = i
            break
    if end < 0:
        return {}, 0
    fields = {}
    for line in lines[1:end]:
        line = line.strip()
        if ':' in line:
            key, _, val = line.partition(':')
            key = key.strip()
            val = val.strip()
            if val.startswith('[') and val.endswith(']'):
                val = [v.strip().strip('"\'') for v in val[1:-1].split(',')]
            elif val.lower() == 'true':
                val = True
            elif val.lower() == 'false':
                val = False
            else:
                try:
                    val = float(val) if '.' in val else int(val)
                except (ValueError, TypeError):
                    val = val.strip('"\'')
            fields[key] = val
    return fields, end


def detect_namespace(filename: str) -> str:
    for prefix, ns in sorted(NAMESPACE_MAP.items(), key=lambda x: -len(x[0])):
        if filename.startswith(prefix):
            return ns
    return 'unknown'


def extract_target_functions(content: str) -> list[str]:
    functions = set()
    dp_match = re.search(r'## 检测模式汇总.*?\n(```|~~~)\w*\n(.*?)(```|~~~)', content, re.DOTALL)
    if dp_match:
        dp_text = dp_match.group(2)
        match_start = -1
        for m in re.finditer(r'# ===\s*MATCH', dp_text):
            match_start = m.end()
            break
        if match_start >= 0:
            match_end = len(dp_text)
            for m in re.finditer(r'# ===\s*EXCLUDE', dp_text):
                match_end = m.start()
                break
            block = dp_text[match_start:match_end]
            for f in re.findall(r'[a-zA-Z_]\w*(?=\s*\()', block):
                if len(f) > 2 and f[0].islower():
                    functions.add(f)
            for f in re.findall(r'\(?([a-z_]\w+)(?=\|)', block):
                if len(f) > 2:
                    functions.add(f.replace('\\', ''))
            for f in re.findall(r'\|([a-z_]\w+)', block):
                if len(f) > 2:
                    functions.add(f.replace('\\', ''))

    dl_match = re.search(r'## 检测逻辑.*?\n(.*?)(?=\n## \w)', content, re.DOTALL)
    if dl_match:
        dl_text = dl_match.group(1)
        for block in re.findall(r'```.*?\n(.*?)```', dl_text, re.DOTALL):
            for f in re.findall(r'(?<![a-zA-Z])([a-z_]\w+)\s*\(', block):
                f = f.strip('_')
                if len(f) > 2 and not f[0].isupper():
                    functions.add(f)
    noise = {'if', 'for', 'while', 'do', 'switch', 'case', 'return', 'int', 'char',
             'void', 'static', 'const', 'struct', 'enum', 'sizeof', 'include',
             'define', 'null', 'true', 'false', 'bool', 'long', 'short',
             'unsigned', 'signed', 'auto', 'extern', 'register',
             'typedef', 'union', 'volatile', 'inline', 'this', 'class', 'new',
             'delete', 'throws', 'throw', 'try', 'catch', 'finally', 'import',
             'extends', 'implements', 'interface', 'abstract', 'assert', 'var',
             'val', 'fun', 'def', 'lambda', 'async', 'await', 'yield', 'with',
             'as', 'except', 'raise', 'pass', 'break', 'continue', 'printf',
             'printf_s', 'puts', 'scanf', 'expect', 'describe', 'it', 'test',
             'let', 'const', 'log', 'print', 'len', 'cap', 'append', 'copy',
             'make', 'range', 'type', 'string', 'error', 'nil', 'panic',
             'recover', 'close', 'select', 'map', 'chan', 'go', 'defer',
             'not', 'and', 'or', 'is', 'in', 'to', 'of', 'at', 'by', 'on'}
    return sorted(functions - noise)


def extract_match_patterns(content: str) -> list[str]:
    return _extract_pattern_group(content, r'# ===\s*MATCH', r'# ===\s*EXCLUDE')


def extract_exclude_patterns(content: str) -> list[str]:
    return _extract_pattern_group(content, r'# ===\s*EXCLUDE', None)


def _extract_pattern_group(content: str, start_marker: str, end_marker: str) -> list[str]:
    dp_match = re.search(r'## 检测模式汇总.*?\n(```|~~~)\w*\n(.*?)(```|~~~)', content, re.DOTALL)
    if not dp_match:
        return []
    dp_text = dp_match.group(2)
    start_idx = -1
    for m in re.finditer(start_marker, dp_text):
        start_idx = m.start()
        break
    if start_idx < 0:
        return []
    end_idx = len(dp_text)
    if end_marker:
        for m in re.finditer(end_marker, dp_text):
            end_idx = m.start()
            break
    block = dp_text[start_idx:end_idx]
    patterns = []
    for line in block.split('\n'):
        s = line.strip()
        if not s:
            continue
        if s.startswith('# ') and ('===' in s or 'MATCH' in s or 'EXCLUDE' in s):
            continue
        if s.startswith('#'):
            continue
        if s.startswith('→') or s.startswith('->'):
            continue
        if re.match(r'^[A-Z]+:', s):
            continue
        if re.match(r'^(MUST|SHOULD|MAY):', s):
            continue
        if re.match(r'^→?\s*[a-z_]\w*$', s):
            continue
        patterns.append(s)
    return patterns


def extract_required_evidence(content: str) -> tuple[list[str], list[str], list[str]]:
    must, should, may = [], [], []
    ev_match = re.search(r'## 取证证据收集指引.*?\n(.*?)(?=\n## )', content, re.DOTALL)
    if not ev_match:
        return must, should, may
    current = None
    for line in ev_match.group(1).split('\n'):
        s = line.strip()
        if '必须收集' in s or 'MUST' in s:
            current = 'must'
        elif '建议收集' in s or 'SHOULD' in s:
            current = 'should'
        elif '可选收集' in s or 'MAY' in s:
            current = 'may'
        elif s and not s.startswith('#'):
            fm = re.search(r'\*\*(\w+)\*\*', s)
            if not fm:
                fm = re.search(r'findings\.evidence\.(\w+)', s)
            if fm:
                f = fm.group(1)
                if current == 'must':
                    must.append(f)
                elif current == 'should':
                    should.append(f)
                elif current == 'may':
                    may.append(f)
    return list(dict.fromkeys(must)), list(dict.fromkeys(should)), list(dict.fromkeys(may))


def build_detection_spec(detector: str, namespace: str, frontmatter: dict,
                         target_functions: list[str],
                         match_patterns: list[str],
                         exclude_patterns: list[str],
                         must_evidence: list[str],
                         should_evidence: list[str]) -> dict:
    severity = frontmatter.get('severity', 'medium')
    cwe = frontmatter.get('cwe', 'CWE-000')
    languages = frontmatter.get('language', [])
    if isinstance(languages, str):
        languages = [languages]
    base = CVSS_MAP.get(str(severity).lower(), 5.5)
    cvss = round(min(base + NAMESPACE_CVSS_MOD.get(namespace, 0.0), 9.8), 1)
    spec = {
        'detector': detector, 'type': 'guard-rule', 'namespace': namespace,
        'severity': str(severity).capitalize(), 'cwe': str(cwe).strip('"\''),
        'cvss': cvss,
        'confidence': frontmatter.get('confidence', 'medium'),
        'precision': frontmatter.get('precision', 'medium'),
        'languages': languages,
        'target_functions': target_functions,
        'match_patterns': match_patterns,
        'exclude_patterns': exclude_patterns,
    }
    if must_evidence:
        spec['required_evidence'] = must_evidence
    if should_evidence:
        spec['optional_evidence'] = should_evidence
    return spec


def build_audit_spec(name: str, frontmatter: dict) -> dict:
    topics = frontmatter.get('topic', [])
    if isinstance(topics, str):
        topics = [topics]
    severity, cwe, cvss = 'Medium', 'CWE-000', 5.5
    sev_order = {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1}
    for t in topics:
        t = t.lower()
        if t in AUDIT_TOPIC_MAP:
            tm = AUDIT_TOPIC_MAP[t]
            if sev_order.get(tm['severity'], 0) > sev_order.get(severity, 0):
                severity, cwe, cvss = tm['severity'], tm['cwe'], tm['cvss']
    return {
        'detector': f'domain.{name}', 'type': 'audit-rule',
        'domain_name': name, 'category': frontmatter.get('category', 'domain'),
        'topics': topics,
        'severity': severity, 'cwe': cwe, 'cvss': cvss,
    }


def build_review_spec(lang: str, content: str) -> dict:
    max_severity = 'Medium'
    count = 0
    sev_order = {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1}
    for m in re.finditer(r'\|(.+?)\|(.+?)\|(.+?)\|', content):
        ap, pat, sev = m.group(1).strip(), m.group(2).strip(), m.group(3).strip()
        if ap and pat and sev in sev_order:
            count += 1
            if sev_order.get(sev, 0) > sev_order.get(max_severity, 0):
                max_severity = sev
    return {
        'detector': f'review.{lang}', 'type': 'review-rule', 'language': lang,
        'max_severity': max_severity, 'cwe': 'CWE-000',
        'anti_pattern_count': count,
    }


def inject_spec_into_md(filepath: str, spec: dict, dry_run: bool = False) -> bool:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    spec_json = json.dumps(spec, ensure_ascii=False, indent=2)
    spec_block = '## Detection Spec\n\n<!-- @secguardian:detection-spec -->\n```json\n' + spec_json + '\n```'
    marker = '<!-- @secguardian:detection-spec -->'

    # Already has spec → update in place
    if marker in content:
        start = content.find('## Detection Spec')
        end = content.find('\n## ', start + 1)
        if end > start:
            old = content[start:end]
            if not dry_run:
                content = content.replace(old, spec_block)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
        return True

    # No spec yet — insert after frontmatter, or create frontmatter if none exists
    _, fm_end = parse_frontmatter(content)
    lines = content.split('\n')

    if fm_end > 0:
        # Has frontmatter — insert after closing ---, before first heading
        insert_at = fm_end + 1
        for i in range(fm_end + 1, len(lines)):
            if lines[i].strip().startswith('#') or lines[i].strip().startswith('##'):
                insert_at = i
                break
        if not dry_run:
            new_lines = lines[:insert_at] + ['', spec_block, ''] + lines[insert_at:]
            new_content = '\n'.join(new_lines)
            if not new_content.endswith('\n'):
                new_content += '\n'
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
        return True

    # No frontmatter (review-rules) — create one then insert spec after it
    det = spec.get('detector', 'unknown')
    rule_type = spec.get('type', 'unknown')
    if not dry_run:
        fm = ['---', f'detector: {det}', f'type: {rule_type}', '---']
        frontmatter_str = '\n'.join(fm)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(frontmatter_str + '\n\n' + spec_block + '\n\n' + content)
    return True


def process_guard_rules(dry_run: bool) -> tuple[int, int]:
    guard_dir = os.path.join(PROJECT_ROOT, 'knowledge', 'guard-rules')
    if not os.path.isdir(guard_dir):
        return 0, 0
    processed, errors = 0, 0
    for fname in sorted(os.listdir(guard_dir)):
        if not fname.endswith('.md'):
            continue
        filepath = os.path.join(guard_dir, fname)
        with open(filepath, encoding='utf-8') as f:
            content = f.read()
        fm, _ = parse_frontmatter(content)
        if not fm:
            continue

        short = fm.get('detector', fname.replace('.md', ''))
        namespace = detect_namespace(fname)
        if namespace == 'unknown':
            tags = fm.get('tags', [])
            if isinstance(tags, list):
                for tag in tags:
                    if tag in NAMESPACE_MAP:
                        namespace = tag
                        break
        # Use full short name without stripping (namespace.name format where both parts can overlap)
        detector_full = f'{namespace}.{short}'
        spec = build_detection_spec(
            detector_full, namespace, fm,
            extract_target_functions(content),
            extract_match_patterns(content),
            extract_exclude_patterns(content),
            *extract_required_evidence(content)[:2],
        )
        inject_spec_into_md(filepath, spec, dry_run)
        if not dry_run:
            print(f'  [OK]  {fname:<40} ns={namespace:<10} spec={detector_full}')
        else:
            print(f'  [DRY] {fname:<40} ns={namespace:<10} spec={detector_full}')
        processed += 1
    return processed, errors


def process_audit_rules(dry_run: bool) -> tuple[int, int]:
    audit_dir = os.path.join(PROJECT_ROOT, 'knowledge', 'audit-rules')
    if not os.path.isdir(audit_dir):
        return 0, 0
    processed, errors = 0, 0
    for fname in sorted(os.listdir(audit_dir)):
        if not fname.endswith('.md'):
            continue
        filepath = os.path.join(audit_dir, fname)
        with open(filepath, encoding='utf-8') as f:
            content = f.read()
        fm, _ = parse_frontmatter(content)
        if not fm:
            continue
        name = fm.get('name', fname.replace('.md', ''))
        spec = build_audit_spec(name, fm)
        inject_spec_into_md(filepath, spec, dry_run)
        if not dry_run:
            print(f'  [OK]  {fname:<40} domain={name:<20} severity={spec["severity"]}')
        else:
            print(f'  [DRY] {fname:<40} domain={name:<20} spec={spec["detector"]}')
        processed += 1
    return processed, errors


def process_review_rules(dry_run: bool) -> tuple[int, int]:
    review_dir = os.path.join(PROJECT_ROOT, 'knowledge', 'review-rules')
    if not os.path.isdir(review_dir):
        return 0, 0
    processed, errors = 0, 0
    for fname in sorted(os.listdir(review_dir)):
        if not fname.endswith('.md'):
            continue
        lang = fname.replace('.md', '')
        filepath = os.path.join(review_dir, fname)
        with open(filepath, encoding='utf-8') as f:
            content = f.read()
        spec = build_review_spec(lang, content)
        inject_spec_into_md(filepath, spec, dry_run)
        if not dry_run:
            print(f'  [OK]  {fname:<40} lang={lang:<8} patterns={spec["anti_pattern_count"]}')
        else:
            print(f'  [DRY] {fname:<40} lang={lang:<8} spec={spec["detector"]}')
        processed += 1
    return processed, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    total = 0
    for label, fn in [('guard-rules', process_guard_rules),
                      ('audit-rules', process_audit_rules),
                      ('review-rules', process_review_rules)]:
        print(f'\n{"="*60}\n{label}/\n{"="*60}')
        p, e = fn(args.dry_run)
        total += p

    print(f'\n{"="*60}')
    print(f'Summary: {total} files processed')
    if args.dry_run:
        print('(dry run — no files modified)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
