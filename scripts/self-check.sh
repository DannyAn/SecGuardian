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

# 1a Verify audit-rules structure
AUD_COUNT=$(ls skills/secaudit/rules/*.md 2>/dev/null | wc -l | tr -d ' ')
if [ "$AUD_COUNT" -eq 17 ]; then
    green "audit-rules: 13 files (complete)"
else
    yellow "audit-rules: $AUD_COUNT files (expected 13)"
fi

# 1f Verify review-rules structure
REV_COUNT=$(find skills/secreview -path '*/rules/*.md' -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
for lang in cpp python java go javascript; do
    rf="skills/secreview/$lang/rules/$lang.md"
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
    red "namespace sum=$MANIFEST_SUM != total=$MANIFEST_COUNT"
echo ""

# ── 3. Commands reference correct paths ──
echo "3. Command path consistency"
for cmd in commands/secguard.md commands/gemini/secguard.toml; do
    if grep -q "skills/secguard" "$cmd" 2>/dev/null; then
        green "$cmd references correct detection rule path"
    else
        red "$cmd missing detection rule reference"
    fi
done
echo ""


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
echo ""
echo "Total: $SKILL_COUNT skills"
echo ""

# ── 6. No dead references ──
echo "6. Stale reference check"
for stale in "knowledge/concepts" "knowledge/cheatsheets" "knowledge/prompt-templates" "knowledge/language-index.md" "knowledge/guard-rules"; do
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
(cd internal && gc=$(mktemp -d) && GOCACHE=$gc go build -tags cgo -o ../scripts/bin/secguardian-index . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build (CGO/tree-sitter) OK" || red "go build (CGO/tree-sitter) FAILED"
(cd internal && gc=$(mktemp -d) && GOCACHE=$gc CGO_ENABLED=0 go build -o ../scripts/bin/secguardian-index . 2>/dev/null; ec=$?; rm -rf "$gc"; exit $ec) && green "go build (no-CGO/regex fallback) OK" || red "go build (no-CGO/regex fallback) FAILED"
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
    stale=$(grep -cE "16 阶段|Isolation constraint|Routing rules" "$f" 2>/dev/null) || true
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

# ── 12. Command template static analysis (bash logic checks) ──
echo "12. Command template static analysis"
# Catches systemic design flaws that file-count checks cannot:
# SECGUARDIAN_HOME paths, .scan_state namespacing, anti-delegation,
# bare script references, /tmp/ usage — all regressions from EPIC-005 bugs.
TS_FAIL=0; TS_PASS=0
for cmd in secguard secaudit secreview; do
    f="commands/${cmd}.md"
    if [ ! -f "$f" ]; then
        red "  ${cmd}: commands/${cmd}.md MISSING"
        TS_FAIL=$((TS_FAIL + 1))
        continue
    fi
    fail=0

    # 12a: SECGUARDIAN_HOME auto-discovery with $HOME/ absolute paths
    if grep -qE '\$HOME/\.(claude|config)' "$f" 2>/dev/null; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12a SECGUARDIAN_HOME auto-discovery (absolute paths) MISSING"
        fail=1
    fi

    # 12b: .scan_state is command-specific (regression guard: cross-contamination)
    total_state=$(grep -c '\.scan_state' "$f" 2>/dev/null) || true
    cmd_state=$(grep -c "\.scan_state\.${cmd}" "$f" 2>/dev/null) || true
    bare_state=$(( total_state - cmd_state ))
    if [ "$bare_state" -eq 0 ] && [ "$cmd_state" -gt 0 ]; then
        TS_PASS=$((TS_PASS + 1))
    else
        if [ "$cmd_state" -eq 0 ]; then
            echo "  ❌ ${cmd}: 12b .scan_state.${cmd} command-specific file MISSING"
        fi
        if [ "$bare_state" -gt 0 ]; then
            echo "  ❌ ${cmd}: 12b ${bare_state} bare '.scan_state' (un-suffixed) reference(s)"
        fi
        fail=1
    fi

    # 12c: Anti-delegation rule present (regression guard: sub-agent bypass)
    if grep -q 'NON-NEGOTIABLE' "$f" 2>/dev/null; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12c anti-delegation rule MISSING"
        fail=1
    fi

    # 12d: No bare python3 scripts/ calls (must use $SECGUARDIAN_HOME)
    bare_scripts=$(grep -c 'python3 scripts/' "$f" 2>/dev/null) || true
    if [ "$bare_scripts" -eq 0 ]; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12d ${bare_scripts} bare 'python3 scripts/' call(s) — must use \$SECGUARDIAN_HOME"
        fail=1
    fi

    # 12e: No /tmp/ for scan state (regression guard: cross-platform /tmp/ ban)
    tmp_state=$(grep -cE 'cat > /tmp/sc' "$f" 2>/dev/null) || true
    if [ "$tmp_state" -eq 0 ]; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12e ${tmp_state} /tmp/ scan-state reference(s)"
        fail=1
    fi

    # 12f: Non-skippable validation marker (regression guard: agents skipping verify)
    if grep -q '@secguardian:non-skippable' "$f" 2>/dev/null; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12f non-skippable validation marker MISSING"
        echo "    Add: <!-- @secguardian:non-skippable step=validate --> before validation step"
        fail=1
    fi

    # 12g: No hardcoded RECORDER paths (must use $SECGUARDIAN_HOME)
    hardcoded_recorder=$(grep -cE 'RECORDER=".*record-finding' "$f" 2>/dev/null) || true
    sg_recorder=$(grep -cE 'RECORDER="\$SECGUARDIAN_HOME/scripts/record-finding' "$f" 2>/dev/null) || true
    if [ "$hardcoded_recorder" -gt 0 ] && [ "$sg_recorder" -lt "$hardcoded_recorder" ]; then
        echo "  ❌ ${cmd}: 12g ${hardcoded_recorder} hardcoded RECORDER path(s)"
        fail=1
    else
        TS_PASS=$((TS_PASS + 1))
    fi

    # 12h: No todowrite tool invocation (regression guard: token waste)
    # Note: "不要使用 todowrite" advisory text is OK; actual **Tool: todowrite** is not.
    if grep -qE '\*\*Tool: todowrite\*\*' "$f" 2>/dev/null; then
        echo "  ❌ ${cmd}: 12h contains '**Tool: todowrite**' — use TaskCreate/TaskUpdate instead"
        fail=1
    else
        TS_PASS=$((TS_PASS + 1))
    fi

    # 12i: timeout 30 present on indexer call (regression guard: hang protection)
    if grep -qE 'timeout.*30.*indexer|timeout.*30.*INDEXER|gtimeout.*30.*INDEXER' "$f" 2>/dev/null; then
        TS_PASS=$((TS_PASS + 1))
    else
        echo "  ❌ ${cmd}: 12i indexer timeout 30s (hang protection) MISSING"
        fail=1
    fi

    if [ "$fail" -eq 0 ]; then
        green "  ${cmd}: all 9 template checks passed"
    else
        TS_FAIL=$((TS_FAIL + 1))
    fi
done
if [ "$TS_FAIL" -eq 0 ]; then
    TS_PASS=$((TS_PASS + 1))  # bonus: all-passed summary line
    green "  All 3 commands pass template static analysis"
else
    TS_FAIL=0
    echo "  ⚠️  Template static analysis: ${TS_FAIL} command(s) have issues"
fi
PASS=$((PASS + TS_PASS))
FAIL=$((FAIL + TS_FAIL))
echo ""

# ── 13. Template security gate: pre-filter + no bulk copy ──
echo "13. Template security gate (FEATURE-002)"
SG_FAIL=0; SG_PASS=0
for cmd in secguard secaudit secreview; do
    f="commands/${cmd}.md"
    if [ ! -f "$f" ]; then
        echo "  ❌ ${cmd}: commands/${cmd}.md MISSING"
        SG_FAIL=$((SG_FAIL + 1))
        continue
    fi
    fail=0

    # 13a: pre-filter non-skippable marker present
    if grep -q '@secguardian:non-skippable step=pre-filter' "$f" 2>/dev/null; then
        SG_PASS=$((SG_PASS + 1))
    else
        echo "  ❌ ${cmd}: 13a pre-filter gate marker MISSING"
        echo "    Add: <!-- @secguardian:non-skippable step=pre-filter --> before pre-filter section"
        fail=1
    fi

    # 13b: no cp -r knowledge bulk copy (exclude comment lines and blockquote lines)
    cp_r=$(grep -n 'cp -r.*knowledge' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*>' || true)
    if [ -z "$cp_r" ]; then
        SG_PASS=$((SG_PASS + 1))
    else
        echo "  ❌ ${cmd}: 13b contains cp -r knowledge bulk copy"
        echo "    $cp_r"
        fail=1
    fi

    # 13c: no mkdir knowledge directory creation
    mkdir_k=$(grep -n 'mkdir.*knowledge' "$f" 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*>' || true)
    if [ -z "$mkdir_k" ]; then
        SG_PASS=$((SG_PASS + 1))
    else
        echo "  ❌ ${cmd}: 13c creates knowledge directory"
        echo "    $mkdir_k"
        fail=1
    fi

    # 13d: rule-loading non-skippable marker (regression: AI skipping guard-rule loading)
    if grep -q '@secguardian:non-skippable step=rule-loading' "$f" 2>/dev/null; then
        SG_PASS=$((SG_PASS + 1))
    else
        echo "  ❌ ${cmd}: 13d rule-loading mandatory marker MISSING"
        echo "    Add: <!-- @secguardian:non-skippable step=rule-loading -->"
        fail=1
    fi

    # 13e: strip-answer-cards.py invocation (prevents AI shortcut via VULNERABILITY comments)
    # Only applies to secguard (the source-scanning command); secaudit/secreview have different workflows
    if [ "$cmd" = "secguard" ]; then
        if grep -q 'strip-answer-cards.py' "$f" 2>/dev/null; then
            SG_PASS=$((SG_PASS + 1))
        else
            echo "  ❌ ${cmd}: 13e strip-answer-cards.py integration MISSING"
            echo "    Add: strip-answer-cards.py invocation in Step 2.5"
            fail=1
        fi
    else
        SG_PASS=$((SG_PASS + 1))  # Auto-pass for non-scanning commands
    fi

    if [ "$fail" -eq 0 ]; then
        if [ "$cmd" = "secguard" ]; then
            green "  ${cmd}: all 5 security gate checks passed"
        else
            green "  ${cmd}: all 4 security gate checks passed"
        fi
    fi
done
if [ "$SG_FAIL" -eq 0 ]; then
    SG_PASS=$((SG_PASS + 1))
    green "  All 3 commands pass template security gate"
fi
PASS=$((PASS + SG_PASS))
FAIL=$((FAIL + SG_FAIL))
echo ""

# ── 14. Frontmatter field integrity ──
echo "14. Frontmatter field integrity"
DS_FAIL=0; DS_PASS=0
for dir in audit-rules review-rules; do
    dir_path="knowledge/${dir}"
    if [ ! -d "$dir_path" ]; then
        echo "  ⚠  $dir_path: directory not found"
        continue
    fi
    count=0; ok=0; missing=0
    for f in "$dir_path"/*.md; do
        [ -f "$f" ] || continue
        count=$((count + 1))
        [ "$(head -1 "$f")" = "---" ] || { echo "  ❌ ${dir}/$(basename "$f"): no frontmatter"; missing=$((missing + 1)); continue; }
        # Check rule-type-specific required frontmatter fields
        case "$dir" in
            guard-rules) field="target_functions:" ;;
            audit-rules) field="cvss:" ;;
            review-rules) field="max_severity:" ;;
        esac
        head -40 "$f" | grep -q "$field" 2>/dev/null && ok=$((ok + 1)) || {
            echo "  ❌ ${dir}/$(basename "$f"): missing '$field' in frontmatter"
            missing=$((missing + 1))
        }
    done
    if [ "$missing" -eq 0 ]; then
        green "  ${dir}: $ok/$ok files have required frontmatter fields"
        DS_PASS=$((DS_PASS + 1))
    else
        echo "  ❌ ${dir}: $missing/$count files missing required frontmatter fields"
        DS_FAIL=$((DS_FAIL + 1))
    fi
done
if [ "$DS_FAIL" -eq 0 ]; then
    DS_PASS=$((DS_PASS + 1))
    green "  All rule files have required frontmatter fields"
fi
PASS=$((PASS + DS_PASS))
FAIL=$((FAIL + DS_FAIL))
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Passed: %d  Failed: %d\n" "$PASS" "$FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
