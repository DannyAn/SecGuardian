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

set -eo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$PROJECT_ROOT/manifest.json"
export MANIFEST_FILE="$MANIFEST"

CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; fi

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: manifest.json not found at $MANIFEST"
    exit 1
fi

# ── Read canonical values from manifest.json ──
TMP_ENV=$(mktemp /tmp/secguardian-tokens.XXXXXX)
trap "rm -f $TMP_ENV" EXIT
python3 > "$TMP_ENV" << 'PYEOF'
import json, os
with open(os.environ['MANIFEST_FILE']) as f:
    d = json.load(f)
det = d['knowledge']['detectors']
ns = det['namespaces']
print(f'DETECTOR_COUNT={det["count"]}')
print(f'NAMESPACE_COUNT={len(ns)}')
for k, v in ns.items():
    print(f'NAMESPACE_{k.upper()}={v}')
PYEOF
# shellcheck disable=SC1090
source "$TMP_ENV"

# ── Token definitions (name:value pairs) ──
tokens=(
    "detector_count:$DETECTOR_COUNT"
    "namespace_count:$NAMESPACE_COUNT"
    "namespace:memory:$NAMESPACE_MEMORY"
    "namespace:concurrency:$NAMESPACE_CONCURRENCY"
    "namespace:system:$NAMESPACE_SYSTEM"
    "namespace:crypto:$NAMESPACE_CRYPTO"
    "namespace:web:$NAMESPACE_WEB"
    "namespace:error:$NAMESPACE_ERROR"
    "namespace:resource:$NAMESPACE_RESOURCE"
)

get_token_value() {
    local name="$1"
    for pair in "${tokens[@]}"; do
        if [ "${pair%%:*}" = "$name" ]; then
            echo "${pair#*:}"
            return 0
        fi
    done
    return 1
}

# ── Find all files containing @secguardian tokens ──
FILES_WITH_TOKENS=$(grep -rl '@secguardian:' "$PROJECT_ROOT" \
    --include="*.md" --include="*.json" --include="*.sh" 2>/dev/null | \
    grep -v '.codeagent\|node_modules\|dist/\|.git/\|.claude/\|.opencode/\|.gemini/\|docs/superpowers/' || true)

if [ -z "$FILES_WITH_TOKENS" ] && [ "$CHECK" -eq 0 ]; then
    echo "No @secguardian token markers found in project. Nothing to sync."
    exit 0
fi

PASS=0; FAIL=0
UPDATED=0

for file in $FILES_WITH_TOKENS; do
    rel="${file#$PROJECT_ROOT/}"
    for pair in "${tokens[@]}"; do
        token_name="${pair%%:*}"
        expected="${pair#*:}"
        marker="<!-- @secguardian:$token_name -->"

        if grep -qF "$marker" "$file" 2>/dev/null; then
            # Extract number: digits immediately before the marker, with optional space
            actual=$(grep -oE "[0-9]+[[:space:]]*<!-- @secguardian:$token_name -->" "$file" 2>/dev/null | \
                     sed -E 's/[[:space:]]*<!--.*-->//' | head -1 || echo "")
            if [ -z "$actual" ]; then
                echo "  ❌ $rel: marker for '$token_name' found but cannot parse number"
                FAIL=$((FAIL + 1))
            elif [ "$CHECK" -eq 1 ]; then
                if [ "$actual" != "$expected" ]; then
                    echo "  ❌ $rel: @secguardian:$token_name = $actual (expected $expected)"
                    FAIL=$((FAIL + 1))
                else
                    PASS=$((PASS + 1))
                fi
            else
                # ── Update mode ──
                if [ "$actual" != "$expected" ]; then
                    sed -i '' -E "s/[0-9]+[[:space:]]*$marker/$expected$marker/g" "$file"
                    echo "  ✓ $rel: @secguardian:$token_name $actual → $expected"
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
