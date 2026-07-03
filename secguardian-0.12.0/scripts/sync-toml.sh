#!/usr/bin/env python3
"""从 commands/*.md 自动生成 commands/gemini/*.toml"""

import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEMINI_DIR = os.path.join(ROOT, "commands", "gemini")
os.makedirs(GEMINI_DIR, exist_ok=True)

for cmd in ("secguard", "secaudit", "secreview"):
    md_file = os.path.join(ROOT, "commands", f"{cmd}.md")
    toml_file = os.path.join(GEMINI_DIR, f"{cmd}.toml")

    if not os.path.isfile(md_file):
        print(f"  ⚠️  {md_file} not found, skipping")
        continue

    with open(md_file) as f:
        content = f.read()

    # Extract frontmatter description
    m = re.search(r'^description:\s*"(.*?)"', content, re.MULTILINE)
    desc = m.group(1) if m else cmd

    # Extract body (everything after second ---)
    body_parts = content.split('---\n', 2)
    if len(body_parts) >= 3:
        body = body_parts[2]
    else:
        body = content

    # Write TOML (use repr-like escaping for triple-quoted string)
    with open(toml_file, 'w') as f:
        f.write(f'description = "{desc}"\n\n')
        f.write('prompt = """\n')
        f.write(body)
        if not body.endswith('\n'):
            f.write('\n')
        f.write('"""\n')

    size = os.path.getsize(toml_file)
    print(f"  {cmd}.toml → {size} bytes")

print(f"✅ All .toml files generated in {GEMINI_DIR}")
