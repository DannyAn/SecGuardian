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
OS=$(uname -s)

# 从 macOS Keychain 读取
if [ -z "$TOKEN" ] && [ "$OS" = "Darwin" ]; then
    TOKEN=$(security find-generic-password -a "$(whoami)" -s "secguardian-gitee-token" -w 2>/dev/null || echo "")
fi

# 从 Linux 密钥环读取（如果安装了 secret-tool）
if [ -z "$TOKEN" ] && command -v secret-tool &>/dev/null; then
    TOKEN=$(secret-tool lookup service secguardian-gitee 2>/dev/null || echo "")
fi

if [ -z "$TOKEN" ]; then
    echo "❌ 未找到 Gitee Token"
    echo "   设置方式（三选一）:"
    echo "     1. 环境变量:   export GITEE_TOKEN=xxx"
    echo "     2. macOS:      security add-generic-password -a \"\$USER\" -s secguardian-gitee-token -w xxx"
    echo "     3. Linux:      secret-tool store --label='Gitee' service secguardian-gitee xxx"
    echo "    Token 生成: https://gitee.com/profile/personal_access_tokens"
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
    # Standalone binaries are inside the platform zips — don't upload separately
    [[ "$f" == *secguardian-index-* ]] && continue
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
            \"description\": \"AI Native Security Guardian — 60 detectors, CWE Top 25 100%, 27 audit skills\",
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

AI Native Security Guardian — 67 个检测规则 + 17 个审计领域 + 5 个语言反模式，CWE Top 25 100%，OWASP Top 10 100%。

### 安装指南

SecGuardian 是 **AI Agent 插件**，不是独立 CLI。提供两种安装方式。

#### 方式一：用户级安装（推荐）

安装到用户家目录，一次安装所有项目共用，无需每个项目重复配置。

```bash
# 1. 下载对应平台的发布包和 install.sh
# 2. 执行安装
bash install.sh --user --all        # 安装全部三个平台
bash install.sh --user --opencode   # 仅安装 OpenCode
bash install.sh --user --gemini     # 仅安装 Gemini CLI
bash install.sh --user --claude     # 仅安装 Claude Code
```

各平台用户级安装路径：

| AI 平台 | 安装路径 |
|---------|---------|
| OpenCode | `~/.opencode/` (commands + skills + knowledge + scripts) |
| Gemini CLI | `~/.gemini/` (commands + skills + knowledge + scripts + GEMINI.md) |
| Claude Code | `~/.claude/extensions/<name>/` |

#### 方式二：项目级安装

安装到指定项目目录，仅该项目的 AI Agent 可用。

```bash
bash install.sh <项目路径> --all
bash install.sh <项目路径> --opencode
```

各平台项目级安装路径：

| AI 平台 | 安装路径 |
|---------|---------|
| OpenCode | `<project>/.opencode/` |
| Gemini CLI | `<project>/.gemini/` |
| Claude Code | `<project>/.claude/extensions/<name>/` |

#### 方式三：手动解压

| AI 平台 | 下载包 | 解压到 |
|---------|--------|--------|
| OpenCode | `secguardian-VERSION-opencode.zip` | `~/.opencode/`（用户级）或 `<project>/.opencode/`（项目级） |
| Gemini CLI | `secguardian-VERSION-gemini-cli.zip` | `~/.gemini/`（用户级）或 `<project>/.gemini/`（项目级） |
| Claude Code | `secguardian-VERSION-claude-code.zip` | `~/.claude/extensions/`（用户级）或 `<project>/.claude/extensions/`（项目级） |

安装后重启 AI CLI 即可使用：
- `/secguard <path> <language> [filters]` — 安全加固项排查
- `/secaudit <path> <language> [--focus <domain>]` — 安全专项审计（17 领域）
- `/secreview <path> <language>` — 安全编码规范检视

> **优先级说明**: 如果同时存在用户级和项目级安装，项目级优先。这一规则与 Git 配置、npm 依赖等工具的约定一致。建议日常使用用户级安装，需为特定项目定制规则时才使用项目级。

#### 产物说明

> ⚠️ **平台说明**: 受 tree-sitter CGO 限制，本地发布仅包含当前平台的二进制。每个 zip 的文件名含平台后缀（如 `-darwin-arm64`），下载与您操作系统匹配的版本。Linux/Windows 用户请使用源码包在本机编译，或等待 CI 构建产物。

| 文件 | 用途 |
|------|------|
| `secguardian-VERSION-opencode-PLATFORM.zip` | OpenCode 插件包（自包含，含二进制） |
| `secguardian-VERSION-gemini-cli-PLATFORM.zip` | Gemini CLI 插件包（自包含，含二进制） |
| `secguardian-VERSION-claude-code-PLATFORM.zip` | Claude Code 插件包（自包含，含二进制） |
| `secguardian-VERSION-source.tar.gz` | 源码包（跨平台，需本机编译 `cd internal && go build`） |

### 更新内容

详见 [CHANGELOG.md](https://gitee.com/jonyan/secguardian/blob/develop/CHANGELOG.md)。
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

# ── 4. 上传产物（幂等：跳过已存在的同名文件） ──
log "Uploading ${#ARTIFACTS[@]} artifacts..."
UPLOAD_URL="${GITEE_API}/releases/${RELEASE_ID}/attach_files"

# Fetch existing assets to avoid duplicates
EXISTING_ASSETS=$(curl -s "${GITEE_API}/releases/${RELEASE_ID}/attach_files?access_token=$TOKEN&per_page=100" | jq -r '.[].name // empty' 2>/dev/null)

for artifact in "${ARTIFACTS[@]}"; do
    filename=$(basename "$artifact")

    # Skip if already uploaded (idempotent)
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

    if [ "$HTTP_CODE" = "201" ]; then
        ok "$filename"
    else
        warn "$filename upload returned HTTP $HTTP_CODE"
    fi

    # 上传 .sha256 校验文件
    sha_file="${artifact}.sha256"
    if [ -f "$sha_file" ]; then
        sha_name=$(basename "$sha_file")
        if echo "$EXISTING_ASSETS" | grep -qxF "$sha_name"; then
            continue
        fi
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
