#!/bin/bash
# SecGuardian — Gitee Release Publisher
#
# 将构建产物发布到 Gitee Release。
# 依赖: gh (GitHub CLI), curl, jq
#
# 用法:
#   export GITEE_TOKEN="your-personal-access-token"
#   bash scripts/gitee-release.sh 0.3.1
#
# 环境变量:
#   GITEE_TOKEN   Gitee 个人访问令牌（必填）
#   GITEE_OWNER   仓库所有者（默认: 从 git remote 自动提取）
#   GITEE_REPO    仓库名称（默认: secguardian）
#   RELEASE_DIR   发布产物目录（默认: dist/release/<version>）

set -euo pipefail

# ── 参数 ──────────────────────────────────────
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "用法: export GITEE_TOKEN=xxx && bash scripts/gitee-release.sh <version>"
    echo "示例: bash scripts/gitee-release.sh 0.3.1"
    exit 1
fi

# ── 环境变量 ──────────────────────────────────
TOKEN="${GITEE_TOKEN:-}"
if [ -z "$TOKEN" ]; then
    echo "❌ 请设置 GITEE_TOKEN 环境变量"
    echo "   生成: https://gitee.com/profile/personal_access_tokens"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 从 git remote 自动提取 owner
DEFAULT_OWNER=""
if git -C "$PROJECT_ROOT" remote get-url origin &>/dev/null; then
    REMOTE_URL=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null)
    # 支持 https://gitee.com/owner/repo.git 和 git@gitee.com:owner/repo.git
    DEFAULT_OWNER=$(echo "$REMOTE_URL" | sed -n 's|.*[:/]\([^/]*\)/secguardian.*|\1|p')
fi

OWNER="${GITEE_OWNER:-${DEFAULT_OWNER:-secguardian}}"
REPO="${GITEE_REPO:-secguardian}"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/dist/release/$VERSION}"
GITEE_API="https://gitee.com/api/v5/repos/${OWNER}/${REPO}"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${CYAN}  →${NC} $1"; }
ok()    { echo -e "${GREEN}  ✓${NC} $1"; }
warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
fail()  { echo -e "${RED}  ✗${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — Gitee Release v${VERSION}              ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo "  Owner:  $OWNER"
echo "  Repo:   $REPO"
echo "  API:    $GITEE_API"
echo "  Dist:   $RELEASE_DIR"
echo ""

# ── 检查产物目录 ────────────────────────────
if [ ! -d "$RELEASE_DIR" ]; then
    fail "Release directory not found: $RELEASE_DIR"
fi

ARTIFACTS=()
while IFS= read -r -d '' f; do
    [[ "$f" == *.sha256 ]] && continue
    [[ "$f" == *manifest.json ]] && continue
    ARTIFACTS+=("$f")
done < <(find "$RELEASE_DIR" -maxdepth 1 -type f ! -name "*.sha256" ! -name "manifest.json" -print0)

if [ ${#ARTIFACTS[@]} -eq 0 ]; then
    fail "No artifacts found in $RELEASE_DIR (run 'bash scripts/release.sh $VERSION' first)"
fi

echo "  Artifacts to upload: ${#ARTIFACTS[@]}"
for f in "${ARTIFACTS[@]}"; do
    echo "    $(basename "$f") ($(du -h "$f" | cut -f1))"
done
echo ""

# ── 1. 检查仓库是否存在 ─────────────────────
log "Checking Gitee repository..."
if ! curl -sf "$GITEE_API?access_token=$TOKEN" > /dev/null 2>&1; then
    warn "Repository $OWNER/$REPO not found on Gitee"
    log "Creating repository..."
    curl -s -X POST "https://gitee.com/api/v5/user/repos" \
        -H "Content-Type: application/json" \
        -d "{
            \"access_token\": \"$TOKEN\",
            \"name\": \"$REPO\",
            \"description\": \"AI Native Security Guardian — 45 detectors, CWE Top 25 100%\",
            \"homepage\": \"https://gitee.com/$OWNER/$REPO\",
            \"private\": false,
            \"has_issues\": true,
            \"has_wiki\": false
        }" > /dev/null && ok "Repository created" || warn "Create failed (may already exist)"
fi
ok "Repository accessible"

# ── 2. 推送 Git tag ─────────────────────────
if ! git -C "$PROJECT_ROOT" tag -l "v$VERSION" | grep -q "v$VERSION"; then
    log "Creating git tag v$VERSION..."
    git -C "$PROJECT_ROOT" tag "v$VERSION"
    ok "Tag v$VERSION created locally"
fi

log "Pushing tag to Gitee..."
GITEE_SSH="git@gitee.com:${OWNER}/${REPO}.git"
GITEE_HTTPS="https://oauth2:${TOKEN}@gitee.com/${OWNER}/${REPO}.git"

REMOTE_EXISTS=$(git -C "$PROJECT_ROOT" remote -v 2>/dev/null | grep gitee | head -1 || echo "")
if [ -z "$REMOTE_EXISTS" ]; then
    git -C "$PROJECT_ROOT" remote add gitee "$GITEE_HTTPS" 2>/dev/null || true
fi
git -C "$PROJECT_ROOT" remote set-url gitee "$GITEE_HTTPS" 2>/dev/null

if git -C "$PROJECT_ROOT" push gitee tag "v$VERSION" 2>/dev/null; then
    ok "Tag v$VERSION pushed to Gitee"
else
    warn "Tag push failed (check GITEE_TOKEN has write access)"
    log "  You may need to push manually: git push gitee v$VERSION"
fi

# ── 3. 创建 Release ─────────────────────────
log "Creating Gitee release..."
RELEASE_BODY=$(cat <<'BODY'
## SecGuardian vVERSION

AI Native Security Guardian — 45 detectors, CWE Top 25 100%, OWASP Top 10 90%.

### 更新内容

详见 CHANGELOG.md

### 安装

```bash
# macOS (Apple Silicon)
chmod +x secguardian-VERSION-darwin-arm64
./secguardian-VERSION-darwin-arm64 help

# 或从源码构建
cd internal && go build -o secguardian .
```
BODY
)
RELEASE_BODY="${RELEASE_BODY//VERSION/$VERSION}"

RELEASE_RESP=$(curl -s -X POST "${GITEE_API}/releases" \
    -H "Content-Type: application/json" \
    -d "{
        \"access_token\": \"$TOKEN\",
        \"tag_name\": \"v$VERSION\",
        \"name\": \"v${VERSION}\",
        \"body\": $(echo "$RELEASE_BODY" | jq -Rs .),
        \"prerelease\": false,
        \"target_commitish\": \"develop\"
    }")

RELEASE_ID=$(echo "$RELEASE_RESP" | jq -r '.id // empty')
if [ -z "$RELEASE_ID" ]; then
    # 可能已经存在，获取已有 release ID
    RELEASE_ID=$(curl -s "${GITEE_API}/releases/tags/v${VERSION}?access_token=$TOKEN" | jq -r '.id // empty')
fi

if [ -z "$RELEASE_ID" ] || [ "$RELEASE_ID" = "null" ]; then
    fail "Release creation failed: $(echo "$RELEASE_RESP" | jq -r '.message // "unknown error"')"
fi
ok "Release v$VERSION created (ID: $RELEASE_ID)"

# ── 4. 上传产物 ────────────────────────────
log "Uploading ${#ARTIFACTS[@]} artifacts..."
UPLOAD_URL="${GITEE_API}/releases/${RELEASE_ID}/attach_files"

for artifact in "${ARTIFACTS[@]}"; do
    filename=$(basename "$artifact")
    log "  Uploading $filename..."

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "$UPLOAD_URL" \
        -H "Content-Type: multipart/form-data" \
        -F "access_token=$TOKEN" \
        -F "file=@$artifact")

    if [ "$HTTP_CODE" = "201" ]; then
        ok "$filename"
    else
        warn "$filename upload returned HTTP $HTTP_CODE (may already exist)"
    fi

    # 上传 .sha256 校验文件
    sha_file="${artifact}.sha256"
    if [ -f "$sha_file" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -X POST "$UPLOAD_URL" \
            -H "Content-Type: multipart/form-data" \
            -F "access_token=$TOKEN" \
            -F "file=@$sha_file")
        [ "$HTTP_CODE" = "201" ] || true
    fi
done

log "Syncing README to Gitee..."
README_CONTENT=$(cat "$PROJECT_ROOT/README.md")
curl -s -X PUT "${GITEE_API}/contents/README.md" \
    -H "Content-Type: application/json" \
    -d "{
        \"access_token\": \"$TOKEN\",
        \"content\": \"$(echo "$README_CONTENT" | base64 | tr -d '\n')\",
        \"message\": \"docs: sync README for v$VERSION [skip ci]\"
    }" > /dev/null 2>&1 || warn "README sync failed (not critical)"

# ── 完成 ────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}═══ Published to Gitee ═══${NC}"
echo ""
echo "  Release:  https://gitee.com/${OWNER}/${REPO}/releases/tag/v${VERSION}"
echo "  Tag:      v${VERSION}"
echo "  Artifacts: ${#ARTIFACTS[@]} uploaded"
echo ""
echo "  ${BOLD}Next:${NC} Verify at the URL above."
echo "  ${BOLD}Note:${NC} If README didn't sync, push manually:"
echo "    git push gitee develop"
