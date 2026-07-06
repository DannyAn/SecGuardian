#!/bin/bash
# SecGuardian — Release Build + GitHub Upload
#
# 构建单包分发产物 → 上传到 GitHub Releases。
#
# 用法:
#   bash scripts/release.sh v0.14.0           # 发布指定 tag
#   bash scripts/release.sh v0.14.0 --draft   # 创建 draft release
#
# 前提:
#   - tag 已存在 (git tag v0.x.y && git push origin v0.x.y)
#   - gh CLI 已登录 (gh auth status)
#   - 工作目录干净（有未提交修改时交互式确认）
#
# 产物结构:
#
#   dist/release/
#   └── secguardian-0.14.0.tar.gz     ← 唯一需要下载的包
#       ├── install.sh                ← bash install.sh claude|nga|cac
#       ├── uninstall.sh              ← bash uninstall.sh claude|nga|cac
#       ├── README.md
#       ├── secguardian-0.14.0-darwin-arm64.tar.gz   ← 平台内包
#       ├── secguardian-0.14.0-darwin-amd64.tar.gz
#       ├── secguardian-0.14.0-linux-amd64.tar.gz
#       ├── secguardian-0.14.0-linux-arm64.tar.gz
#       └── secguardian-0.14.0-windows-amd64.zip
#   SHA256SUMS                         ← 校验文件

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_TAG="${1:-}"
DRAFT_FLAG="${2:-}"

# ── Help ──────────────────────────────────────
if [ -z "$RELEASE_TAG" ] || [ "$RELEASE_TAG" = "-h" ] || [ "$RELEASE_TAG" = "--help" ]; then
    cat << 'EOF'
用法:
  bash scripts/release.sh v0.x.y         # 发布正式版
  bash scripts/release.sh v0.x.y --draft # 发布草稿

流程:
  1. bash scripts/package.sh         (构建 dist/ + 5 平台二进制)
  2. 合并 4 个 extension → 5 个平台内包
  3. 打包为 secguardian-<ver>.tar.gz (含 install.sh + uninstall.sh)
  4. gh release create + upload
EOF
    exit 0
fi

# ── Tag 校验 ──────────────────────────────────
if ! git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
    echo "[FAIL] Tag '$RELEASE_TAG' not found."
    echo "  Create it: git tag $RELEASE_TAG && git push origin $RELEASE_TAG"
    exit 1
fi

if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
    echo "[WARN] Release '$RELEASE_TAG' already exists."
    echo "  Delete old: gh release delete $RELEASE_TAG"
    echo "  Delete tag: git push --delete origin $RELEASE_TAG"
    echo "  Or use --clobber-assets to overwrite assets (not yet supported)."
    exit 1
fi

# ── Worktree check ────────────────────────────
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "[WARN] Working directory has uncommitted changes:"
    git status --short
    echo ""
    read -r -p "Continue? [y/N] " reply
    if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
        echo "Cancelled."
        exit 1
    fi
fi

VERSION="${RELEASE_TAG#v}"
DIST="$PROJECT_ROOT/dist"
RELEASE_DIR="$DIST/release"
BIN_SRC="$PROJECT_ROOT/scripts/bin"

# ── Step 1: Build ─────────────────────────────
echo ""
echo "==> Step 1: Building dist/ + binaries..."
bash "$PROJECT_ROOT/scripts/package.sh"

# ── Step 2: Platform bundles ──────────────────
echo ""
echo "==> Step 2: Building platform bundles..."

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
    mkdir -p "$staging/scripts/bin"

    # Merge all 4 extensions into staging (excluding binaries)
    for ext_dir in "$DIST"/*-secguardian/; do
        [ -d "$ext_dir" ] || continue
        # Copy all except scripts/bin/ (we handle binaries per-platform)
        (cd "$ext_dir" && find . -not -path './scripts/bin/*' -type f | while read -r f; do
            mkdir -p "$staging/$(dirname "$f")"
            cp "$ext_dir/$f" "$staging/$f"
        done)
    done

    # Use platform-specific binary (renamed to canonical name)
    bin_name="secguardian-index-${platform}"
    [ "$platform" = "windows-amd64" ] && bin_name="${bin_name}.exe"
    if [ -f "$BIN_SRC/$bin_name" ]; then
        cp "$BIN_SRC/$bin_name" "$staging/scripts/bin/secguardian-index"
        chmod +x "$staging/scripts/bin/secguardian-index"
    else
        echo "  [WARN] Binary not found: $bin_name"
    fi

    # Package the platform bundle
    bundle_name="secguardian-${VERSION}-${platform}${ext}"
    (cd "$RELEASE_DIR" && \
        if [ "$ext" = ".zip" ]; then
            (cd "staging-$platform" && zip -qr "$RELEASE_DIR/$bundle_name" .)
        else
            tar czf "$bundle_name" -C "staging-$platform" .
        fi)
    echo "  → $bundle_name"
    rm -rf "$staging"
done

# ── Step 3: Top-level bundle ──────────────────
echo ""
echo "==> Step 3: Creating top-level bundle..."

TOP_DIR="$RELEASE_DIR/secguardian-${VERSION}"
mkdir -p "$TOP_DIR"

# Copy install/uninstall scripts
cp "$PROJECT_ROOT/scripts/install.sh" "$TOP_DIR/install.sh"
cp "$PROJECT_ROOT/scripts/uninstall.sh" "$TOP_DIR/uninstall.sh"
chmod +x "$TOP_DIR/install.sh" "$TOP_DIR/uninstall.sh"

# Copy platform bundles
for entry in "${TARGETS[@]}"; do
    IFS=: read -r platform ext <<< "$entry"
    bundle_name="secguardian-${VERSION}-${platform}${ext}"
    if [ -f "$RELEASE_DIR/$bundle_name" ]; then
        mv "$RELEASE_DIR/$bundle_name" "$TOP_DIR/"
    fi
done

# Generate quick-start README
cat > "$TOP_DIR/README.md" << README
# SecGuardian ${VERSION}

Enterprise white-box security AI Agent for Claude Code / OpenCode / Gemini CLI.

## Quick Install

\`\`\`bash
# Install to a single platform
bash install.sh claude      # Claude Code
bash install.sh nga         # OpenCode
bash install.sh cac         # Gemini CLI

# Or install to all
bash install.sh all
\`\`\`

## Uninstall

\`\`\`bash
bash uninstall.sh claude    # Remove from Claude Code
bash uninstall.sh all       # Remove from all platforms
\`\`\`

## Platform Packages

Each platform bundle contains all 4 SecGuardian commands:
  /secguard  — Secure Coding Guidance
  /secaudit  — Security Audit
  /secreview — AI Security Code Review
  /secfix    — AI Remediation

After install, restart your AI CLI. Run \`/secguard --help\` to get started.
README

# Package top-level
TOP_ARCHIVE="secguardian-${VERSION}.tar.gz"
(cd "$RELEASE_DIR" && tar czf "$TOP_ARCHIVE" "secguardian-${VERSION}")
echo "  → $TOP_ARCHIVE"
rm -rf "$TOP_DIR"

# ── Step 4: SHA256 ────────────────────────────
echo ""
echo "==> Step 4: Generating SHA256 checksums..."

cd "$RELEASE_DIR"
if command -v sha256sum &>/dev/null; then
    sha256sum -- *.tar.gz *.zip 2>/dev/null > SHA256SUMS
elif command -v shasum &>/dev/null; then
    shasum -a 256 -- *.tar.gz *.zip 2>/dev/null > SHA256SUMS
fi
echo "  → SHA256SUMS written"
echo ""
echo "Release artifacts:"
ls -lh "$RELEASE_DIR/"*
echo ""

# ── Step 5: Changelog ─────────────────────────
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

# ── Step 6: Release + Upload ──────────────────
echo "==> Step 5: Creating GitHub Release..."

if [ "$DRAFT_FLAG" = "--draft" ]; then
    gh release create "$RELEASE_TAG" \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES" \
        --draft
else
    gh release create "$RELEASE_TAG" \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES"
fi

echo ""
echo "==> Step 6: Uploading assets..."

gh release upload "$RELEASE_TAG" "$RELEASE_DIR/secguardian-${VERSION}.tar.gz" --clobber
gh release upload "$RELEASE_TAG" "$RELEASE_DIR/SHA256SUMS" --clobber

echo ""
echo "==> Done!"
gh release view "$RELEASE_TAG" --json url -q '.url'
