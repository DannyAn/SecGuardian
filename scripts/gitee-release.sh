#!/bin/bash
# SecGuardian — Publish to Gitee
#
# 将构建产物发布到 Gitee Release。
# 可独立使用，也可作为 release.sh --gitee 的后端。
#
# 依赖: curl, jq
# 前置: release.sh 构建步骤已完成（产物在 dist/release/）
#
# 独立用法:
#   export GITEE_TOKEN="your-token"
#   bash scripts/gitee-release.sh v0.15.0
#
# 由 release.sh 调用 (--gitee 标志):
#   bash scripts/release.sh v0.15.0 --gitee
#
# 环境变量:
#   GITEE_TOKEN     Gitee 个人访问令牌（必填）
#   GITEE_OWNER     仓库所有者（默认: 从 git remote 自动提取）
#   GITEE_REPO      仓库名称（默认: secguardian）

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── 颜色 ────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

# ── 参数 ──────────────────────────────────────
ARG_VERSION="${1:-}"
if [ -z "$ARG_VERSION" ]; then
    echo "用法: bash scripts/gitee-release.sh <version>"
    echo "示例: bash scripts/gitee-release.sh v0.15.0"
    exit 1
fi

# 统一为 v 前缀
VERSION="${ARG_VERSION#v}"
TAG="v${VERSION}"

# ── Token ────────────────────────────────────
TOKEN="${GITEE_TOKEN:-}"
OS=$(uname -s)

if [ -z "$TOKEN" ] && [ "$OS" = "Darwin" ]; then
    TOKEN=$(security find-generic-password -a "$(whoami)" -s "secguardian-gitee-token" -w 2>/dev/null || echo "")
fi
if [ -z "$TOKEN" ] && command -v secret-tool &>/dev/null; then
    TOKEN=$(secret-tool lookup service secguardian-gitee 2>/dev/null || echo "")
fi
if [ -z "$TOKEN" ]; then
    fail "GITEE_TOKEN not set. See script header for instructions."
fi

# ── Owner / Repo ─────────────────────────────
DEFAULT_OWNER=""
if git -C "$PROJECT_ROOT" remote get-url origin &>/dev/null; then
    REMOTE_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null)
    DEFAULT_OWNER=$(echo "$REMOTE_URL" | sed -n 's|.*[:/]\([^/]*\)/secguardian.*|\1|p')
fi

OWNER="${GITEE_OWNER:-${DEFAULT_OWNER:-secguardian}}"
REPO="${GITEE_REPO:-secguardian}"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/dist/release}"
GITEE_API="https://gitee.com/api/v5/repos/${OWNER}/${REPO}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — Gitee Release ${TAG}                        ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Owner:  $OWNER"
echo "  Repo:   $REPO"
echo "  API:    $GITEE_API"
echo "  Dist:   $RELEASE_DIR"
echo ""

# ── 检查产物 ──────────────────────────────────
if [ ! -d "$RELEASE_DIR" ]; then
    fail "Artifact directory not found: $RELEASE_DIR (run build first)"
fi

ARTIFACTS=()
while IFS= read -r -d '' f; do
    [[ "$f" == *SHA256SUMS ]] && continue
    [[ "$f" == *.sha256 ]] && continue
    [[ "$f" == *manifest.json ]] && continue
    [[ "$f" == *secguardian-index-* ]] && continue
    ARTIFACTS+=("$f")
done < <(find "$RELEASE_DIR" -maxdepth 1 -type f ! -name "*.sha256" ! -name "manifest.json" -print0)

if [ ${#ARTIFACTS[@]} -eq 0 ]; then
    fail "No artifacts in $RELEASE_DIR"
fi

echo "  Artifacts to upload: ${#ARTIFACTS[@]}"
for f in "${ARTIFACTS[@]}"; do
    echo "    $(basename "$f") ($(du -h "$f" | cut -f1))"
done
echo ""

# ── 1. 检查仓库 ──────────────────────────────
log "Checking Gitee repository..."
if ! curl -sf "$GITEE_API?access_token=$TOKEN" > /dev/null 2>&1; then
    warn "Repository $OWNER/$REPO not found on Gitee"
    log "Creating repository..."
    curl -s -X POST "https://gitee.com/api/v5/user/repos" \
        -H "Content-Type: application/json" \
        -d "{
            \"access_token\": \"$TOKEN\",
            \"name\": \"$REPO\",
            \"description\": \"AI Native Security Guardian\",
            \"private\": false,
            \"has_issues\": true,
            \"has_wiki\": false
        }" > /dev/null && ok "Repository created" || warn "Create failed (may already exist)"
fi
ok "Repository accessible"

# ── 2. 推送 Tag ──────────────────────────────
if ! git -C "$PROJECT_ROOT" tag -l "$TAG" | grep -q "$TAG"; then
    log "Creating git tag $TAG..."
    git -C "$PROJECT_ROOT" tag "$TAG"
    ok "Tag $TAG created locally"
fi

log "Pushing tag to Gitee..."
GITEE_HTTPS="https://oauth2:${TOKEN}@gitee.com/${OWNER}/${REPO}.git"
REMOTE_EXISTS=$(git -C "$PROJECT_ROOT" remote -v 2>/dev/null | grep gitee | head -1 || echo "")
if [ -z "$REMOTE_EXISTS" ]; then
    git -C "$PROJECT_ROOT" remote add gitee "$GITEE_HTTPS" 2>/dev/null || true
fi
git -C "$PROJECT_ROOT" remote set-url gitee "$GITEE_HTTPS" 2>/dev/null

if git -C "$PROJECT_ROOT" push gitee tag "$TAG" 2>/dev/null; then
    ok "Tag $TAG pushed to Gitee"
else
    warn "Tag push failed (check GITEE_TOKEN write access)"
    log "  Manual: git push gitee $TAG"
fi

# ── 3. 创建 Release ─────────────────────────
log "Creating Gitee release..."
RELEASE_BODY=$(cat << BODY_EOF
## SecGuardian $TAG

AI Native Security Guardian — Security scanning for Claude Code / OpenCode / Gemini CLI.

### Installation

\`\`\`bash
# Download the platform-specific bundle and install.sh
bash install.sh --user --all        # Install all 3 platforms
bash install.sh --user --opencode   # OpenCode only
bash install.sh --user --gemini     # Gemini CLI only
bash install.sh --user --claude     # Claude Code only
\`\`\`

### Assets

| File | Platform |
|------|----------|
\`secguardian-${VERSION}-darwin-arm64.tar.gz\` | macOS ARM64 |
\`secguardian-${VERSION}-darwin-amd64.tar.gz\` | macOS x64 |
\`secguardian-${VERSION}-linux-amd64.tar.gz\` | Linux x64 |
\`secguardian-${VERSION}-linux-arm64.tar.gz\` | Linux ARM64 |
\`secguardian-${VERSION}-windows-amd64.zip\` | Windows x64 |
\`secguardian-${VERSION}.tar.gz\` | Source bundle (all platforms) |

### Full Changelog

See [CHANGELOG.md]($(echo "https://gitee.com/${OWNER}/${REPO}/blob/develop/CHANGELOG.md" | sed 's/ /%20/g')).
BODY_EOF
)

RELEASE_RESP=$(curl -s -X POST "${GITEE_API}/releases" \
    -H "Content-Type: application/json" \
    -d "{
        \"access_token\": \"$TOKEN\",
        \"tag_name\": \"$TAG\",
        \"name\": \"$TAG\",
        \"body\": $(echo "$RELEASE_BODY" | jq -Rs .),
        \"prerelease\": false
    }")

RELEASE_ID=$(echo "$RELEASE_RESP" | jq -r '.id // empty')
if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    RELEASE_ID=$(curl -s "${GITEE_API}/releases/tags/${TAG}?access_token=$TOKEN" | jq -r '.id // empty')
fi

if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    fail "Release creation failed: $(echo "$RELEASE_RESP" | jq -r '.message // "unknown error"')"
fi
ok "Release $TAG created (ID: $RELEASE_ID)"

# ── 4. 上传产物（幂等） ───────────────────────
log "Uploading ${#ARTIFACTS[@]} artifacts..."
UPLOAD_URL="${GITEE_API}/releases/${RELEASE_ID}/attach_files"
EXISTING_ASSETS=$(curl -s "${GITEE_API}/releases/${RELEASE_ID}/attach_files?access_token=$TOKEN&per_page=100" | jq -r '.[].name // empty' 2>/dev/null)

for artifact in "${ARTIFACTS[@]}"; do
    filename=$(basename "$artifact")
    if echo "$EXISTING_ASSETS" | grep -qxF "$filename"; then
        ok "$filename (already exists, skipping)"
        continue
    fi
    log "  Uploading $filename..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$UPLOAD_URL" \
        -H "Content-Type: multipart/form-data" \
        -F "access_token=$TOKEN" \
        -F "file=@$artifact")
    [ "$HTTP_CODE" = "201" ] && ok "$filename" || warn "$filename returned HTTP $HTTP_CODE"
done

# ── 完成 ──────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══ Published to Gitee ═══${NC}"
echo ""
echo "  Release:  https://gitee.com/${OWNER}/${REPO}/releases/tag/${TAG}"
echo ""
