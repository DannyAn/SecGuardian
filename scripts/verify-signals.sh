#!/bin/bash
# SecGuardian — Signal Matrix Verification (3-Round)
#
# Round 1: 功能完备性 — 每语言信号非零断言
# Round 2: 端到端检测 — 信号→finding 关联
# Round 3: 回归 + 边界
#
# 用法:
#   bash scripts/verify-signals.sh              # 全量验证 (3 rounds)
#   bash scripts/verify-signals.sh --quick       # Round 1 only
#   bash scripts/verify-signals.sh --round2      # Round 2 only
#   bash scripts/verify-signals.sh --round3      # Round 3 only

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDX="$PROJECT_ROOT/scripts/bin/secguardian-index"

BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS="${GREEN}PASS${NC}"; FAIL="${RED}FAIL${NC}"; WARN="${YELLOW}WARN${NC}"

PASSED=0; FAILED=0; WARNINGS=0

check() {
    local label="$1"; shift
    printf "  [....] %s" "$label"
    if eval "$@" &>/dev/null; then
        printf "\r  [${PASS}] %s\n" "$label"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s\n" "$label"
        FAILED=$((FAILED + 1))
    fi
}

check_signal() {
    local label="$1"; local var="$2"; local min="$3"
    local val="${!var:-0}"
    if [ "$val" -ge "$min" ] 2>/dev/null; then
        printf "\r  [${PASS}] %s (%s=%d ≥ %d)\n" "$label" "$var" "$val" "$min"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s (%s=%d < %d)\n" "$label" "$var" "$val" "$min"
        FAILED=$((FAILED + 1))
    fi
}

# Build binary first
echo -e "${BOLD}Building indexer binary...${NC}"
go build -tags cgo -o "$IDX" . 2>/dev/null || (cd "$PROJECT_ROOT/internal" 2>/dev/null && go build -tags cgo -o "$IDX" .) || {
    echo -e "  [${FAIL}] go build failed"
    exit 1
}
echo -e "  ${GREEN}✓${NC} Binary built"

parser_mode=$("$IDX" --path "$PROJECT_ROOT/examples/cpp-vuln-demo-no-answers" --output /dev/null 2>&1 | grep "Parser mode:" | sed 's/.*Parser mode: //')
echo -e "  Indexer: $($IDX --version 2>/dev/null) | Parser: ${CYAN}${parser_mode}${NC}"
echo ""

# Parse CLI args
ROUND1="${1:-all}"; ROUND2="${1:-all}"; ROUND3="${1:-all}"
case "${1:-}" in
    --quick|--round1) ROUND1="all"; ROUND2=""; ROUND3="" ;;
    --round2) ROUND1=""; ROUND2="all"; ROUND3="" ;;
    --round3) ROUND1=""; ROUND2=""; ROUND3="all" ;;
esac

# ── Language config ──
dir_for_lang() {
    case "$1" in
        cpp)        echo "cpp-vuln-demo-no-answers" ;;
        go)         echo "go-vuln-demo-no-answers" ;;
        java)       echo "java-vuln-demo-no-answers" ;;
        python)     echo "python-vuln-demo-no-answers" ;;
        javascript) echo "js-vuln-demo-no-answers" ;;
    esac
}
ALL_LANGS=("cpp" "go" "java" "python" "javascript")

# Helper: run indexer and extract signal values into S_<lang>_<sig> variables
index_and_parse() {
    local lang="$1"
    local dir="$(dir_for_lang "$lang")"
    [ -z "$dir" ] && return
    local out
    out=$("$IDX" --path "$PROJECT_ROOT/examples/$dir" --output /dev/null 2>&1) || true
    local sigline=$(echo "$out" | grep "Signals:" || echo "")
    echo "    $sigline"
    # Parse "237 calls, 87 strings, ..." into variables
    local sigdata=$(echo "$sigline" | sed 's/.*Signals: //')
    [ -z "$sigdata" ] && return
    local old_ifs="$IFS"; IFS=','
    for part in $sigdata; do
        part=$(echo "$part" | xargs)
        local v=$(echo "$part" | awk '{print $1}')
        local n=$(echo "$part" | awk '{print $2}')
        [ -n "$n" ] && eval "S_${lang}_${n}=$v"
    done
    IFS="$old_ifs"
}

# ═══════════════════════════════════════════════
# Round 1: 功能完备性 — 信号非零断言
# ═══════════════════════════════════════════════
if [ -n "$ROUND1" ]; then
echo -e "${BOLD}═══ Round 1: 功能完备性验证 ═══${NC}"

for lang in "${ALL_LANGS[@]}"; do
    echo -e "  ${CYAN}${lang}${NC}"
    index_and_parse "$lang"
done

echo ""
echo -e "  ${BOLD}阈值断言:${NC}"
check_signal "C++ calls"       S_cpp_calls      50
check_signal "C++ strings"    S_cpp_strings     20
check_signal "C++ decls"      S_cpp_decls       10
check_signal "C++ values"     S_cpp_values       1
check_signal "C++ imports"    S_cpp_imports     10
check_signal "C++ flow"       S_cpp_flow        10
check_signal "Go calls"       S_go_calls        50
check_signal "Go strings"     S_go_strings      20
check_signal "Go imports"     S_go_imports       3
check_signal "Go flow"        S_go_flow          3
check_signal "Java calls"     S_java_calls      20
check_signal "Java strings"   S_java_strings    20
check_signal "Java imports"   S_java_imports     5
check_signal "Java flow"      S_java_flow        1
check_signal "Python calls"   S_python_calls    10
check_signal "Python strings" S_python_strings  20
check_signal "Python imports" S_python_imports   5
check_signal "Python flow"    S_python_flow      1
check_signal "JS calls"       S_javascript_calls  30
check_signal "JS strings"     S_javascript_strings 50
echo ""
fi

# ═══════════════════════════════════════════════
# Round 2: 端到端检测价值验证
# ═══════════════════════════════════════════════
if [ -n "$ROUND2" ]; then
echo -e "${BOLD}═══ Round 2: 端到端检测价值 (快速抽样) ═══${NC}"

echo -e "  ${CYAN}C++ 安全调用覆盖${NC}"
"$IDX" --path "$PROJECT_ROOT/examples/cpp-vuln-demo-no-answers" --output /tmp/sig-r2-cpp.json 2>/dev/null
check "C++: system() detected"    "grep -q 'system' /tmp/sig-r2-cpp.json"
check "C++: strcpy detected"      "grep -q 'strcpy' /tmp/sig-r2-cpp.json"
check "C++: malloc detected"      "grep -q 'malloc' /tmp/sig-r2-cpp.json"

echo -e "  ${CYAN}Go 安全调用覆盖${NC}"
"$IDX" --path "$PROJECT_ROOT/examples/go-vuln-demo-no-answers" --output /tmp/sig-r2-go.json 2>/dev/null
check "Go: exec.Command detected" "grep -q 'exec\\.Command' /tmp/sig-r2-go.json"

echo -e "  ${CYAN}Python 安全调用覆盖${NC}"
"$IDX" --path "$PROJECT_ROOT/examples/python-vuln-demo-no-answers" --output /tmp/sig-r2-py.json 2>/dev/null
check "Python: subprocess detected" "grep -q 'subprocess' /tmp/sig-r2-py.json"

echo -e "  ${CYAN}Java 安全调用覆盖${NC}"
"$IDX" --path "$PROJECT_ROOT/examples/java-vuln-demo-no-answers" --output /tmp/sig-r2-java.json 2>/dev/null
check "Java: executeQuery detected" "grep -q 'executeQuery' /tmp/sig-r2-java.json"

echo -e "  ${CYAN}JavaScript 安全调用覆盖${NC}"
"$IDX" --path "$PROJECT_ROOT/examples/js-vuln-demo-no-answers" --output /tmp/sig-r2-js.json 2>/dev/null
check "JavaScript: exec detected" "grep -qE '\"exec\"|execSync' /tmp/sig-r2-js.json"

rm -f /tmp/sig-r2-*.json
echo ""
fi

# ═══════════════════════════════════════════════
# Round 3: 回归 + 边界验证
# ═══════════════════════════════════════════════
if [ -n "$ROUND3" ]; then
echo -e "${BOLD}═══ Round 3: 回归 + 边界验证 ═══${NC}"

echo -e "  ${CYAN}L1: 编译检查${NC}"
check "go build (CGO) passes"    "cd '$PROJECT_ROOT/internal' && go build -tags cgo -o /dev/null ."
check "go build (non-CGO) passes" "cd '$PROJECT_ROOT/internal' && CGO_ENABLED=0 go build -o /dev/null ."

echo -e "  ${CYAN}L2: 测试${NC}"
check "go test (CGO) passes"    "cd '$PROJECT_ROOT/internal' && go test -tags cgo ./... -count=1"
check "go test (non-CGO) passes" "cd '$PROJECT_ROOT/internal' && CGO_ENABLED=0 go test -count=1 ./..."

echo -e "  ${CYAN}L3: 5 语言信号产出${NC}"
for lang in "${ALL_LANGS[@]}"; do
    local_dir=$(dir_for_lang "$lang")
    out=$("$IDX" --path "$PROJECT_ROOT/examples/$local_dir" --output /dev/null 2>&1) || true
    sigline=$(echo "$out" | grep "Signals:" || echo "")
    # Check first signal value (calls) is > 0
    val=$(echo "$sigline" | sed 's/.*Signals: //' | awk '{print $1}')
    if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
        printf "\r  [${PASS}] %s\n" "$lang"
        PASSED=$((PASSED + 1))
    else
        printf "\r  [${FAIL}] %s\n" "$lang"
        echo "    $sigline"
        FAILED=$((FAILED + 1))
    fi
done

echo -e "  ${CYAN}L4: CGO vs non-CGO 一致性${NC}"
echo -e "  ${CYAN}L4: CGO vs non-CGO 一致性${NC}"
# Extract calls count: "Signals: 237 calls, ..." → awk $2 = 237
cpp_cgo=$("$IDX" --path "$PROJECT_ROOT/examples/cpp-vuln-demo-no-answers" --output /dev/null 2>&1 | grep "calls," | awk '{print $2}')
tmp_exe=/tmp/secguardian-regex-test
CGO_ENABLED=0 go build -o "$tmp_exe" . 2>/dev/null || (cd "$PROJECT_ROOT/internal" && CGO_ENABLED=0 go build -o "$tmp_exe" . 2>/dev/null) || true
if [ -x "$tmp_exe" ]; then
    cpp_regex=$("$tmp_exe" --path "$PROJECT_ROOT/examples/cpp-vuln-demo-no-answers" --output /dev/null 2>&1 | grep "calls," | awk '{print $2}')
    rm -f "$tmp_exe"
    check "CGO(calls=$cpp_cgo) and regex(calls=$cpp_regex) both >0" \
        "[ ${cpp_cgo:-0} -gt 0 ] && [ ${cpp_regex:-0} -gt 0 ]"
else
    printf "  [${WARN}] Could not build non-CGO binary — skipping\n"
    WARNINGS=$((WARNINGS + 1))
fi

echo -e "  ${CYAN}L5: 边界场景${NC}"
check "Empty dir handles gracefully" \
    'tmpdir=$(mktemp -d); "$IDX" --path "$tmpdir" --output /dev/null 2>&1; ec=$?; rm -rf "$tmpdir"; [ $ec -eq 1 ]'

echo ""
fi

# ═══════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
TOTAL=$((PASSED + FAILED))
if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "  ${GREEN}✓ 全部通过${NC}  (${PASSED}/${TOTAL} checks)"
    EXIT_CODE=0
elif [ $FAILED -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ 通过但有警告${NC}  (${PASSED}/${TOTAL} passed, ${WARNINGS} warnings)"
    EXIT_CODE=0
else
    echo -e "  ${RED}✗ ${FAILED}/${TOTAL} checks 失败${NC}"
    EXIT_CODE=1
fi
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"

exit $EXIT_CODE
