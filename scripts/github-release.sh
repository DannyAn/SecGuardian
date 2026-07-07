#!/bin/bash
# SecGuardian — GitHub Release Publisher
#
# 用法:
#   bash scripts/github-release.sh <version>
#
# 示例:
#   bash scripts/github-release.sh v0.15.0    # 完整发布
#   bash scripts/github-release.sh 0.15.0     # 自动补 v 前缀
#
# 流程: 委托 scripts/release.sh 完成全部工作（构建 → 打包 → release → 上传）
# 前置: gh CLI 已登录 (gh auth status), 版本号已在 manifest.json + extensions 更新

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "用法: bash scripts/github-release.sh <version>"
    echo "示例: bash scripts/github-release.sh 0.15.0"
    exit 1
fi

# 自动补 v 前缀
[[ "$VERSION" != v* ]] && VERSION="v$VERSION"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── 颜色 ────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — GitHub Release ${VERSION}                 ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── 前置检查 ──────────────────────────────
log "Checking gh CLI..."
if ! command -v gh &>/dev/null; then
    fail "gh CLI not found. Install: brew install gh"
fi

if ! gh auth status 2>&1 | grep -q "Logged in"; then
    fail "gh not authenticated. Run: gh auth login"
fi

# 检查 release 是否已存在（避免 release.sh 失败一半）
if gh release view "$VERSION" &>/dev/null 2>&1; then
    fail "Release $VERSION already exists. Delete first:\n  gh release delete $VERSION\n  git push --delete origin $VERSION"
fi

# ── 委托 release.sh ───────────────────────
log "Delegating to scripts/release.sh..."
echo ""
bash "$PROJECT_ROOT/scripts/release.sh" "$VERSION"

echo ""
echo -e "${GREEN}${BOLD}═══ Published to GitHub ═══${NC}"
echo ""
gh release view "$VERSION" --json url -q '.url'
