#!/bin/bash
# SecGuardian — Release Canonical Entry Point
#
# Build 发布产物 → 发布到 GitHub / Gitee。
# 所有发布流程必须通过此脚本执行，分别维护多个发布脚本 = 维护噩梦。
#
# 用法:
#   bash scripts/release.sh v0.15.0               # 构建 + GitHub (默认)
#   bash scripts/release.sh v0.15.0 --gitee        # 构建 + GitHub + Gitee
#   bash scripts/release.sh v0.15.0 --only-gitee   # 构建 + Gitee 仅
#   bash scripts/release.sh --help                 # 帮助
#
# 前置条件:
#   - tag v0.x.y 已存在 (git tag && git push origin --tags)
#   - gh CLI 已登录 (gh auth status)
#   - GITEE_TOKEN 已设置（发布到 Gitee 时需要）
#
# 产物: dist/release/
#
# 设计原则:
#   1. 单入口 — 不拆分 multiple 发布脚本，不保留 github-release.sh 包装层
#   2. 构建在前 — 发布前必构建，不信任旧产物
#   3. 先快后慢 — 先做轻量检查再构建，失败不浪费构建时间

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── 颜色 ────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

# ── 参数解析 ──────────────────────────────────
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << 'HELP'
用法:
  bash scripts/release.sh v0.x.y               # 构建 + GitHub
  bash scripts/release.sh v0.x.y --gitee        # 构建 + GitHub + Gitee
  bash scripts/release.sh v0.x.y --only-gitee   # 构建 + Gitee 仅

流程:
  1. Pre-flight: 检查 gh CLI / 认证 / tag 存在 / Release 不重复
  2. bash scripts/package.sh → 构建 dist/
  3. 平台打包 (5 targets × 3 AI 平台格式)
  4. 顶层 bundle + SHA256SUMS
  5. 发布到 GitHub（除非 --only-gitee）
  6. 发布到 Gitee（如果 --gitee 或 --only-gitee）

环境变量:
  GITEE_TOKEN      发布到 Gitee 必需
  GITEE_OWNER      Gitee 仓库所有者（默认: 从 git remote 提取）
HELP
    exit 0
fi

RELEASE_TAG="$1"
PUBLISH_TARGET="github"   # github | gitee | all

if [ "${2:-}" = "--gitee" ]; then
    PUBLISH_TARGET="all"
elif [ "${2:-}" = "--only-gitee" ]; then
    PUBLISH_TARGET="gitee"
fi

VERSION="${RELEASE_TAG#v}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian Release ${VERSION}                          ${BOLD}║${NC}"
echo -e "${BOLD}║${NC}  Publish target: ${PUBLISH_TARGET}${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ════════════════════════════════════════════════════════════════
# Step 0: Pre-flight Checks
# ════════════════════════════════════════════════════════════════

log "Pre-flight checks..."

# Tag 必须存在
if ! git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
    fail "Tag '$RELEASE_TAG' not found. Create: git tag $RELEASE_TAG && git push origin $RELEASE_TAG"
fi

# GitHub 发布时需要 gh CLI
if [ "$PUBLISH_TARGET" = "github" ] || [ "$PUBLISH_TARGET" = "all" ]; then
    if ! command -v gh &>/dev/null; then
        fail "gh CLI not found. Install: brew install gh"
    fi
    if ! gh auth status 2>&1 | grep -q "Logged in"; then
        fail "gh not authenticated. Run: gh auth login"
    fi
    if gh release view "$RELEASE_TAG" &>/dev/null 2>&1; then
        fail "GitHub Release $RELEASE_TAG already exists. Delete first:\n  gh release delete $RELEASE_TAG\n  git push --delete origin $RELEASE_TAG"
    fi
    ok "GitHub release checks passed"
fi

# 工作目录检查
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo -e "${YELLOW}  ⚠  Working directory has uncommitted changes:${NC}"
    git status --short
    echo ""
    read -r -p "  Continue? [y/N] " reply
    if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
        echo "  Cancelled."
        exit 1
    fi
fi
ok "Pre-flight complete"

DIST="$PROJECT_ROOT/dist"
RELEASE_DIR="$DIST/release"
BIN_SRC="$PROJECT_ROOT/scripts/bin"

# ════════════════════════════════════════════════════════════════
# Step 1: Build dist/ + binaries
# ════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}═══ Step 1: Build ═══${NC}"
bash "$PROJECT_ROOT/scripts/package.sh"
ok "Build complete"

# ════════════════════════════════════════════════════════════════
# Step 2: Platform bundles (5 targets × 3 AI platforms)
# ════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}═══ Step 2: Platform bundles ═══${NC}"

TARGETS=(
    "darwin-arm64:.tar.gz"
    "darwin-amd64:.tar.gz"
    "linux-amd64:.tar.gz"
    "linux-arm64:.tar.gz"
    "windows-amd64:.zip"
)

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

for entry in "${TARGETS[@]}"; do
    IFS=: read -r platform ext <<< "$entry"
    staging="$RELEASE_DIR/staging-$platform"
    rm -rf "$staging"

    mkdir -p "$staging/.claude-plugin" \
             "$staging/commands/secguardian" \
             "$staging/skills" \
             "$staging/knowledge/protocols" \
             "$staging/knowledge/standards" \
             "$staging/scripts/bin" \
             "$staging/plugins"

    # Merge .md commands (Claude Code version — development anchor)
    for d in "$DIST"/*-secguardian/; do
        if [ -d "$d/commands/claude" ]; then
            for f in "$d/commands/claude"/*.md; do
                [ -f "$f" ] && cp "$f" "$staging/commands/"
            done
        fi
    done
    for f in "$staging/commands"/*.md; do
        [ -f "$f" ] && cp "$f" "$staging/commands/secguardian/"
    done

    # OpenCode .md commands (subdirectory — install.sh promotes on opencode install)
    mkdir -p "$staging/commands/opencode"
    for d in "$DIST"/*-secguardian/; do
        if [ -d "$d/commands/opencode" ]; then
            for f in "$d/commands/opencode"/*.md; do
                [ -f "$f" ] && cp "$f" "$staging/commands/opencode/"
            done
        fi
    done

    # Gemini .toml commands
    bash "$PROJECT_ROOT/scripts/gen-toml.sh" > /dev/null
    for f in "$PROJECT_ROOT/commands/gemini"/*.toml; do
        [ -f "$f" ] && cp "$f" "$staging/commands/"
    done

    # Merge skills with command prefix
    for d in "$DIST"/*-secguardian/; do
        prefix="$(basename "$d" | sed 's/-secguardian//')"
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$staging/skills/${prefix}-$(basename "$sd")"
            done
        fi
    done

    # Merge knowledge
    for cat in languages protocols; do
        for d in "$DIST"/*-secguardian/; do
            [ -d "$d/knowledge/$cat" ] && find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$staging/knowledge/$cat/" \;
        done
    done
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$staging/knowledge/"
    [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$staging/knowledge/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && find "$PROJECT_ROOT/knowledge/standards" -name '*.md' -exec cp {} "$staging/knowledge/standards/" \; 2>/dev/null || true

    # Scripts + wrappers
    for wrapper in init-scan.sh secguardian-index secguardian-index.ps1 render-report.py validate-index.py record-finding.py; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$staging/scripts/$wrapper"
            chmod +x "$staging/scripts/$wrapper" 2>/dev/null || true
        fi
    done

    # Platform binary
    bin_name="secguardian-index-${platform}"
    [ "$platform" = "windows-amd64" ] && bin_name="${bin_name}.exe"
    if [ -f "$BIN_SRC/$bin_name" ]; then
        cp "$BIN_SRC/$bin_name" "$staging/scripts/bin/secguardian-index"
        chmod +x "$staging/scripts/bin/secguardian-index"
    else
        echo "  [WARN] Binary not found: $bin_name"
    fi

    # Platform manifests (Claude Code / OpenCode / Gemini)
    cat > "$staging/.claude-plugin/plugin.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — Enterprise white-box security AI Agent",
  "author": { "name": "SecGuardian", "url": "https://github.com/DannyAn/SecGuardian" },
  "homepage": "https://github.com/DannyAn/SecGuardian"
}
JSON
    cat > "$staging/codeagent-extension.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — Enterprise white-box security AI Agent"
}
JSON
    cat > "$staging/gemini-extension.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — Enterprise white-box security AI Agent",
  "author": "SecGuardian",
  "homepage": "https://github.com/DannyAn/SecGuardian",
  "commands": ["commands/secguard.toml", "commands/secaudit.toml", "commands/secreview.toml", "commands/secfix.toml"]
}
JSON

    # OpenCode plugin script
    if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
        cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$staging/plugins/secguardian.js"
    fi

    # Gemini context
    cat > "$staging/GEMINI.md" << 'GEMINI'
# SecGuardian — Security Guardian

This extension registers 4 Gemini CLI security commands:

| Command | Purpose |
|---------|---------|
| `/secguard <path> [mode] [filters]` | Secure Coding Guidance |
| `/secaudit <skill-name> [path]` | Security Audit |
| `/secreview <path> [language]` | Code Review |
| `/secfix <path> [rule]` | AI Remediation |

All scan results written to `.codeagent/secguardian/scans/<scan-id>/`.
GEMINI

    # Strip macOS artifacts + package
    xattr -cr "$staging" 2>/dev/null || true
    find "$staging" -name '._*' -type f -delete 2>/dev/null || true

    bundle_name="secguardian-${VERSION}-${platform}${ext}"
    (cd "$RELEASE_DIR" && \
        if [ "$ext" = ".zip" ]; then
            (cd "staging-$platform" && zip -qr "$RELEASE_DIR/$bundle_name" .)
        else
            COPYFILE_DISABLE=1 tar czf "$bundle_name" --no-xattrs -C "staging-$platform" .
        fi)
    echo "  → $bundle_name"
    rm -rf "$staging"
done

ok "Platform bundles built"

# ════════════════════════════════════════════════════════════════
# Step 3: Top-level bundle + SHA256
# ════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}═══ Step 3: Top-level bundle ═══${NC}"

TOP_DIR="$RELEASE_DIR/secguardian-${VERSION}"
mkdir -p "$TOP_DIR"

cp "$PROJECT_ROOT/scripts/install.sh" "$TOP_DIR/install.sh"
cp "$PROJECT_ROOT/scripts/uninstall.sh" "$TOP_DIR/uninstall.sh"
chmod +x "$TOP_DIR/install.sh" "$TOP_DIR/uninstall.sh"

for entry in "${TARGETS[@]}"; do
    IFS=: read -r platform ext <<< "$entry"
    bundle_name="secguardian-${VERSION}-${platform}${ext}"
    if [ -f "$RELEASE_DIR/$bundle_name" ]; then
        mv "$RELEASE_DIR/$bundle_name" "$TOP_DIR/"
    fi
done

cat > "$TOP_DIR/README.md" << README
# SecGuardian ${VERSION}

Enterprise white-box security AI Agent for Claude Code / OpenCode / Gemini CLI.

## Quick Install

\`\`\`bash
bash install.sh claude      # Claude Code
bash install.sh nga         # OpenCode
bash install.sh cac         # Gemini CLI
bash install.sh all         # All platforms
\`\`\`

## Uninstall

\`\`\`bash
bash uninstall.sh claude
bash uninstall.sh all
\`\`\`
README

xattr -cr "$TOP_DIR" 2>/dev/null || true

TOP_ARCHIVE="secguardian-${VERSION}.tar.gz"
(cd "$RELEASE_DIR" && COPYFILE_DISABLE=1 tar czf "$TOP_ARCHIVE" --no-xattrs "secguardian-${VERSION}")
echo "  → $TOP_ARCHIVE"
rm -rf "$TOP_DIR"

ok "Top-level bundle created"

# ── SHA256 ────────────────────────────────
echo ""
echo -e "${BOLD}═══ Step 4: SHA256 checksums ═══${NC}"

cd "$RELEASE_DIR"
if command -v shasum &>/dev/null; then
    shasum -a 256 -- secguardian-*.tar.gz secguardian-*.zip > SHA256SUMS 2>/dev/null || true
elif command -v sha256sum &>/dev/null; then
    sha256sum -- secguardian-*.tar.gz secguardian-*.zip > SHA256SUMS 2>/dev/null || true
fi
echo "  → SHA256SUMS written"

# ── Extract changelog ────────────────────
RELEASE_NOTES=""
if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    RELEASE_NOTES=$(python3 -c "
import re, sys
tag = '$RELEASE_TAG'
ver = tag.lstrip('v')
with open('$PROJECT_ROOT/CHANGELOG.md', 'r') as f:
    content = f.read()
pattern = r'## \[' + re.escape(ver) + r'\].*?(?=## \[|\Z)'
m = re.search(pattern, content, re.DOTALL)
print(m.group(0).strip() if m else '')
")
fi

ok "SHA256 + changelog ready"

# ════════════════════════════════════════════════════════════════
# Step 5: Publish to GitHub
# ════════════════════════════════════════════════════════════════

if [ "$PUBLISH_TARGET" != "gitee" ]; then
    echo ""
    echo -e "${BOLD}═══ Step 5: Publishing to GitHub ═══${NC}"

    log "Creating GitHub Release..."
    gh release create "$RELEASE_TAG" \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES"

    log "Uploading assets..."
    gh release upload "$RELEASE_TAG" "$RELEASE_DIR/secguardian-${VERSION}.tar.gz" --clobber
    gh release upload "$RELEASE_TAG" "$RELEASE_DIR/SHA256SUMS" --clobber

    echo ""
    gh release view "$RELEASE_TAG" --json url -q '.url'
    ok "Published to GitHub"
fi

# ════════════════════════════════════════════════════════════════
# Step 6: Publish to Gitee
# ════════════════════════════════════════════════════════════════

if [ "$PUBLISH_TARGET" = "all" ] || [ "$PUBLISH_TARGET" = "gitee" ]; then
    echo ""
    echo -e "${BOLD}═══ Step 6: Publishing to Gitee ═══${NC}"

    # Source gitee-release.sh as a function library
    # It provides publish_to_gitee() when sourced, otherwise runs standalone
    GITEE_RELEASE_SCRIPT="$PROJECT_ROOT/scripts/gitee-release.sh"
    if [ -f "$GITEE_RELEASE_SCRIPT" ]; then
        # Prevent standalone execution when sourced
        PUBLISH_TO_GITEE_CALLED_FROM_RELEASE=1 \
        PUBLISH_VERSION="$VERSION" \
        bash "$GITEE_RELEASE_SCRIPT" "$RELEASE_TAG"
        ok "Published to Gitee"
    else
        warn "gitee-release.sh not found, skipping Gitee publish"
    fi
fi

# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}═══ Release ${VERSION} complete ═══${NC}"
echo ""
