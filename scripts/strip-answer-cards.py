#!/usr/bin/env python3
"""
strip-answer-cards.py — 脱敏源码中的答案卡注释，防止 AI 走捷径。

移除已知的答案卡标注模式（VULNERABILITY / CWE / BAD / TP/P0-P3），
迫使 AI 回归 guard-rule 独立检测，而非靠注释直接获知漏洞所在。

用法:
  python3 strip-answer-cards.py \\
      --index <index.json>          index.json 提供文件清单
      --output-dir <dir>            脱敏副本输出目录
      [--source-root <dir>]         源码根目录（默认从 index 记录的路径推断）
      [--dry-run]                   只统计，不写入

输出:
  - 在 output-dir 下写入所有源码文件脱敏副本
  - stdout 输出处理摘要: "Stripped N lines across M files"
  - exit 0 表示成功
"""

import json
import os
import re
import sys
from typing import Optional, Set

# ── 答案卡模式 ──────────────────────────────────────────────
# 整行答案卡 — 替换整行为空行（保留行号）
PATTERNS_LINE = [
    # // VULNERABILITY [CWE-xxx]  / # VULNERABILITY [CWE-xxx]
    re.compile(r'^\s*//\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'^\s*#\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    # // BAD: / # BAD:
    re.compile(r'^\s*//\s*BAD\s*:.*$'),
    re.compile(r'^\s*#\s*BAD\s*:.*$'),
    # // TP-xxx / // P0-xxx  (Python: """TP-01:..."""  / # TP-01:)
    re.compile(r'^\s*//\s*(?:TP|P[0-3])-\d+.*$'),
    re.compile(r'^\s*#\s*(?:TP|P[0-3])-\d+.*$'),
    re.compile(r'^\s*"""(?:TP|P[0-3])-\d+\s*:.*"""\s*$'),
    # // ── CWE-79: XSS ── section headers
    re.compile(r'^\s*//\s*─+\s*CWE-\d+.*$'),
    re.compile(r'^\s*#\s*─+\s*CWE-\d+.*$'),
    # // CWE-xxx: title / # CWE-xxx: title
    re.compile(r'^\s*//\s*CWE-\d+\s*:.*$'),
    re.compile(r'^\s*#\s*CWE-\d+\s*:.*$'),
    # // 1. NoSQL Injection (CWE-943)
    re.compile(r'^\s*//\s*\d+\.\s+.*\(CWE-\d+\).*$'),
    re.compile(r'^\s*#\s*\d+\.\s+.*\(CWE-\d+\).*$'),
    # // 真漏洞: / # 真漏洞:
    re.compile(r'^\s*//.*真漏洞.*$'),
    re.compile(r'^\s*#.*真漏洞.*$'),
    # VULNERABILITIES: (Python docstring, no * prefix)
    re.compile(r'^\s*VULNERABILITIES:\s*$'),
    # * VULNERABILITIES: (block comment header)
    re.compile(r'^\s*\*\s*VULNERABILITIES:\s*$'),
]

# 块注释类 — 替换为最小占位（保留行号和结构）
PATTERNS_BLOCK = [
    # /* ── CWE-77: Title ──────────── */
    re.compile(r'^(\s*)/\*\s*─+\s*CWE-\d+\s*:.*─+\s*\*/\s*$'),
    # *   - CWE-415: Double free (line 85)
    re.compile(r'^(\s*\*\s*)-+\s*CWE-\d+\s*:.*$'),
    re.compile(r'^(\s*\*\s*)VULNERABILITIES:.*$'),
    re.compile(r'^(\s*\*\s*)-+\s*CWE-\d+\s*:?.*$'),
    # *   - CWE-xxx: (block comment list — without leading dash)  */
    re.compile(r'^(\s*\*\s+)-?\s*CWE-\d+\s*:.*$'),
    #   - CWE-22: Path traversal (Python docstring / any indent)
    re.compile(r'^(\s*)[-*]\s+CWE-\d+\s*:.*$'),
]

# 行内答案卡 — 只去掉注释部分（保留代码）
PATTERNS_INLINE = [
    re.compile(r'\s*//\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'\s*#\s*VULNERABILITY\s*\[CWE-\d+\].*$'),
    re.compile(r'\s*//\s*BAD\s*:.*$'),
    re.compile(r'\s*#\s*BAD\s*:.*$'),
    re.compile(r'\s*//\s*(?:TP|P[0-3])-\d+.*$'),
    re.compile(r'\s*#\s*(?:TP|P[0-3])-\d+.*$'),
    # ← Detector 标记 / ← 真漏洞 / Detector 标记 (任意位置)
    re.compile(r'\s*//\s*←.*CWE-\d+.*$'),
    re.compile(r'\s*//\s*←.*真漏洞.*$'),
    re.compile(r'\s*//.*Detector.*标记.*$'),
    re.compile(r'\s*#.*Detector.*标记.*$'),
]


def strip_line_annotations(line: str) -> Optional[str]:
    for pat in PATTERNS_LINE:
        if pat.match(line):
            return ""
    return None


def strip_block_annotations(line: str) -> Optional[str]:
    for pat in PATTERNS_BLOCK:
        m = pat.match(line)
        if m:
            prefix = m.group(1)
            if prefix.strip():
                return f"{prefix}(sanitized)\n"
            return "\n"
    return None


def strip_inline_annotations(line: str) -> Optional[str]:
    for pat in PATTERNS_INLINE:
        m = pat.search(line)
        if m:
            return line[:m.start()] + "\n"
    return None


def strip_file(source_path: str) -> tuple[int, str]:
    """
    读取 source_path，脱敏后返回 (stripped_lines_count, stripped_content).
    原始文件不被修改。
    """
    with open(source_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    stripped = 0
    out_lines = []
    for line in lines:
        new = strip_line_annotations(line)
        if new is not None:
            if new != line:
                stripped += 1
            out_lines.append(new)
            continue

        new = strip_block_annotations(line)
        if new is not None:
            if new != line:
                stripped += 1
            out_lines.append(new)
            continue

        new = strip_inline_annotations(line)
        if new is not None:
            if new != line:
                stripped += 1
            out_lines.append(new)
            continue

        out_lines.append(line)

    return stripped, "".join(out_lines)


def main():
    if "--dry-run" in sys.argv:
        dry_run = True
        sys.argv.remove("--dry-run")
    else:
        dry_run = False

    index_path = None
    output_dir = None
    source_root = None

    args = iter(sys.argv[1:])
    for arg in args:
        if arg == "--index":
            index_path = next(args)
        elif arg == "--output-dir" or arg == "--output":
            output_dir = next(args)
        elif arg == "--source-root":
            source_root = next(args)

    if not index_path or not output_dir:
        print("Usage: strip-answer-cards.py --index <index.json> --output-dir <dir> [--source-root <dir>] [--dry-run]", file=sys.stderr)
        sys.exit(1)

    # 1. 读取 index.json
    if not os.path.isfile(index_path):
        print(f"FATAL: index.json not found: {index_path}", file=sys.stderr)
        sys.exit(1)

    with open(index_path, "r") as f:
        index = json.load(f)

    # 2. 收集所有源码文件路径
    source_files: Set[str] = set()
    for func in index.get("symbols", {}).get("functions", []):
        rel_path = func.get("file", "")
        if rel_path:
            source_files.add(rel_path)

    # 同时从 files 列表收集
    for file_entry in index.get("files", []):
        if isinstance(file_entry, str):
            source_files.add(file_entry)
        elif isinstance(file_entry, dict):
            path = file_entry.get("path", "") or file_entry.get("file", "")
            if path:
                source_files.add(path)

    if not source_files:
        print("WARNING: No source files found in index.json", file=sys.stderr)
        sys.exit(0)

    # 3. 确定源码根目录
    if not source_root:
        # 从 index 中第一个文件的路径推断
        first_file = next(iter(source_files))
        if "/" in first_file:
            possible = os.path.dirname(os.path.dirname(os.path.abspath(index_path)))  # scroll up to project root
            source_root = possible
        else:
            source_root = os.path.dirname(os.path.abspath(index_path))
            # Walk up to parent of .codeagent
            p = source_root
            while p and not os.path.isdir(os.path.join(p, ".codeagent")):
                parent = os.path.dirname(p)
                if parent == p:
                    break
                p = parent
            if p and os.path.isdir(os.path.join(p, ".codeagent")):
                source_root = p

    # 4. 处理每个文件
    total_lines_stripped = 0
    files_modified = 0
    files_skipped = []

    for abs_path in sorted(source_files):
        # index.json 可能包含绝对路径（如 /Users/.../src/AuthController.java）
        # 必须先转为相对于 source_root 的路径，否则 os.path.join(output_dir, abs_path)
        # 因绝对值优先级而忽略 output_dir，写在错误的位置
        if os.path.isabs(abs_path) and source_root:
            try:
                rel_path = os.path.relpath(abs_path, source_root)
            except ValueError:
                rel_path = abs_path
        else:
            rel_path = abs_path

        src_abs = os.path.join(source_root, rel_path)
        out_abs = os.path.join(output_dir, rel_path)

        if not os.path.isfile(src_abs):
            files_skipped.append(f"{abs_path} (not found)")
            continue

        # Skip non-text files
        ext = os.path.splitext(rel_path)[1].lower()
        if ext in (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".o", ".a", ".so", ".dylib", ".dll", ".exe", ".class", ".jar", ".zip", ".tar", ".gz"):
            files_skipped.append(f"{rel_path} (binary extension)")
            continue

        stripped_count, content = strip_file(src_abs)

        if dry_run and stripped_count > 0:
            print(f"  [{stripped_count:>3}] {rel_path}")

        if not dry_run:
            os.makedirs(os.path.dirname(out_abs), exist_ok=True)
            with open(out_abs, "w", encoding="utf-8") as f:
                f.write(content)

        if stripped_count > 0:
            files_modified += 1
            total_lines_stripped += stripped_count

    # 5. 报告
    total_files = len(source_files)
    if dry_run:
        print(f"\nDry-run: {total_files} files scanned, {files_modified} would be modified, {total_lines_stripped} lines would be stripped")
        if files_skipped:
            print(f"Skipped: {len(files_skipped)} files")
            for s in files_skipped[:10]:
                print(f"  - {s}")
    else:
        print(f"✅ Answer-card strip: {total_files} files scanned, {files_modified} files modified, {total_lines_stripped} lines stripped")
        if files_skipped:
            print(f"   Skipped: {len(files_skipped)} files")
        if total_lines_stripped > 0:
            print(f"   Output: {output_dir}/")

    # 写入 strip-manifest.json
    if not dry_run:
        manifest = {
            "schema_version": "1.0",
            "tool": "strip-answer-cards.py",
            "total_files_scanned": total_files,
            "files_modified": files_modified,
            "total_lines_stripped": total_lines_stripped,
            "output_dir": output_dir,
        }
        manifest_path = os.path.join(output_dir, ".strip-manifest.json")
        os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)

    sys.exit(0)


if __name__ == "__main__":
    main()
