#!/usr/bin/env python3
"""从 knowledge/{guard,audit,review}-rules/*.md 的 frontmatter
自动生成 knowledge/language-index.md"""

import os, sys, re, yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "knowledge", "language-index.md")

LANGUAGES = ["c", "cpp", "python", "java", "go", "javascript"]
DIRS = ["guard-rules", "audit-rules"]

def parse_languages(filepath):
    """从 .md 文件的 YAML frontmatter 提取 language 字段"""
    with open(filepath) as f:
        content = f.read()
    # Extract YAML frontmatter (between --- and ---)
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        return []
    try:
        fm = yaml.safe_load(m.group(1))
    except:
        return []
    if not fm or 'language' not in fm:
        return []
    langs = fm['language']
    if isinstance(langs, list):
        return [l.lower() for l in langs if isinstance(l, str)]
    if isinstance(langs, str):
        return [langs.lower()]
    return []

def collect_rules(language, rules_dir):
    """收集某个语言适用的所有规则"""
    rules = []
    dirpath = os.path.join(ROOT, "knowledge", rules_dir)
    if not os.path.isdir(dirpath):
        return rules
    for fname in sorted(os.listdir(dirpath)):
        if not fname.endswith('.md'):
            continue
        fp = os.path.join(dirpath, fname)
        langs = parse_languages(fp)
        name = rules_dir + '/' + fname[:-3]
        if not langs:  # 没 language = 全语言通用
            rules.append(name)
        elif language in langs:
            rules.append(name)
    return rules

def main():
    lines = ["# 语言规则索引（自动生成 — 请勿手工编辑）", ""]

    for lang in LANGUAGES:
        lines.append(f"## {lang}")
        all_rules = []
        for d in DIRS:
            all_rules.extend(collect_rules(lang, d))

        # review-rules: {lang}.md (fallback c→cpp since C uses C++ indexer)
        review_fallback = {"c": "cpp"}
        ef = review_fallback.get(lang, lang)
        review_file = os.path.join(ROOT, "knowledge", "review-rules", f"{ef}.md")
        if os.path.isfile(review_file):
            all_rules.append(f"review-rules/{ef}")

        if all_rules:
            # 每行 5 个
            for i in range(0, len(all_rules), 5):
                chunk = all_rules[i:i+5]
                lines.append(", ".join(chunk))
        lines.append("")

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"✅ Generated: {OUTPUT} ({len(lines)} lines)")

if __name__ == '__main__':
    main()
