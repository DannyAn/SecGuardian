#!/bin/bash
# SecGuardian — GitHub Release Publisher
#
# 用法:
#   bash scripts/github-release.sh <version>
#
# 示例:
#   bash scripts/github-release.sh 0.10.0
#
# 前置: 版本号已在 manifest.json + extensions/*/extension.json 中更新
# Token: 从 macOS 钥匙串读取 github-token

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "用法: bash scripts/github-release.sh <version>"
    echo "示例: bash scripts/github-release.sh 0.10.0"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── 颜色 ────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

# ── 读取 Token ──────────────────────────────
TOKEN=""
if command -v security &>/dev/null; then
    TOKEN=$(security find-generic-password -a "DannyAn" -s "github-token" -w 2>/dev/null || echo "")
fi

if [ -z "$TOKEN" ]; then
    fail "GitHub token not found. Run: security add-generic-password -a DannyAn -s github-token -w <token>"
fi

OWNER="DannyAn"
REPO="SecGuardian"
RELEASE_DIR="$PROJECT_ROOT/dist/release/$VERSION"
GITHUB_API="https://api.github.com/repos/${OWNER}/${REPO}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — GitHub Release v${VERSION}               ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── 1. 构建产物 ────────────────────────────
if [ ! -d "$RELEASE_DIR" ]; then
    log "Building release artifacts..."
    bash "$PROJECT_ROOT/scripts/release.sh" "$VERSION"
    ok "Release artifacts built"
else
    ok "Release directory exists: $RELEASE_DIR"
fi

# ── 2. 收集产物 ────────────────────────────
ARTIFACTS=()
while IFS= read -r -d '' f; do
    [[ "$f" == *.sha256 ]] && continue
    [[ "$f" == *manifest.json ]] && continue
    # Standalone indexer binaries are inside the zips — skip duplicates
    [[ "$f" == *secguardian-index-* ]] && continue
    ARTIFACTS+=("$f")
done < <(find "$RELEASE_DIR" -maxdepth 1 -type f ! -name "*.sha256" ! -name "manifest.json" -print0)

if [ ${#ARTIFACTS[@]} -eq 0 ]; then
    fail "No artifacts found in $RELEASE_DIR"
fi

echo "  Artifacts to upload: ${#ARTIFACTS[@]}"
for f in "${ARTIFACTS[@]}"; do
    echo "    $(basename "$f") ($(du -h "$f" | cut -f1))"
done
echo ""

# ── 3. 推送 Git tag ─────────────────────────
if ! git -C "$PROJECT_ROOT" tag -l "v$VERSION" | grep -q "v$VERSION"; then
    log "Creating git tag v$VERSION..."
    git -C "$PROJECT_ROOT" tag "v$VERSION"
    ok "Tag v$VERSION created locally"
fi

log "Pushing tag to GitHub..."
git -C "$PROJECT_ROOT" push origin "v$VERSION" 2>/dev/null && ok "Tag pushed" || warn "Tag push failed (may already exist)"

# ── 4. 生成 Release Body ────────────────────
RELEASE_BODY=$(cat <<BODY
## v${VERSION} — Strategic Repositioning

### What's new

- **Four Gates workflow**: Prevent (secguard) → Detect (secreview) → Fix (secfix) → Verify (secaudit)
- **/secfix MVP**: Auto-generates ready-to-apply patches from findings. See \`scripts/secfix.py\`
- **/secreview refactored**: Now an AI Security Code Review for PRs with git diff mode
- **Audit Framework**: Pluggable Rule Pack architecture (\`audit-framework/\`). \`/secaudit --rulepack <name>\`
- **README fully rewritten**: English, AI-Native Security Workflow narrative, Mermaid diagram

### Installation

Download the \`source.tar.gz\`, extract, then:

\`\`\`bash
bash scripts/deploy.sh          # Install for all supported platforms
bash scripts/deploy.sh cc       # Claude Code only
bash scripts/deploy.sh nga      # OpenCode only
bash scripts/deploy.sh cac      # Gemini CLI only
\`\`\`

Platform-specific \`.zip\` packages are AI agent plugin bundles — extract and install them directly.

### Artifacts

| File | Description |
|------|-------------|
| \`secguardian-${VERSION}-claude-code-*.zip\` | Claude Code plugin |
| \`secguardian-${VERSION}-opencode-*.zip\` | OpenCode plugin |
| \`secguardian-${VERSION}-gemini-cli-*.zip\` | Gemini CLI plugin |
| \`secguardian-${VERSION}-source.tar.gz\` | Source tarball (for deploy.sh) |

### Full changelog

See [CHANGELOG.md](https://github.com/DannyAn/SecGuardian/blob/develop/CHANGELOG.md)
BODY
)

# ── 5. 创建 Release ─────────────────────────
log "Creating GitHub release..."
# Check if release already exists
RELEASE_ID=$(curl -s "${GITHUB_API}/releases/tags/v${VERSION}" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.id // empty')

if [ -z "$RELEASE_ID" ]; then
    log "Creating GitHub release..."
    RELEASE_RESP=$(curl -s -X POST "${GITHUB_API}/releases" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$(jq -n \
            --arg tag "v$VERSION" \
            --arg name "v${VERSION}" \
            --arg body "$RELEASE_BODY" \
            '{tag_name: $tag, name: $name, body: $body, prerelease: false, target_commitish: "develop"}')")

    RELEASE_ID=$(echo "$RELEASE_RESP" | jq -r '.id // empty')
    if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
        fail "Release creation failed: $(echo "$RELEASE_RESP" | jq -r '.message // "unknown error"')"
    fi
    ok "Release created"
    RELEASE_URL=$(echo "$RELEASE_RESP" | jq -r '.html_url')
else
    ok "Release already exists (ID: $RELEASE_ID)"
    RELEASE_URL="${GITHUB_API}/releases/${RELEASE_ID}"
fi

# ── 6. 上传产物 ────────────────────────────
log "Uploading ${#ARTIFACTS[@]} artifacts..."

# Fetch existing assets to skip duplicates
EXISTING_NAMES=$(curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}/assets" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.[].name // empty')

for artifact in "${ARTIFACTS[@]}"; do
    filename=$(basename "$artifact")

    if echo "$EXISTING_NAMES" | grep -qxF "$filename"; then
        ok "$filename (already exists, skipping)"
        continue
    fi

    log "  Uploading $filename..."

    HTTP_CODE=$(curl -s --connect-timeout 30 --max-time 300 -o /dev/null -w "%{http_code}" \
        -X POST "https://uploads.github.com/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}/assets?name=${filename}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$artifact")

    if [ "$HTTP_CODE" = "201" ]; then
        ok "$filename"
    else
        warn "$filename: HTTP $HTTP_CODE"
    fi

    # Upload .sha256 if exists
    sha_file="${artifact}.sha256"
    if [ -f "$sha_file" ]; then
        sha_name=$(basename "$sha_file")
        if echo "$EXISTING_NAMES" | grep -qxF "$sha_name"; then
            continue
        fi
        curl -s --connect-timeout 30 --max-time 60 -o /dev/null \
            -X POST "https://uploads.github.com/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}/assets?name=${sha_name}" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: text/plain" \
            --data-binary "@$sha_file" 2>/dev/null || true
    fi
done

# ── 完成 ────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══ Published to GitHub ═══${NC}"
echo ""
echo "  Release:  $RELEASE_URL"
echo "  Tag:      v${VERSION}"
echo "  Artifacts: ${#ARTIFACTS[@]} uploaded"
echo ""
echo "  ${BOLD}Next:${NC} Verify at the URL above."
echo "  ${BOLD}Note:${NC} Push the version commit if not done:"
echo "    git push origin develop"
