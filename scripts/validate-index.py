#!/usr/bin/env python3
"""
Step 2b 索引验证 + 结构化摘要输出

用途: 被命令模板中的 Step 2b 调用，替代内联 Python heredoc。
优势: 
  - 避免内联 Python 的引号转义问题
  - 对 None/null 值鲁棒（不同语言索引器结构不同）
  - 可在 CI 中独立测试

用法: python3 scripts/validate-index.py --index <path> --scan-id <id>
"""
import argparse, json, os, sys
from collections import Counter

EXT_MAP = {
    'c': 'cpp', 'h': 'cpp', 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp',
    'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
    'java': 'java',
    'py': 'python', 'pyw': 'python',
    'go': 'go',
    'js': 'javascript', 'jsx': 'javascript', 'ts': 'javascript',
    'tsx': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
    'rs': 'rust', 'swift': 'swift', 'kt': 'kotlin', 'kts': 'kotlin',
    'scala': 'scala', 'rb': 'ruby', 'php': 'php', 'cs': 'csharp',
    'fs': 'fsharp', 'sh': 'shell', 'bash': 'shell', 'zsh': 'shell',
    'cmake': 'cmake', 'mk': 'makefile',
}

# C vs C++ — 当 all C-family 文件是 .c/.h 时报告 "c" 而非 "cpp"
C_ONLY_EXTS = {'c', 'h'}
CXX_EXTS = {'cpp', 'cc', 'cxx', 'hpp', 'hh', 'hxx'}


def safe_len(obj):
    """安全获取长度: None → 0, list → len(list)"""
    return len(obj) if isinstance(obj, (list, dict, str)) else 0


def detect_lang(filepath):
    base = os.path.basename(filepath)
    if base.startswith('.') or '.' not in base:
        return None
    return EXT_MAP.get(base.rsplit('.', 1)[-1].lower())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--index', required=True)
    parser.add_argument('--scan-id', default='')
    args = parser.parse_args()

    if not os.path.isfile(args.index):
        print(f"FATAL: index file not found: {args.index}", file=sys.stderr)
        sys.exit(1)

    with open(args.index) as f:
        d = json.load(f)

    # ── 校验（null-safe） ──
    files = d.get('files') or []
    assert len(files) > 0, 'FATAL: index contains no files'
    assert d.get('symbols') is not None, 'FATAL: index missing symbols'
    assert d.get('call_graph') is not None, 'FATAL: index missing call_graph'

    # ── 语言检测 ──
    langs = Counter()
    ext_counts = Counter()  # raw extension (before cpp normalization)
    for f in files:
        lang = detect_lang(f)
        if lang:
            langs[lang] += 1
            ext = os.path.splitext(f)[-1].lstrip('.').lower()
            ext_counts[ext] += 1
    primary_lang = langs.most_common(1)[0][0] if langs else 'unknown'

    # Normalize: when all C-family files are .c/.h, report "c" not "cpp"
    if primary_lang == 'cpp':
        c_total = sum(ext_counts[e] for e in C_ONLY_EXTS if e in ext_counts)
        cxx_total = sum(ext_counts[e] for e in CXX_EXTS if e in ext_counts)
        if c_total > 0 and cxx_total == 0:
            primary_lang = 'c'

    # ── 安全访问索引器数据 ──
    functions = d.get('symbols', {}).get('functions') or []
    call_edges = d.get('call_graph', {}).get('edges') or []

    # ── 输出 JSON 摘要 ──
    summary = {
        'scan_id': args.scan_id,
        'file_count': safe_len(files),
        'function_count': safe_len(functions),
        'call_edge_count': safe_len(call_edges),
        'primary_language': primary_lang,
        'language_distribution': dict(langs.most_common()),
        'index_path': os.path.abspath(args.index),
    }
    json.dump(summary, sys.stdout, indent=2, ensure_ascii=False)
    print()  # trailing newline


if __name__ == '__main__':
    main()
