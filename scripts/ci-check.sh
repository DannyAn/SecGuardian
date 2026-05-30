#!/bin/bash
# SecGuardian — 本地 CI 检查（push 前运行）
# 模拟 .gitee-ci.yml 中的所有检查项，无需依赖 Gitee Go 平台。
#
# 用法:
#   bash scripts/ci-check.sh         # 完整检查
#   bash scripts/ci-check.sh quick   # 快速检查（仅 JSON 格式 + 版本）
#
# 建议在 git push 前运行，确保 CI 不会失败。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

ERRORS=0

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian CI Check                     ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. 项目结构检查 ──────────────────────────
echo -e "${BOLD}[1/5] 项目结构${NC}"
echo "  Concepts:  $(ls knowledge/concepts/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Languages: $(ls knowledge/languages/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Detectors: $(ls knowledge/detectors/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Protocols: $(ls knowledge/protocols/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills:    $(find skills -name SKILL.md -maxdepth 2 | wc -l | tr -d ' ')"
echo "  Commands:  $(ls commands/*.md 2>/dev/null | wc -l | tr -d ' ')"

# ── 2. Extension JSON 格式验证 ────────────────
echo ""
echo -e "${BOLD}[2/5] Extension JSON 格式${NC}"

if ! command -v jq &>/dev/null; then
    warn "jq 未安装，跳过 JSON 验证"
else
    for ext in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        f="extensions/$ext/extension.json"
        if jq empty "$f" 2>/dev/null; then
            pass "$ext"
        else
            fail "$ext — JSON 格式错误"
            ((ERRORS++))
        fi
    done
fi

# ── 3. 版本号一致性 ──────────────────────────
echo ""
echo -e "${BOLD}[3/5] 版本号一致性${NC}"

if ! command -v jq &>/dev/null; then
    warn "jq 未安装，跳过版本检查"
else
    VER=$(jq -r '.version' manifest.json)
    echo "  manifest.json: $VER"

    for ext in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        ev=$(jq -r '.version' "extensions/$ext/extension.json")
        if [ "$ev" = "$VER" ]; then
            pass "$ext: $ev"
        else
            fail "$ext: $ev (expected $VER)"
            ((ERRORS++))
        fi
    done

    GO_VER=$(grep 'const version' internal/main.go | sed 's/.*"\(.*\)".*/\1/')
    if [ "$GO_VER" = "$VER" ]; then
        pass "main.go: $GO_VER"
    else
        fail "main.go: $GO_VER (expected $VER)"
        ((ERRORS++))
    fi
fi

# ── 4. Skill 目录完整性 ──────────────────────
echo ""
echo -e "${BOLD}[4/5] Skill 目录完整性${NC}"

if ! command -v jq &>/dev/null; then
    warn "jq 未安装，跳过 skill 检查"
else
    for ext in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        jf="extensions/$ext/extension.json"
        cmd=$(jq -r '.command' "$jf")
        for skill in $(jq -r '.skills[]' "$jf"); do
            sd="skills/${cmd}-${skill}"
            if [ -d "$sd" ] && [ -f "$sd/SKILL.md" ]; then
                pass "${cmd}-${skill}"
            else
                fail "${cmd}-${skill} — 目录或 SKILL.md 缺失"
                ((ERRORS++))
            fi
        done
    done
fi

# ── 5. Go 编译 + 冒烟测试 ────────────────────
MODE="${1:-full}"
if [ "$MODE" = "quick" ]; then
    echo ""
    echo -e "${BOLD}[5/5] Go 编译${NC} — 跳过 (quick 模式)"
else
    echo ""
    echo -e "${BOLD}[5/5] Go 编译 + 冒烟测试${NC}"

    if ! command -v go &>/dev/null; then
        warn "Go 未安装，跳过编译测试"
    else
        echo "  编译中..."
        if (cd internal && go build -o ../scripts/bin/secguardian-index . 2>/dev/null); then
            pass "Go 编译成功"

            # Version
            VER=$("./scripts/bin/secguardian-index" --version 2>/dev/null || echo "FAIL")
            echo "  Version: $VER"

            # Detectors
            echo "  Detectors: $(./scripts/bin/secguardian-index detectors 2>/dev/null | grep -c '|') rows"

            # Index test
            if "./scripts/bin/secguardian-index" --path examples/cpp-vuln-demo/src --output /tmp/test-ci-index.json 2>/dev/null; then
                if python3 -c "
import json
d=json.load(open('/tmp/test-ci-index.json'))
assert len(d.get('files',[]))>0
assert len(d.get('symbols',{}).get('functions',[]))>0
print(f'Index: {len(d[\"files\"])} files, {len(d[\"symbols\"][\"functions\"])} funcs, {len(d[\"call_graph\"][\"edges\"])} edges')
" 2>/dev/null; then
                    pass "索引生成 + 完整性验证"
                else
                    fail "索引完整性验证"
                    ((ERRORS++))
                fi
            else
                fail "索引生成失败"
                ((ERRORS++))
            fi
            rm -f /tmp/test-ci-index.json
        else
            fail "Go 编译失败"
            ((ERRORS++))
        fi
    fi
fi

# ── 结果 ─────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════════════${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  全部检查通过 ✓${NC}"
    echo ""
    echo "  Push 到 Gitee 后 CI 应能顺利通过。"
else
    echo -e "${RED}${BOLD}  $ERRORS 项检查失败 ✗${NC}"
    echo ""
    echo "  请修复上述问题后重新运行。"
fi
echo ""
exit $ERRORS
