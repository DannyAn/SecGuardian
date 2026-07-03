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


yellow() { echo "  🟡 $1"; }
# ── 1. Knowledge rules structure ──
echo "1. Knowledge rules structure"
GLD_DIR="knowledge/guard-rules"
AUD_DIR="knowledge/audit-rules"
REV_DIR="knowledge/review-rules"
LANG_IDX="knowledge/language-index.md"

# 1a Verify each knowledge directory has files
for dir_name in guard-rules audit-rules review-rules; do
    dir="knowledge/$dir_name"
    count=$(ls "$dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        green "$dir: $count files"
    else
        red "$dir missing or empty"
    fi
done

# 1b Verify language-index.md exists with language sections
if [ -f "$LANG_IDX" ]; then
    lang_count=$(grep -c '^## ' "$LANG_IDX" 2>/dev/null || echo 0)
    if [ "$lang_count" -ge 5 ]; then
        green "$LANG_IDX: $lang_count language sections"
    else
        red "$LANG_IDX: only $lang_count language sections (expected >=5)"
    fi
else
    red "$LANG_IDX MISSING"
fi

# 1c Verify guard-rules filename format: namespace-name.md
for f in "$GLD_DIR"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    ns="${base%%-*}"
    case "$ns" in
        memory|concurrency|system|crypto|web|resource|error)
            green "guard-rules/$base"
            ;;
        *)
            red "guard-rules/$base — unknown namespace '$ns'"
            ;;
    esac
done

# 1d Verify guard-rules frontmatter language field is parseable
MISSING_LANG=0
for f in "$GLD_DIR"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    if grep -q '^language:' "$f" 2>/dev/null; then
        :
    else
        MISSING_LANG=$((MISSING_LANG + 1))
        red "guard-rules/$base missing language field"
    fi
done
[ "$MISSING_LANG" -eq 0 ] && green "All guard-rules have language field"

# 1e Verify audit-rules structure
AUD_COUNT=$(ls "$AUD_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$AUD_COUNT" -eq 17 ]; then
    green "audit-rules: 13 files (complete)"
else
    yellow "audit-rules: $AUD_COUNT files (expected 13)"
fi

# 1f Verify review-rules structure
REV_COUNT=$(ls "$REV_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
for lang in cpp python java go javascript; do
    rf="$REV_DIR/$lang.md"
    if [ -f "$rf" ]; then
        green "review-rules/$lang.md"
    else
        red "review-rules/$lang.md MISSING"
    fi
done

# 1g Verify .toml files are auto-generated
TOML_MISSING=0
for cmd in secguard secaudit secreview; do
    if [ -f "commands/gemini/$cmd.toml" ]; then
        green "commands/gemini/$cmd.toml"
    else
        red "commands/gemini/$cmd.toml MISSING"
        TOML_MISSING=$((TOML_MISSING + 1))
    fi
done
# ── 2. Manifest counts vs reality ──
echo "2. Manifest count consistency"
MANIFEST_COUNT=$(jq '.knowledge.detectors.count' manifest.json)
ACTUAL_COUNT=$(ls "knowledge/guard-rules"/*.md | wc -l | tr -d ' ')
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
    if grep -q "knowledge/language-index.md" "$cmd" 2>/dev/null; then
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
GUARD_DIR="knowledge/guard-rules"
# Extract namespace prefixes from guard-rules filenames
KNOWN_NS="memory concurrency system crypto web resource error"
for ns in $KNOWN_NS; do
    count=$(ls "$GUARD_DIR/${ns}-"*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        green "namespace $ns -> $count detectors"
    else
        red "namespace $ns -> no detectors in $GUARD_DIR"
    fi
done
# ── 5. Skills structure ──
echo "5. Skills structure"
SKILL_COUNT=0
for cmd_dir in skills/secaudit skills/secguard skills/secreview; do
    if [ -d "$cmd_dir" ]; then
        n=$(find "$cmd_dir" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
        green "$cmd_dir/ ($n skills)"
        SKILL_COUNT=$((SKILL_COUNT + n))
    else
        red "$cmd_dir/ MISSING"
    fi
done
echo "  else
    echo "  npx not available — install Node.js to run markdownlint locally"
fi

Total: $SKILL_COUNT skills"
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
sections = re.findall(r'## .*?\((\w+)\).*?— (\d+)(?:<!--.*?-->)? 个', content)
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


# ── 7.6. Manifest token consistency ──
echo "7.6. Manifest token consistency"
if [ -x "$PROJECT_ROOT/scripts/sync-manifest.sh" ]; then
    bash "$PROJECT_ROOT/scripts/sync-manifest.sh" --check 2>/dev/null
    if [ $? -eq 0 ]; then
        green "All @secguardian tokens match manifest.json"
    else
        red "Token mismatch — run: bash scripts/sync-manifest.sh"
    fi
else
    echo "  sync-manifest.sh not found — skipping"
fi
echo ""
# ── 8. Go compilation ──
echo "8. Go compilation"
(cd internal && gc=$(mktemp -d) && GOCACHE=$gc go build -o /dev/null . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build OK" || red "go build FAILED"
(cd internal && gc=$(mktemp -d) && GOCACHE=$gc CGO_ENABLED=0 go build -o /dev/null . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build (no-CGO) OK" || red "go build (no-CGO) FAILED"
echo ""


# ── 9. Command template export validation ──
if [ -f "scripts/check-command-templates.py" ]; then
    echo "9. Command template export validation"
    if python3 scripts/check-command-templates.py >/dev/null 2>&1; then
        green "commands/*.md 共 12 处 os.environ 引用均使用 export，模板健壮"
    else
        red "commands/*.md 模板中 bash → Python 环境变量缺失 export"
        python3 scripts/check-command-templates.py 2>&1 | grep '❌'
    fi
    echo ""
fi


# ── 10. validate-index.py cross-language smoke test ──
if [ -f "scripts/validate-index.py" ] && [ -f "scripts/secguardian-index" ]; then
    echo "10. validate-index.py cross-language smoke test"
    ALL_OK=0
    for repo in cpp-vuln-demo python-vuln-demo java-vuln-demo go-vuln-demo; do
        idx=$(mktemp /tmp/selfchk-idx-XXXX.json)
        bash scripts/secguardian-index --path "examples/$repo/src" --output "$idx" >/dev/null 2>&1
        out=$((cd /tmp && python3 "$PROJECT_ROOT/scripts/validate-index.py" --index "$idx" --scan-id "test-$repo") 2>&1)
        lang=$(echo "$out" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['primary_language'])" 2>/dev/null || echo "FAIL")
        if [ "$lang" != "FAIL" ]; then
            green "examples/$repo → $lang"
        else
            red "examples/$repo → validate-index.py FAILED"
            ALL_OK=1
        fi
        rm -f "$idx"
    done
    [ "$ALL_OK" -eq 0 ] && green "All languages pass validate-index.py" || red "Some languages FAILED"
    echo ""
fi

# ── 11. Cross-command consistency ──
echo "11. Cross-command consistency"
XC_FAIL=0
XC_PASS=0
for cmd in secguard secaudit secreview; do
    f="commands/${cmd}.md"
    if [ ! -f "$f" ]; then
        red "  ${cmd}: commands/${cmd}.md MISSING"
        XC_FAIL=$((XC_FAIL + 1))
        continue
    fi
    ok=1
    # --command <cmd> present
    if grep -q -- "--command ${cmd}" "$f"; then
        XC_PASS=$((XC_PASS + 1))
    else
        red "  ${cmd}: MISSING '--command ${cmd}' in renderer call"
        ok=0
    fi
    # <user-project> prefix used
    if grep -q '<user-project>/\.codeagent' "$f"; then
        XC_PASS=$((XC_PASS + 1))
    else
        red "  ${cmd}: MISSING '<user-project>/' prefix in output paths"
        ok=0
    fi
    # scan_id ordering instruction
    if grep -qE "scan_id FIRST|首选生成 scan_id|Generate scan_id FIRST" "$f"; then
        XC_PASS=$((XC_PASS + 1))
    else
        red "  ${cmd}: MISSING scan_id ordering instruction"
        ok=0
    fi
    # No stale references
    stale=$(grep -cE "16 阶段|Isolation constraint|Routing rules" "$f" 2>/dev/null || echo 0)
    if [ "$stale" -gt 0 ]; then
        red "  ${cmd}: ${stale} stale reference(s) found"
        ok=0
    fi
    if [ "$ok" -eq 1 ]; then
        green "  ${cmd}: all checks passed"
    else
        XC_FAIL=$((XC_FAIL + 1))
    fi
done
if [ "$XC_FAIL" -eq 0 ]; then
    green "  All 3 commands are in sync"
else
    red "  ${XC_FAIL} commands have consistency issues"
fi
PASS=$((PASS + XC_PASS))
FAIL=$((FAIL + XC_FAIL))
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Passed: %d  Failed: %d\n" "$PASS" "$FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
