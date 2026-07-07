#!/usr/bin/env python3
"""
strip-all-demos.py — 批量脱敏。
第四版：覆盖 Python docstring TP/P 模式 + 中文"真漏洞" + 带空格 CWE 列表。
"""
import os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))

PATTERNS_SOLO = [
    # // VULNERABILITY [CWE-xxx]  / # VULNERABILITY [CWE-xxx]
    re.compile(r'^\s*//\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'^\s*#\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    # // BAD:  / # BAD:
    re.compile(r'^\s*//\s*BAD\s*:.*$'),
    re.compile(r'^\s*#\s*BAD\s*:.*$'),
    # // TP-xxx / // P0-xxx / // P3-xxx
    re.compile(r'^\s*//\s*(?:TP|P[0-3])-\d+.*$'),
    re.compile(r'^\s*#\s*(?:TP|P[0-3])-\d+.*$'),
    # """TP-01: title"""  / """P3-01: title"""
    re.compile(r'^\s*"""(?:TP|P[0-3])-\d+\s*:.*"""\s*$'),
    # /* ── CWE-77: Title ─── */
    re.compile(r'^\s*/\*\s*─+\s*CWE-\d+\s*:.*─+\s*\*/\s*$'),
    # // ── CWE-79: XSS ──
    re.compile(r'^\s*//\s*─+\s*CWE-\d+.*$'),
    re.compile(r'^\s*#\s*─+\s*CWE-\d+.*$'),
    # *   - CWE-415: ... (块注释 CWE 列表)
    re.compile(r'^\s*\*\s+-\s+CWE-\d+\s*:.*$'),
    #   - CWE-22:  Path traversal (Python docstring / 任意缩进)
    re.compile(r'^\s*[-*]\s+CWE-\d+\s*:.*$'),
    # // 1. NoSQL Injection (CWE-943)
    re.compile(r'^\s*//\s*\d+\.\s+.*\(CWE-\d+\).*$'),
    re.compile(r'^\s*#\s*\d+\.\s+.*\(CWE-\d+\).*$'),
    # // CWE-xxx: title / # CWE-xxx: title
    re.compile(r'^\s*//\s*CWE-\d+\s*:.*$'),
    re.compile(r'^\s*#\s*CWE-\d+\s*:.*$'),
    # // 真漏洞: 任意文字
    re.compile(r'^\s*//.*真漏洞.*$'),
    # VULNERABILITIES: (Python docstring, no * prefix)
    re.compile(r'^\s*VULNERABILITIES:\s*$'),
    # * VULNERABILITIES:
    re.compile(r'^\s*\*\s*VULNERABILITIES:\s*$'),
    # // ← Detector 标记: / # Detector 标记:  /  Detector 会标记
    re.compile(r'^\s*//.*Detector.*标记.*$'),
    re.compile(r'^\s*#.*Detector.*标记.*$'),
    re.compile(r'^\s*\*.*Detector.*标记.*$'),
    # // P2 期望: / // P3 — Edge Cases
    re.compile(r'^\s*//\s*P[0-9].*期望.*$'),
    re.compile(r'^\s*//\s*P[0-9]\s*[—\-]+\s*.*$'),
    # * P2 期望: / * P3 — Edge (block comment)
    re.compile(r'^\s*\*\s*P[0-9]\s*.*期望.*$'),
    re.compile(r'^\s*\*\s*P[0-9]\s*[—\-]+\s*.*$'),
]

PATTERNS_INLINE = [
    re.compile(r'\s*//\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'\s*#\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'\s*//\s*BAD\s*:.*$'),
    re.compile(r'\s*#\s*BAD\s*:.*$'),
    re.compile(r'\s*//\s*←\s*Detector.*CWE-\d+.*$'),
    re.compile(r'\s*//\s*←.*标记.*CWE-\d+.*$'),
    re.compile(r'\s*//\s*←.*真漏洞.*$'),
    re.compile(r'\s*//.*真漏洞.*$'),
    re.compile(r'\s*//.*Detector.*标记.*$'),
    re.compile(r'\s*//.*P[0-9].*期望.*$'),
    re.compile(r'\s*//.*P[0-9]\s*[—\-]+\s*.*$'),
    re.compile(r'\s*//.*←.*标记.*$'),
]

SOURCE_EXTS = {'.c', '.cpp', '.h', '.hpp', '.java', '.py', '.go', '.js', '.ts', '.rs', '.rb', '.php'}


def strip_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    stripped = 0
    out = []
    for line in lines:
        hit = False
        for pat in PATTERNS_SOLO:
            if pat.match(line):
                out.append("\n")
                stripped += 1
                hit = True
                break
        if hit:
            continue

        for pat in PATTERNS_INLINE:
            m = pat.search(line)
            if m:
                line = line[:m.start()] + "\n"
                stripped += 1
                break

        out.append(line)

    if stripped > 0:
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(out)
    return stripped


def main():
    total_lines = 0
    total_files = 0
    for root, dirs, files in os.walk(BASE):
        if ".codeagent" in dirs:
            dirs.remove(".codeagent")
        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in SOURCE_EXTS:
                continue
            if "-no-answers" not in root:
                continue
            fpath = os.path.join(root, fname)
            n = strip_file(fpath)
            if n > 0:
                rel = os.path.relpath(fpath, BASE)
                print(f"  [{n:>3}] {rel}")
                total_lines += n
                total_files += 1
    print(f"\nDone: {total_files} files modified, {total_lines} lines stripped")
    return 0


if __name__ == "__main__":
    sys.exit(main())
