#!/usr/bin/env python3
"""Validate benchmark anchors and declared detector ownership before scoring."""
import argparse
import json
import os
import re
import sys


def normalize(text):
    return re.sub(r"\s+", " ", text.replace("...", "")).strip().lower()


def validate(expected_path, source_root, rules_dir):
    with open(expected_path, encoding="utf-8") as f:
        expected = json.load(f)
    rule_text = ""
    for current, _dirs, files in os.walk(rules_dir):
        for name in files:
            if name == "rule.md":
                with open(os.path.join(current, name), encoding="utf-8") as f:
                    rule_text += f.read() + "\n"
    errors = []
    for case in expected.get("test_cases", []):
        path = os.path.join(source_root, case["file"].removeprefix("src/"))
        if not os.path.isfile(path):
            errors.append({"id": case["id"], "error": "source file missing", "path": path})
            continue
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        line = int(case.get("line", 0))
        if line < 1 or line > len(lines):
            errors.append({"id": case["id"], "error": "line out of range", "line": line,
                           "max_line": len(lines)})
        else:
            needle = normalize(case.get("code", ""))
            window = normalize(" ".join(lines[max(0, line - 3):min(len(lines), line + 2)]))
            tokens = [token for token in re.findall(r"[a-zA-Z_]\w*", needle) if len(token) >= 4]
            if tokens and not any(token.lower() in window for token in tokens[:3]):
                errors.append({"id": case["id"], "error": "code does not match anchor", "line": line})
        detector = case.get("detector", "")
        if detector and detector not in rule_text:
            errors.append({"id": case["id"], "error": "declared detector has no C++ rule", "detector": detector})
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected", required=True)
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--rules-dir", required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    errors = validate(args.expected, args.source_root, args.rules_dir)
    if args.json:
        print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    else:
        for error in errors:
            print("%s: %s" % (error["id"], error["error"]))
        print("Benchmark: %s (%d errors)" % ("VALID" if not errors else "INVALID", len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
