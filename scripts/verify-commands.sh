#!/bin/bash
# SecGuardian — Cross-Platform Command Verification
#
# Static checks for platform-separated command files:
# 1. File parity — all commands exist in both claude/ and opencode/
# 2. Forbidden words — no platform-specific tool references in wrong platform
# 3. Platform frontmatter — correct platform field in each file
#
# Usage: bash scripts/verify-commands.sh
# Called by: package.sh (build-time verification)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/commands/claude"
OPENCODE_DIR="$PROJECT_ROOT/commands/opencode"
EXIT_CODE=0

# Color helpers
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "${GREEN}  ✓${NC} $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; EXIT_CODE=1; }

echo "==> SecGuardian Cross-Platform Command Verification"

# ── 1. File parity ──────────────────────────────
echo ""
echo "--- File Parity ---"

claude_files=()
for f in "$CLAUDE_DIR"/*.md; do
    [ -f "$f" ] && claude_files+=("$(basename "$f")")
done

opencode_files=()
for f in "$OPENCODE_DIR"/*.md; do
    [ -f "$f" ] && opencode_files+=("$(basename "$f")")
done

missing_in_opencode=()
missing_in_claude=()

for f in "${claude_files[@]}"; do
    if [ ! -f "$OPENCODE_DIR/$f" ]; then
        missing_in_opencode+=("$f")
    fi
done

for f in "${opencode_files[@]}"; do
    if [ ! -f "$CLAUDE_DIR/$f" ]; then
        missing_in_claude+=("$f")
    fi
done

if [ ${#missing_in_opencode[@]} -eq 0 ] && [ ${#missing_in_claude[@]} -eq 0 ]; then
    pass "All ${#claude_files[@]} commands have parity between claude/ and opencode/"
else
    for f in "${missing_in_opencode[@]}"; do fail "Missing in opencode/: $f"; done
    for f in "${missing_in_claude[@]}"; do fail "Missing in claude/: $f"; done
fi

# ── 2. Forbidden words ──────────────────────────
echo ""
echo "--- Forbidden Words ---"

# OpenCode must NOT reference Claude-specific Workflow tool (Agent is allowed for Workers)
bad_oc=0
for f in "$OPENCODE_DIR"/*.md; do
    if grep -q '<Agent>\|Workflow 工具\|claude.*Agent' "$f" 2>/dev/null; then
        fail "OpenCode $(basename "$f") contains Workflow tool reference"
        bad_oc=1
    fi
done
[ "$bad_oc" -eq 0 ] && pass "OpenCode commands: no Workflow tool references"

# OpenCode must NOT use --from-stdin (deprecated — replaced by --from-file)
# Only flag actual code usage (not deprecation warning prose)
bad_stdin=0
for f in "$OPENCODE_DIR"/*.md; do
    # Match --from-stdin only in actual code blocks (bash fenced), not in prose/deprecation warnings
    if grep -q '^python3 "\$RECORDER".*--from-stdin\|\$(RECORDER).*--from-stdin' "$f" 2>/dev/null; then
        fail "OpenCode $(basename "$f") contains --from-stdin in code block (use --from-file instead)"
        bad_stdin=1
    fi
done
[ "$bad_stdin" -eq 0 ] && pass "OpenCode commands: no --from-stdin in code (uses --from-file)"

# Claude must NOT reference OpenCode-specific background-task
bad_cc=0
for f in "$CLAUDE_DIR"/*.md; do
    if grep -q 'background-task\|background_task\|OpenCode.*background' "$f" 2>/dev/null; then
        fail "Claude $(basename "$f") contains OpenCode background-task reference"
        bad_cc=1
    fi
done
[ "$bad_cc" -eq 0 ] && pass "Claude commands: no background-task references"

# ── 3. Platform frontmatter ─────────────────────
echo ""
echo "--- Platform Frontmatter ---"

for f in "$CLAUDE_DIR"/*.md; do
    name=$(basename "$f")
    if grep -q '^platform: claude' "$f" 2>/dev/null; then
        pass "$name frontmatter: platform: claude"
    else
        fail "$name missing platform: claude in frontmatter"
    fi
done

for f in "$OPENCODE_DIR"/*.md; do
    name=$(basename "$f")
    if grep -q '^platform: opencode' "$f" 2>/dev/null; then
        pass "$name frontmatter: platform: opencode"
    else
        fail "$name missing platform: opencode in frontmatter"
    fi
done

# ── Summary ─────────────────────────────────────
echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
    echo -e "${GREEN}==> All checks passed.${NC}"
else
    echo -e "${RED}==> Some checks failed.${NC}"
fi
exit "$EXIT_CODE"
