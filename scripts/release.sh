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
echo "==> Step 2: Building per-OS/arch bundles (with all 3 AI-platform formats)..."

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

    # ── 1. Directory structure ───────────────────
    mkdir -p "$staging/.claude-plugin" \
             "$staging/commands/secguardian" \
             "$staging/skills" \
             "$staging/knowledge/languages" \
             "$staging/knowledge/guard-rules" \
             "$staging/knowledge/protocols" \
             "$staging/knowledge/standards" \
             "$staging/scripts/bin" \
             "$staging/plugins"

    # ── 2. Merge .md commands (Claude + OpenCode) ──
    for d in "$DIST"/*-secguardian/; do
        [ -d "$d/commands" ] && find "$d/commands" -maxdepth 1 -name '*.md' -exec cp {} "$staging/commands/" \;
    done
    # Namespace copies for Claude Code: /secguardian:secguard
    for f in "$staging/commands"/*.md; do
        [ -f "$f" ] && cp "$f" "$staging/commands/secguardian/"
    done

    # ── 3. Generate + bundle .toml commands (Gemini) ──
    bash "$PROJECT_ROOT/scripts/gen-toml.sh" > /dev/null
    for f in "$PROJECT_ROOT/commands/gemini"/*.toml; do
        [ -f "$f" ] && cp "$f" "$staging/commands/"
    done

    # ── 4. Merge skills with command prefix ───────
    # Each extension has skills/: secguard has cpp/go/java/js/python,
    # secreview has cpp/go/java/js/python — they'd overwrite without prefix.
    for d in "$DIST"/*-secguardian/; do
        prefix="$(basename "$d" | sed 's/-secguardian//')"
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$staging/skills/${prefix}-$(basename "$sd")"
            done
        fi
    done

    # ── 5. Merge knowledge from all extensions ────
    for cat in languages guard-rules protocols; do
        for d in "$DIST"/*-secguardian/; do
            [ -d "$d/knowledge/$cat" ] && find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$staging/knowledge/$cat/" \;
        done
    done
    # Project-level knowledge (outside extension dirs)
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$staging/knowledge/"
    [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$staging/knowledge/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && find "$PROJECT_ROOT/knowledge/standards" -name '*.md' -exec cp {} "$staging/knowledge/standards/" \; 2>/dev/null || true
    cp -r "$PROJECT_ROOT/knowledge/audit-rules" "$staging/knowledge/" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/knowledge/review-rules" "$staging/knowledge/" 2>/dev/null || true
    cp "$PROJECT_ROOT/knowledge/language-index.md" "$staging/knowledge/" 2>/dev/null || true

    # ── 6. Scripts + wrappers ────────────────────
    for wrapper in secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$staging/scripts/$wrapper"
            chmod +x "$staging/scripts/$wrapper" 2>/dev/null || true
        fi
    done

    # ── 7. Platform-specific binary ─────────────
    bin_name="secguardian-index-${platform}"
    [ "$platform" = "windows-amd64" ] && bin_name="${bin_name}.exe"
    if [ -f "$BIN_SRC/$bin_name" ]; then
        cp "$BIN_SRC/$bin_name" "$staging/scripts/bin/secguardian-index"
        chmod +x "$staging/scripts/bin/secguardian-index"
    else
        echo "  [WARN] Binary not found: $bin_name"
    fi

    # ── 8. Platform manifests (all 3 pre-built) ──

    # Claude Code: .claude-plugin/plugin.json
    cat > "$staging/.claude-plugin/plugin.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — 企业级白盒安全 AI Agent 辅助解决方案",
  "author": { "name": "SecGuardian", "url": "https://github.com/DannyAn/SecGuardian" },
  "homepage": "https://github.com/DannyAn/SecGuardian"
}
JSON

    # OpenCode: codeagent-extension.json
    cat > "$staging/codeagent-extension.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — 企业级白盒安全 AI Agent 辅助解决方案"
}
JSON

    # Gemini CLI: gemini-extension.json (lists all 4 .toml commands)
    cat > "$staging/gemini-extension.json" << JSON
{
  "name": "secguardian",
  "version": "${VERSION}",
  "description": "SecGuardian — 企业级白盒安全 AI Agent 辅助解决方案",
  "author": "SecGuardian",
  "homepage": "https://github.com/DannyAn/SecGuardian",
  "commands": ["commands/secguard.toml", "commands/secaudit.toml", "commands/secreview.toml", "commands/secfix.toml"]
}
JSON

    # ── 9. OpenCode plugin script ────────────────
    if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
        cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$staging/plugins/secguardian.js"
    fi

    # ── 10. Gemini context file ──────────────────
    cat > "$staging/GEMINI.md" << 'GEMINI'
# SecGuardian — 安全守卫

本扩展注册了 4 个 Gemini CLI 安全命令：

| 命令 | 用途 |
|------|------|
| `/secguard <path> [mode] [filters]` | 安全加固项排查 — 代码级漏洞检测 |
| `/secaudit <skill-name> [path]` | 安全专项审计 — 深度安全分析 |
| `/secreview <path> [language]` | 安全规范检视 — 反模式和最佳实践 |
| `/secfix <path> [rule]` | AI 安全修复 |

## 使用流程

```
/secguard ./src cpp              # 扫描 C/C++ 项目
/secaudit input-validation ./src # 审计输入验证
/secreview ./src java            # 安全规范检视
```

所有扫描结果写入 `.codeagent/secguardian/scans/<scan-id>/`。
GEMINI

    # ── 11. Strip macOS artifacts + package ──────
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

# Strip macOS extended attributes from files copied into TOP_DIR
xattr -cr "$TOP_DIR" 2>/dev/null || true

# Package top-level
TOP_ARCHIVE="secguardian-${VERSION}.tar.gz"
(cd "$RELEASE_DIR" && COPYFILE_DISABLE=1 tar czf "$TOP_ARCHIVE" --no-xattrs "secguardian-${VERSION}")
echo "  → $TOP_ARCHIVE"
rm -rf "$TOP_DIR"

# ── Step 4: SHA256 ────────────────────────────
echo ""
echo "==> Step 4: Generating SHA256 checksums..."

cd "$RELEASE_DIR"
if command -v shasum &>/dev/null; then
    shasum -a 256 -- secguardian-*.tar.gz secguardian-*.zip > SHA256SUMS 2>/dev/null || true
elif command -v sha256sum &>/dev/null; then
    sha256sum -- secguardian-*.tar.gz secguardian-*.zip > SHA256SUMS 2>/dev/null || true
fi
echo "  → SHA256SUMS written"

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
