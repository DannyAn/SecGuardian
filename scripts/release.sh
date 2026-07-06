#!/bin/bash
# SecGuardian — GitHub Release 发布脚本
#
# 构建 dist/ → 创建归档 → 上传到 GitHub Releases。
#
# 用法:
#   bash scripts/release.sh v0.14.0           # 发布指定 tag
#   bash scripts/release.sh v0.14.0 --draft   # 创建 draft release
#
# 前提:
#   - tag 已存在 (git tag v0.x.y && git push origin v0.x.y)
#   - gh CLI 已登录 (gh auth status)
#   - 工作目录干净（有未提交修改时交互式确认）

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
  1. 运行 bash scripts/package.sh      (构建 dist/ + 二进制)
  2. 创建 dist/release/ 归档目录
  3. 归档每个 extension 为 .tar.gz
  4. 收集二进制到 release 目录
  5. 生成 SHA256 校验文件
  6. gh release create → gh release upload
EOF
    exit 0
fi

# ── Tag 校验 ──────────────────────────────────
if ! git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
    echo "[FAIL] Tag '$RELEASE_TAG' 不存在。先创建 tag:"
    echo "  git tag $RELEASE_TAG && git push origin $RELEASE_TAG"
    exit 1
fi

if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
    echo "[FAIL] Release '$RELEASE_TAG' 已存在。如需覆盖:"
    echo "  gh release delete $RELEASE_TAG && git push --delete origin $RELEASE_TAG"
    exit 1
fi

# ── 工作目录检查 ──────────────────────────────
if [ -n "$(git status --porcelain)" ]; then
    echo "[WARN] 工作目录有未提交修改:"
    git status --short
    echo ""
    read -r -p "继续发布？[y/N] " reply
    if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
        echo "已取消."
        exit 1
    fi
fi

# ── 构建 dist/ ────────────────────────────────
echo ""
echo "==> Step 1: Building dist/..."
bash "$PROJECT_ROOT/scripts/package.sh"
echo ""

# ── 整理产物 ──────────────────────────────────
RELEASE_DIR="$PROJECT_ROOT/dist/release"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "==> Step 2: Creating release archives..."

# 2a: 归档每个 extension 目录
for ext_dir in "$PROJECT_ROOT/dist"/*-*/; do
    ext_name="$(basename "$ext_dir")"
    archive_name="${ext_name}-${RELEASE_TAG#v}.tar.gz"
    echo "  → Archiving: $archive_name"
    tar czf "$RELEASE_DIR/$archive_name" -C "$PROJECT_ROOT/dist" "$ext_name"
done

# 2b: 复制跨平台二进制
BIN_SRC="$PROJECT_ROOT/scripts/bin"
if [ -d "$BIN_SRC" ]; then
    echo ""
    echo "  → Copying platform binaries..."
    mkdir -p "$RELEASE_DIR/bin"
    for bin_file in "$BIN_SRC"/secguardian-index-*; do
        [ -f "$bin_file" ] || continue
        cp "$bin_file" "$RELEASE_DIR/bin/"
        echo "    $(basename "$bin_file")"
    done
fi

echo ""
echo "  → Note: GitHub auto-generates source.tar.gz for tags"

# ── SHA256 校验 ───────────────────────────────
echo ""
echo "==> Step 3: Generating SHA256 checksums..."
cd "$RELEASE_DIR"

# Try sha256sum (Linux), fall back to shasum -a 256 (macOS)
if command -v sha256sum &>/dev/null; then
    sha256sum -- *.tar.gz bin/* 2>/dev/null > SHA256SUMS
elif command -v shasum &>/dev/null; then
    shasum -a 256 -- *.tar.gz bin/* 2>/dev/null > SHA256SUMS
fi
echo "  → SHA256SUMS written"
echo ""

echo "Release artifacts in: $RELEASE_DIR/"
ls -lh "$RELEASE_DIR/"*
echo ""

# ── Changelog 提取 ────────────────────────────
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

# ── 发布到 GitHub ────────────────────────────
echo "==> Step 4: Creating GitHub Release..."

if [ "$DRAFT_FLAG" = "--draft" ]; then
    echo "  → Creating DRAFT release..."
    gh release create "$RELEASE_TAG" \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES" \
        --draft
else
    echo "  → Creating release..."
    gh release create "$RELEASE_TAG" \
        --title "$RELEASE_TAG" \
        --notes "$RELEASE_NOTES"
fi

echo ""

# ── 上传产物 ──────────────────────────────────
echo "==> Step 5: Uploading assets..."

for item in "$RELEASE_DIR"/*.tar.gz "$RELEASE_DIR"/bin/* "$RELEASE_DIR"/SHA256SUMS; do
    [ -f "$item" ] || continue
    echo "  → Uploading: $(basename "$item")"
    gh release upload "$RELEASE_TAG" "$item" --clobber
done

echo ""
echo "==> Done! Release URL:"
gh release view "$RELEASE_TAG" --json url -q '.url'
