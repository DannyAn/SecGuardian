#!/bin/bash
# SecGuardian — 项目完整性检查工具
#
# 用法: bash tools/check.sh
#
# 检查:
#   1. jq 可用性
#   2. extension.json 格式有效
#   3. extension.json 中声明的 skill 目录存在
#   4. extension.json 中声明的 detector 文件存在
#   5. extension.json 中声明的 concept/language 文件存在
#   6. 三个 extension 版本号一致性
#   7. 文件统计

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }

ERRORS=0

echo "SecGuardian 完整性检查"
echo "======================"
echo ""

# ── 1. 环境检查 ──────────────────────────────────
echo "1. 环境检查"
if command -v jq &>/dev/null; then
    pass "jq $(jq --version)"
else
    fail "jq 未安装 — 构建不可用"
    ((ERRORS++))
fi
echo ""

# ── 2. extension.json 格式检查 ───────────────────
echo "2. Extension 清单格式"
EXTS=(secguard-secguardian secaudit-secguardian secreview-secguardian)
for ext in "${EXTS[@]}"; do
    jf="$PROJECT_ROOT/extensions/$ext/extension.json"
    if jq empty "$jf" 2>/dev/null; then
        pass "$ext/extension.json 格式有效"
    else
        fail "$ext/extension.json 格式错误"
        ((ERRORS++))
    fi
done
echo ""

# ── 3. Skill 目录存在性 ─────────────────────────
echo "3. Skill 目录检查"
for ext in "${EXTS[@]}"; do
    jf="$PROJECT_ROOT/extensions/$ext/extension.json"
    cmd=$(jq -r '.command' "$jf")
    for skill in $(jq -r '.skills[]' "$jf"); do
        sd="$PROJECT_ROOT/skills/${cmd}-${skill}"
        if [ -d "$sd" ] && [ -f "$sd/SKILL.md" ]; then
            pass "${cmd}-${skill}"
        else
            fail "${cmd}-${skill} — 目录或 SKILL.md 缺失"
            ((ERRORS++))
        fi
    done
done
echo ""

# ── 4. Detector 文件存在性 ───────────────────────
echo "4. Detector 文件检查"
jf="$PROJECT_ROOT/extensions/secguard-secguardian/extension.json"
if jq -e '.knowledge.detectors' "$jf" > /dev/null 2>&1; then
    for det in $(jq -r '.knowledge.detectors[]' "$jf"); do
        df="$PROJECT_ROOT/knowledge/detectors/${det}.md"
        if [ -f "$df" ]; then
            pass "detector: $det"
        else
            fail "detector: $det — 文件缺失"
            ((ERRORS++))
        fi
    done
else
    warn "extension.json 中无 knowledge.detectors 字段"
fi
echo ""

# ── 5. Concept / Language 文件存在性 ─────────────
echo "5. Knowledge 文件检查"
for ext in "${EXTS[@]}"; do
    jf="$PROJECT_ROOT/extensions/$ext/extension.json"
    echo "  [$ext]"
    for sheet in $(jq -r '.knowledge.cheatsheets[]' "$jf"); do
        cf="$PROJECT_ROOT/knowledge/cheatsheets/${sheet}.md"
        [ -f "$cf" ] && pass "cheatsheet: $sheet" || { fail "cheatsheet: $sheet"; ((ERRORS++)); }
    done
    for lang in $(jq -r '.knowledge.languages[]' "$jf"); do
        lf="$PROJECT_ROOT/knowledge/languages/${lang}.md"
        [ -f "$lf" ] && pass "language: $lang" || { fail "language: $lang"; ((ERRORS++)); }
    done
done
echo ""

# ── 6. 版本号一致性 ──────────────────────────────
echo "6. 版本号一致性"
VER=$(jq -r '.version' "$PROJECT_ROOT/manifest.json")
for ext in "${EXTS[@]}"; do
    ev=$(jq -r '.version' "$PROJECT_ROOT/extensions/$ext/extension.json")
    if [ "$ev" = "$VER" ]; then
        pass "$ext: $ev"
    else
        fail "$ext: $ev (期望 $VER)"
        ((ERRORS++))
    fi
done
echo ""

# ── 7. 文件统计 ──────────────────────────────────
echo "7. 文件统计"
echo "  Knowledge cheatsheets: $(ls "$PROJECT_ROOT/knowledge/cheatsheets/"*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Knowledge languages: $(ls "$PROJECT_ROOT/knowledge/languages/"*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Knowledge detectors: $(ls "$PROJECT_ROOT/knowledge/detectors/"*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills: $(find "$PROJECT_ROOT/skills" -name SKILL.md -maxdepth 2 | wc -l | tr -d ' ')"
echo "  Commands (.md): $(ls "$PROJECT_ROOT/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Demo languages: $(ls -d "$PROJECT_ROOT/examples/"*-vuln-demo 2>/dev/null | wc -l | tr -d ' ')"
echo ""

# ── 结果 ─────────────────────────────────────────
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}所有检查通过。${NC}"
else
    echo -e "${RED}$ERRORS 个错误。${NC}"
fi
