#!/bin/bash
# SecGuardian — Dev environment verification
#
# Validates that the project-level deployment is healthy:
#   - Indexer binary present and functional (--health + --version)
#   - Plugin files (commands, skills, knowledge) match expected counts
#   - Functional smoke test: index a known directory
#
# Usage:
#   bash scripts/dev-verify.sh           # Verify all platforms
#   bash scripts/dev-verify.sh --quick     # Binary + health only
#   bash scripts/dev-verify.sh -h          # Help

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Colors ─────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; NC='\033[0m'
PASS="${GREEN}PASS${NC}"
FAIL="${RED}FAIL${NC}"
WARN="${YELLOW}WARN${NC}"

QUICK=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            cat << 'EOF'
SecGuardian — Dev 环境验证

用法:
  bash scripts/dev-verify.sh           # 完整验证（所有检查项）
  bash scripts/dev-verify.sh --quick    # 快速验证（仅 binary + health）
  bash scripts/dev-verify.sh -h         # 帮助

检查项:
  1. scripts/bin/ 是否包含当前平台二进制
  2. 三平台部署目录结构完整性
  3. 索引器 --health 通过
  4. 索引器 --version 输出正确
  5. 索引器功能冒烟测试 (index examples/cpp-vuln-demo/src)
  6. 命令/技能/知识文件数量校验
EOF
            exit 0
            ;;
        --quick) QUICK=1; shift ;;
        *) shift ;;
    esac
done

PASSED=0
FAILED=0
WARNINGS=0

check() {
    local label="$1"; shift
    local cmd="$@"
    printf "  [....] %s" "$label"
    if eval "$cmd" &>/dev/null; then
        printf "\r  [${PASS}] %s\n" "$label"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s\n" "$label"
        FAILED=$((FAILED + 1))
    fi
}

check_stderr() {
    local label="$1"; shift
    local cmd="$@"
    printf "  [....] %s" "$label"
    local out
    if out=$(eval "$cmd" 2>&1); then
        printf "\r  [${PASS}] %s  (%s)\n" "$label" "$(echo "$out" | tr '\n' ' ' | xargs)"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s\n" "$label"
        printf "        %s\n" "$(echo "$out" | tr '\n' ' ' | xargs)"
        FAILED=$((FAILED + 1))
    fi
}

check_result() {
    local label="$1"; shift
    local expected="$1"; shift
    local cmd="$@"
    printf "  [....] %s" "$label"
    local out
    out=$(eval "$cmd" 2>/dev/null) || true
    if echo "$out" | grep -q "$expected"; then
        printf "\r  [${PASS}] %s\n" "$label"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s  (got: %s)\n" "$label" "$(echo "$out" | tr '\n' ' ' | xargs)"
        FAILED=$((FAILED + 1))
    fi
}

warn_missing() {
    local label="$1"; shift
    if [ ! -e "$1" ]; then
        printf "  [${WARN}] %s\n" "$label"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
    return 0
}

# ── Detect platform ────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
PLATFORM_BIN_NAME="secguardian-index-${OS}-${ARCH}"

# Expected version
EXPECTED_VER="0.5.5"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — Dev 环境验证                     ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  平台: ${CYAN}${OS}/${ARCH}${NC}  目标版本: ${CYAN}v${EXPECTED_VER}${NC}"
echo ""

# ═══════════════════════════════════════════
# Section 1: Build artifacts
# ═══════════════════════════════════════════
echo -e "${BOLD}1. Build artifacts (scripts/bin/)${NC}"

check "Binary ${PLATFORM_BIN_NAME} exists and is executable" \
    "[ -f '$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME' ] && [ -x '$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME' ]"

bin_count=$(ls "$PROJECT_ROOT/scripts/bin"/secguardian-index-* 2>/dev/null | wc -l | tr -d ' ')
check "All 5 platform binaries present (found: ${bin_count})" \
    "[ '$bin_count' -ge 5 ]"

# ═══════════════════════════════════════════
# Section 2: Indexer health & version
# ═══════════════════════════════════════════
echo ""
echo -e "${BOLD}2. Indexer health & version${NC}"

IDX="$PROJECT_ROOT/scripts/bin/$PLATFORM_BIN_NAME"
if [ ! -x "$IDX" ]; then
    echo -e "  [${FAIL}] Cannot proceed — indexer binary not found"
    FAILED=$((FAILED + 1))
else
    check_result "health check returns HEALTH:OK" \
        "HEALTH:OK" "$IDX --health"

    check_result "version returns ${EXPECTED_VER}" \
        "${EXPECTED_VER}" "$IDX --version"

    # Functional test — run directly, check indexer exit code
    printf "  [....] %s" "indexer functional: parses examples/cpp-vuln-demo"
    rm -f /tmp/secguardian-verify-test.json
    if $IDX --path "$PROJECT_ROOT/examples/cpp-vuln-demo/src" --output /tmp/secguardian-verify-test.json >/dev/null 2>&1; then
        printf "\r  [${PASS}] %s\n" "indexer functional: parses examples/cpp-vuln-demo"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s\n" "indexer functional: parses examples/cpp-vuln-demo"
        FAILED=$((FAILED + 1))
    fi
    rm -f /tmp/secguardian-verify-test.json
fi

# ═══════════════════════════════════════════
# Section 3: Platform deployment directories
# ═══════════════════════════════════════════
echo ""
echo -e "${BOLD}3. Platform deployment structure${NC}"

verify_platform() {
    local plat_dir="$1"
    local plat_name="$2"

    echo ""
    echo -e "  ${CYAN}${plat_name}${NC} (${plat_dir})"

    if [ ! -d "$plat_dir" ]; then
        printf "  [${WARN}] Plugin directory does not exist: %s\n" "$plat_dir"
        WARNINGS=$((WARNINGS + 1))
        return
    fi

    local idx_bin="$plat_dir/scripts/bin/secguardian-index"
    if [ -f "$idx_bin" ] && [ -x "$idx_bin" ]; then
        check "${plat_name} indexer binary is present and executable" "true"
    else
        idx_bin="$plat_dir/scripts/bin/$PLATFORM_BIN_NAME"
        check_stderr "${plat_name} indexer binary (fallback name)" \
            "[ -f '$idx_bin' ] && [ -x '$idx_bin' ]"
    fi

    if [ $QUICK -eq 1 ]; then
        return
    fi

    cmd_count=$(find "$plat_dir/commands" \( -name '*.md' -o -name '*.toml' \) 2>/dev/null | wc -l | tr -d ' ')
    check "${plat_name} commands: ${cmd_count} files (expected 3)" \
        "[ '$cmd_count' -ge 3 ]"

    skill_count=$(find "$plat_dir/skills" -name 'SKILL.md' 2>/dev/null | wc -l | tr -d ' ')
    check "${plat_name} skills: ${skill_count} SKILL.md files (expected 27)" \
        "[ '$skill_count' -eq 27 ]"

    det_count=$(find "$plat_dir/knowledge/guard-rules" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    # Dynamic expected count: read from extension.json detector list, count how many have files in source knowledge/guard-rules/
    if [ -f "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" ]; then
        det_expected=0
        for det in $(jq -r '.knowledge.detectors[]' "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json" 2>/dev/null); do
            [ -f "$PROJECT_ROOT/knowledge/guard-rules/${det}.md" ] && det_expected=$((det_expected + 1))
        done
    else
        det_expected=16  # fallback
    fi
    check "${plat_name} knowledge/guard-rules: ${det_count} .md files (expected ${det_expected})" \
        "[ '$det_count' -ge '$det_expected' ]"

    lang_count=$(find "$plat_dir/knowledge/languages" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    check "${plat_name} knowledge/languages: ${lang_count} .md files (expected 5)" \
        "[ '$lang_count' -eq 5 ]"

    check "${plat_name} scripts/secguardian-index wrapper" \
        "[ -f '$plat_dir/scripts/secguardian-index' ]"
}

verify_platform "$PROJECT_ROOT/.claude/plugins/secguardian" "Claude Code"
verify_platform "$PROJECT_ROOT/.opencode/extensions/secguardian" "OpenCode"

# Verify opencode-plugin.js content (deployed separately from extension)
OPENCODE_PLUGIN="$PROJECT_ROOT/.opencode/plugins/secguardian.js"
[ -f "$OPENCODE_PLUGIN" ] && {
  HAS_K=$(grep -c 'cfg.knowledge' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
  HAS_S=$(grep -c 'cfg.skills' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
  HAS_C=$(grep -c 'cfg.command' "$OPENCODE_PLUGIN" 2>/dev/null || echo 0)
  [ "$HAS_K" -gt 0 ] && [ "$HAS_S" -gt 0 ] && [ "$HAS_C" -gt 0 ] && 
    green "opencode-plugin.js: knowledge+skills+commands" || 
    red "opencode-plugin.js: missing (k=$HAS_K s=$HAS_S c=$HAS_C)"
} || red "opencode-plugin.js NOT FOUND"
verify_platform "$PROJECT_ROOT/.gemini/extensions/secguardian" "Gemini CLI"

# ═══════════════════════════════════════════
# Section 4: Scan output directory
# ═══════════════════════════════════════════
if [ $QUICK -eq 0 ]; then
    echo ""
    echo -e "${BOLD}4. Scan output directory${NC}"

    SCANS_DIR="$PROJECT_ROOT/.codeagent/secguard-secguardian/scans"
    if [ -d "$SCANS_DIR" ]; then
        scan_count=$(ls -1 "$SCANS_DIR" 2>/dev/null | grep -v "^latest$" | wc -l | tr -d ' ')
        check "Scan directory exists (${scan_count} scans)" "[ -d '$SCANS_DIR' ]"
        if [ -L "$SCANS_DIR/latest" ]; then
            latest_target=$(readlink "$SCANS_DIR/latest")
            check "latest symlink exists → ${latest_target}" "true"
        else
            check "latest symlink exists" "false"
        fi
    else
        printf "  [${WARN}] No scan output directory yet (created on first scan)\n"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# ═══════════════════════════════════════════
# Section 5: Architecture E2E (optional, via --e2e flag)
# ═══════════════════════════════════════════
E2E_FLAG="${1:-}"
if [ "$E2E_FLAG" = "--e2e" ] || [ "$E2E_FLAG" = "-e" ]; then
    echo ""
    echo -e "${BOLD}5. Architecture E2E Verification${NC}"
    E2E_SCRIPT="$PROJECT_ROOT/scripts/e2e-verify.sh"
    if [ -f "$E2E_SCRIPT" ] && [ -x "$E2E_SCRIPT" ]; then
        if bash "$E2E_SCRIPT" --quick 2>&1 | grep -E "Passed|Failed|✓|✗|⚠" | tail -20; then
            PASSED=$((PASSED + 1))
            check "E2E verification suite executed" "true"
        else
            FAILED=$((FAILED + 1))
            check "E2E verification suite executed" "false"
        fi
    else
        printf "  [${WARN}] E2E script not found or not executable: ${E2E_SCRIPT}\n"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# ═══════════════════════════════════════════
# Section 6: Clean up temp files
# ═══════════════════════════════════════════
rm -f /tmp/secguardian-verify-test.json

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
TOTAL=$((PASSED + FAILED))
if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "  ${GREEN}✓ 全部通过${NC}  (${PASSED}/${TOTAL} checks)"
    EXIT_CODE=0
elif [ $FAILED -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ 通过但有警告${NC}  (${PASSED}/${TOTAL} passed, ${WARNINGS} warnings)"
    EXIT_CODE=0
else
    echo -e "  ${RED}✗ ${FAILED}/${TOTAL} checks 失败${NC}  (${PASSED} passed, ${FAILED} failed, ${WARNINGS} warnings)"
    EXIT_CODE=1
fi
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"

exit $EXIT_CODE
