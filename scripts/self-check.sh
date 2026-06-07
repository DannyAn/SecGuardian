#!/bin/bash
# SecGuardian — Self-Verification Script
# Catches design inconsistencies before the user does.
# Usage: bash scripts/self-check.sh

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0; FAIL=0
green() { echo "  ✅ $1"; PASS=$((PASS+1)); }
red()   { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SecGuardian Self-Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── 1. Detector filename ↔ index consistency ──
echo "1. Detector filename consistency"
INDEX="skills/secguard/cpp/references/detector-index.md"
DET_DIR="knowledge/detectors"

# Extract namespace.name from table rows (lines starting with | number |)
INDEX_ENTRIES=$(grep '^| [0-9]' "$INDEX" | grep -o '\`[a-z][a-z-]*\.[a-z][a-z-]*\`' | tr -d '\`' | grep '\.' | sort -u)
INDEX_COUNT=$(echo "$INDEX_ENTRIES" | wc -l | tr -d ' ')

while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    ns="${entry%%.*}"; name="${entry##*.}"
    expected="$DET_DIR/${ns}-${name}.md"
    if [ -f "$expected" ]; then
        green "$entry -> $expected"
    else
        red "$entry -> $expected MISSING"
    fi
done <<< "$INDEX_ENTRIES"

for f in "$DET_DIR"/*.md; do
    base=$(basename "$f" .md)
    ns="${base%%-*}"; name="${base#*-}"
    ns_dot="${ns}.${name}"
    if ! echo "$INDEX_ENTRIES" | grep -qxF "$ns_dot"; then
        red "ORPHAN: $f (no matching index entry for $ns_dot)"
    fi
done
echo ""

# ── 2. Manifest counts vs reality ──
echo "2. Manifest count consistency"
MANIFEST_COUNT=$(jq '.knowledge.detectors.count' manifest.json)
ACTUAL_COUNT=$(ls "$DET_DIR"/*.md | wc -l | tr -d ' ')
[ "$MANIFEST_COUNT" = "$ACTUAL_COUNT" ] && \
    green "manifest.json count=$MANIFEST_COUNT matches directory count=$ACTUAL_COUNT" || \
    red "manifest.json count=$MANIFEST_COUNT != directory count=$ACTUAL_COUNT"

MANIFEST_SUM=$(jq '[.knowledge.detectors.namespaces | to_entries[].value] | add' manifest.json)
[ "$MANIFEST_SUM" = "$MANIFEST_COUNT" ] && \
    green "namespace sum=$MANIFEST_SUM matches total=$MANIFEST_COUNT" || \
    red "namespace sum=$MANIFEST_SUM != total=$MANIFEST_COUNT"
echo ""

# ── 3. Commands reference correct paths ──
echo "3. Command path consistency"
for cmd in commands/secguard.md commands/gemini/secguard.toml; do
    if grep -q "skills/secguard/cpp/references/detector-index.md" "$cmd" 2>/dev/null; then
        green "$cmd references correct detector-index path"
    elif grep -q "skills/secguard-cpp" "$cmd" 2>/dev/null; then
        red "$cmd references OLD path skills/secguard-cpp"
    else
        red "$cmd missing detector-index reference"
    fi
done
echo ""

# ── 4. Namespace filter coverage ──
echo "4. Namespace filter coverage"
INDEX_NS=$(echo "$INDEX_ENTRIES" | sed 's/\..*//' | sort -u)
CMD_NS=$(grep "secguard \./src " commands/secguard.md | grep -o '[a-z][a-z]*\.\*' | sed 's/\.\*//' | sort -u)
for ns in $CMD_NS; do
    if echo "$INDEX_NS" | grep -qxF "$ns"; then
        count=$(echo "$INDEX_ENTRIES" | grep -c "^${ns}\." || echo 0)
        green "filter '$ns.*' -> $count detectors"
    else
        red "filter '$ns.*' -> NAMESPACE NOT FOUND"
    fi
done
echo ""

# ── 5. Skills structure ──
echo "5. Skills structure"
SKILL_COUNT=0
for cmd_dir in skills/secaudit skills/secguard skills/secreview; do
    if [ -d "$cmd_dir" ]; then
        n=$(ls -d "$cmd_dir"/*/ 2>/dev/null | wc -l | tr -d ' ')
        green "$cmd_dir/ ($n skills)"
        SKILL_COUNT=$((SKILL_COUNT + n))
    else
        red "$cmd_dir/ MISSING"
    fi
done
echo "  Total: $SKILL_COUNT skills"
echo ""

# ── 6. No dead references ──
echo "6. Stale reference check"
for stale in "knowledge/concepts" "knowledge/cheatsheets" "knowledge/prompt-templates"; do
    refs=$(grep -rl "$stale" commands/ skills/ --include="*.md" --include="*.toml" 2>/dev/null || true)
    if [ -n "$refs" ]; then
        red "Stale reference to '$stale' in: $refs"
    else
        green "No stale '$stale' references"
    fi
done
echo ""

# ── 7. threat-catalog consistency vs manifest ──
echo "7. Threat catalog vs manifest"
MANIFEST_NS=$(python3 -c "
import json
with open('manifest.json') as f:
    ns = json.load(f)['knowledge']['detectors']['namespaces']
print(json.dumps(ns))
")
CATALOG_NS=$(python3 -c "
import re, json
with open('knowledge/threat-catalog.md') as f:
    content = f.read()
sections = re.findall(r'## .*?\((\w+)\).*?— (\d+) 个', content)
ns_counts = {}
for ns, count in sections:
    ns_counts[ns] = int(count)
print(json.dumps(ns_counts))
")
MISMATCH=$(python3 -c "
import json, sys
manifest = json.loads('''$MANIFEST_NS''')
catalog = json.loads('''$CATALOG_NS''')
mismatch = False
for ns, expected in manifest.items():
    actual = catalog.get(ns, 0)
    if actual != expected:
        print(f'  ❌ {ns}: manifest={expected}, catalog={actual}')
        mismatch = True
    else:
        print(f'  ✅ {ns}: {expected}')
if not mismatch:
    print('  ✅ All namespace counts match manifest')
sys.exit(0 if not mismatch else 1)
")
if [ $? -eq 0 ]; then
    green "threat-catalog.md consistent with manifest.json"
else
    red "threat-catalog.md out of sync with manifest.json — update counts and sections"
fi
echo ""

# ── 8. Go compilation ──
echo "7. Go compilation"
(cd internal && go build -o /dev/null . 2>/dev/null) && green "go build OK" || red "go build FAILED"
(cd internal && CGO_ENABLED=0 go build -o /dev/null . 2>/dev/null) && green "go build (no-CGO) OK" || red "go build (no-CGO) FAILED"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Passed: %d  Failed: %d\n" "$PASS" "$FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
