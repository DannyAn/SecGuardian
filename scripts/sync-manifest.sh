#!/bin/bash
# sync-manifest.sh — Sync @secguardian token markers across project files from manifest.json
#
# Token format: NNN<!-- @secguardian:token_name -->
# Each token is a number followed by an HTML comment identifying the key.
# sync-manifest.sh reads the authoritative value from manifest.json and
# updates the number before the marker.
#
# Usage:
#   bash scripts/sync-manifest.sh           Update all files in-place
#   bash scripts/sync-manifest.sh --check   CI mode: verify only, exit 1 on mismatch

set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$PROJECT_ROOT/manifest.json"

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; fi

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: manifest.json not found at $MANIFEST"
    exit 1
fi

# ── Read canonical values from manifest.json ──
eval "$(python3 -c "
import json, sys
with open('$MANIFEST') as f:
    d = json.load(f)
det = d['knowledge']['detectors']
ns = det['namespaces']
print(f'DETECTOR_COUNT={det[\"count\"]}')
print(f'NAMESPACE_COUNT={len(ns)}')
for k, v in ns.items():
    print(f'NAMESPACE_{k.upper()}={v}')
")"

# ── Token definitions ──
declare -A TOKENS=(
    ["detector_count"]="$DETECTOR_COUNT"
    ["namespace_count"]="$NAMESPACE_COUNT"
    ["namespace:memory"]="$NAMESPACE_MEMORY"
    ["namespace:concurrency"]="$NAMESPACE_CONCURRENCY"
    ["namespace:system"]="$NAMESPACE_SYSTEM"
    ["namespace:crypto"]="$NAMESPACE_CRYPTO"
    ["namespace:web"]="$NAMESPACE_WEB"
    ["namespace:error"]="$NAMESPACE_ERROR"
    ["namespace:resource"]="$NAMESPACE_RESOURCE"
)

# ── Find all files containing @secguardian tokens ──
FILES_WITH_TOKENS=$(grep -rl '@secguardian:' "$PROJECT_ROOT" \
    --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | \
    grep -v '.codeagent\|node_modules\|dist/\|.git/\|.claude/\|.opencode/\|.gemini/' || true)

if [ -z "$FILES_WITH_TOKENS" ] && [ "$CHECK" -eq 0 ]; then
    echo "No @secguardian token markers found in project. Nothing to sync."
    exit 0
fi

PASS=0; FAIL=0
UPDATED=0

for file in $FILES_WITH_TOKENS; do
    rel="${file#$PROJECT_ROOT/}"
    for token_name in "${!TOKENS[@]}"; do
        expected="${TOKENS[$token_name]}"
        marker="@secguardian:$token_name"

        if grep -q "$marker" "$file" 2>/dev/null; then
            if [ "$CHECK" -eq 1 ]; then
                # ── CI mode: verify correctness ──
                actual=$(grep -oP "[0-9]+(?=<!-- $marker -->)" "$file" 2>/dev/null || echo "")
                if [ -z "$actual" ]; then
                    echo "  ❌ $rel: marker '$marker' found but no number before it"
                    FAIL=$((FAIL + 1))
                elif [ "$actual" != "$expected" ]; then
                    echo "  ❌ $rel: @secguardian:$token_name = $actual (expected $expected)"
                    FAIL=$((FAIL + 1))
                else
                    PASS=$((PASS + 1))
                fi
            else
                # ── Update mode: replace number before marker ──
                before=$(grep -o "[0-9]\+<!-- $marker -->" "$file" 2>/dev/null | head -1 || echo "")
                if [ -n "$before" ]; then
                    sed -i '' -E "s/[0-9]+<!-- $marker -->/$expected<!-- $marker -->/g" "$file"
                    UPDATED=$((UPDATED + 1))
                fi
            fi
        fi
    done
done

# ── Report ──
if [ "$CHECK" -eq 1 ]; then
    if [ "$FAIL" -eq 0 ] && [ "$PASS" -eq 0 ]; then
        echo "  (no token markers found in project files)"
        exit 0
    fi
    echo "  Token check: $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ] || exit 1
else
    echo "  Synced $UPDATED token occurrences across $(echo "$FILES_WITH_TOKENS" | wc -l | tr -d ' ') files."
fi
