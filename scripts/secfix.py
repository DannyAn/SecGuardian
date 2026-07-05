#!/usr/bin/env python3
"""
secfix.py - Generate unified diff patches from secguard/secreview findings.

Transforms findings with fix.before_code / fix.after_code into .patch files
that developers can review (git diff) and apply (git apply).

Usage:
    python3 scripts/secfix.py --findings-dir <path> --output <path>

Output:
    <output>/index.json          <- Patch manifest
    <output>/<detector>/*.patch   <- unified diffs
    <output>/<detector>/*.meta   <- patch metadata

Environment:
    SOURCE_ROOT: project root for relative file paths (default: cwd)
"""

import argparse
import json
import os
import re
import sys
import hashlib
import difflib
from pathlib import Path


def sha_prefix(s, length=12):
    return hashlib.sha256(s.encode()).hexdigest()[:length]


def slugify(path):
    stem = Path(path).stem
    return re.sub(r'[^a-zA-Z0-9_-]', '', stem)[:40]


def find_finding_files(findings_dir):
    results = []
    for f in sorted(findings_dir.rglob("*.json")):
        if f.name in ("index.json", "manifest.json", "summary.json"):
            continue
        results.append(f)
    return results


def load_finding(path):
    try:
        data = json.loads(path.read_text())
        finding = data.get("finding") or data
        if not finding.get("fix"):
            return None
        return finding
    except (json.JSONDecodeError, KeyError, IOError):
        return None


def resolve_source_file(file_path, source_root):
    p = Path(file_path)
    if p.is_absolute() and p.exists():
        return p
    p = source_root / file_path
    if p.exists():
        return p
    p = source_root / Path(file_path).name
    if p.exists():
        return p
    return None


def generate_unified_diff(before_code, after_code, file_path):
    before_lines = before_code.rstrip("\n").split("\n")
    after_lines = after_code.rstrip("\n").split("\n")
    diff = difflib.unified_diff(
        before_lines, after_lines,
        fromfile="a/" + file_path,
        tofile="b/" + file_path,
        fromfiledate="", tofiledate="", n=3
    )
    return "\n".join(diff)


def process_finding(finding, source_root, scan_id):
    detector = finding.get("detector", "unknown")
    file_path = (finding.get("file", "") or
                 finding.get("location", {}).get("file_path", ""))
    line = (finding.get("line", 0) or
            finding.get("location", {}).get("start_line", 0))
    cwe = finding.get("cwe", "")
    severity = finding.get("severity", "")
    fix = finding.get("fix", {})
    before = fix.get("before_code", "")
    after = fix.get("after_code", "")
    description = fix.get("description", "")

    if (not before and not after) or not file_path:
        return None

    identity = "{}:{}:{}:{}".format(detector, file_path, line, cwe)
    sha = sha_prefix(identity)
    slug = slugify(file_path)
    patch_name = "{}_{}-{}.patch".format(sha, slug, line)

    header_lines = [
        "# " + detector,
        "# Severity: {}  |  CWE: {}".format(severity, cwe),
        "# File: {}:{}".format(file_path, line),
        "# Source scan: " + scan_id,
        "# Description: " + description,
        "#",
        "# Apply: git apply " + patch_name,
    ]
    header = "\n".join(header_lines) + "\n"

    diff = generate_unified_diff(before, after, file_path)
    if not diff.strip():
        return None

    return detector, patch_name, header + diff + "\n"


def run(args):
    findings_dir = Path(args.findings_dir)
    output_dir = Path(args.output)
    source_root = Path(os.environ.get("SOURCE_ROOT", os.getcwd()))
    scan_id = args.scan_id or ""

    output_dir.mkdir(parents=True, exist_ok=True)

    if not findings_dir.is_dir():
        print("ERROR: Findings directory not found: " + str(findings_dir), file=sys.stderr)
        sys.exit(1)

    files = find_finding_files(findings_dir)
    if not files:
        print("WARN: No finding files found in " + str(findings_dir), file=sys.stderr)
        manifest = {"schema_version": "1.0", "tool": "secfix",
                    "total_patches": 0, "patches": [], "summary": {}}
        (output_dir / "index.json").write_text(json.dumps(manifest, indent=2))
        return

    patches_meta = []
    stats = {"processed": 0, "skipped": 0, "errors": 0}

    for f in files:
        try:
            finding = load_finding(f)
            if finding is None:
                stats["skipped"] += 1
                continue

            result = process_finding(finding, source_root, scan_id)
            if result is None:
                stats["skipped"] += 1
                continue

            detector, patch_name, patch_text = result

            det_dir = output_dir / detector
            det_dir.mkdir(parents=True, exist_ok=True)
            patch_path = det_dir / patch_name
            patch_path.write_text(patch_text)

            meta_entry = {
                "source_file": str(f),
                "detector": detector,
                "severity": finding.get("severity", ""),
                "cwe": finding.get("cwe", ""),
                "file": file_path or "",
                "line": line or 0,
                "description": description or "",
                "patch_file": str(patch_path),
            }
            meta_path = patch_path.with_name(patch_name.replace(".patch", ".patch.meta"))
            meta_path.write_text(json.dumps(meta_entry, indent=2))
            patches_meta.append(meta_entry)
            stats["processed"] += 1

        except Exception as e:
            stats["errors"] += 1
            print("WARN: Error processing {}: {}".format(f, e), file=sys.stderr)

    manifest = {
        "schema_version": "1.0",
        "tool": "secfix",
        "total_patches": len(patches_meta),
        "patches": patches_meta,
        "summary": {},
    }
    for p in patches_meta:
        sev = p.get("severity", "unknown")
        manifest["summary"][sev] = manifest["summary"].get(sev, 0) + 1

    (output_dir / "index.json").write_text(json.dumps(manifest, indent=2))

    print("")
    print("## secfix complete")
    print("")
    print("- Findings processed: {}".format(stats["processed"]))
    print("- Findings skipped:   {}".format(stats["skipped"]))
    print("- Patches generated:  {}".format(len(patches_meta)))
    print("- Output directory:   {}".format(output_dir))
    print("")
    print("Next steps:")
    print("  1. Review patches: ls {}/<detector>/*.patch".format(output_dir))
    print("  2. Apply:          git apply {}/<detector>/*.patch".format(output_dir))
    print("  3. Verify:         /secreview <path> <language>")
    print("")


def auto_discover_findings():
    """Auto-discover the latest scan findings directory."""
    import glob
    candidates = []
    for ext_dir in sorted(Path('.codeagent').glob('*-secguardian/scans/*/findings')):
        if ext_dir.is_dir():
            candidates.append(ext_dir)
    for ext_dir in sorted(Path('.codeagent').glob('*-secguardian/scans/*/findings/')):
        if ext_dir.is_dir():
            candidates.append(ext_dir)
    if candidates:
        # Sort by path name (contains timestamp) and take latest
        candidates.sort(reverse=True)
        return str(candidates[0])
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Generate patches from security findings. "
                    "Zero arguments: auto-discovers latest scan.")
    parser.add_argument("--findings-dir", "-f", default=None,
                        help="Path to findings/ directory (default: auto-discover)")
    parser.add_argument("--output", "-o", default=None,
                        help="Output directory for patches (default: auto)")
    parser.add_argument("--scan-id", "-s", default="",
                        help="Source scan ID (for traceability)")
    args = parser.parse_args()

    if not args.findings_dir:
        discovered = auto_discover_findings()
        if not discovered:
            print("ERROR: No findings directory found.", file=sys.stderr)
            print("  Provide one with: --findings-dir <path>", file=sys.stderr)
            print("  Or run /secreview or /secaudit first to generate findings.", file=sys.stderr)
            sys.exit(1)
        args.findings_dir = discovered
        print(f"Auto-discovered findings: {discovered}")

    if not args.output:
        # Default: output to 'fixes/' next to the findings directory
        findings_path = Path(args.findings_dir)
        # If findings_dir is .../scans/<id>/findings, output to .../scans/<id>/fixes
        if findings_path.parent.parent.name == 'scans':
            args.output = str(findings_path.parent / 'fixes')
        else:
            args.output = str(findings_path / '../fixes')
        print(f"Output directory: {args.output}")

    run(args)


if __name__ == "__main__":
    main()
