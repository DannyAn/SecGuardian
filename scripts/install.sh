#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  SecGuardian — Installer (macOS / Linux)                   ║
# ║  将发布包安装到用户级或项目级 AI Agent 目录中               ║
# ╚══════════════════════════════════════════════════════════════╝
#
# 用法:
#   bash install.sh --user [options]              # 用户级（推荐）
#   bash install.sh <target-project> [options]    # 项目级
#
# 选项:
#   --user              安装到用户家目录（推荐，跨项目共用）
#   --all               安装全部三个平台 (默认)
#   --claude            仅安装 Claude Code
#   --opencode          仅安装 OpenCode
#   --gemini            仅安装 Gemini CLI
#   --release-dir <dir> 指定发布包所在目录 (默认: 当前目录)
#   --version <ver>     指定版本号 (默认: 自动检测)
#   --dry-run           仅显示将要执行的操作，不实际安装
#   --no-backup         不备份已有安装
#
# 示例:
#   # 用户级安装（推荐）
#   bash install.sh --user --all                 # 安装全部平台到 ~/
#   bash install.sh --user --opencode            # 仅 OpenCode 到 ~/.opencode/
#
#   # 项目级安装
#   bash install.sh ~/my-project --all           # 安装全部平台到项目
#   bash install.sh ~/my-project --opencode      # 仅 OpenCode 到项目
#   bash install.sh ~/my-project --dry-run       # 预览操作

set -euo pipefail

# ── 颜色 ──────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'

log_step()  { echo -e "${BOLD}═══ $1 ═══${NC}"; }
log_info()  { echo -e "${CYAN}  →${NC} $1"; }
log_done()  { echo -e "${GREEN}  ✓${NC} $1"; }
log_warn()  { echo -e "${YELLOW}  ⚠${NC} $1"; }
log_error() { echo -e "${RED}  ✗${NC} $1"; }

# ── 帮助信息 ──────────────────────────────────
show_help() {
    head -36 "$0" | tail -30
    exit 0
}

# ── 参数解析 ──────────────────────────────────
USER_MODE=false
TARGET=""
PLATFORM="all"
RELEASE_DIR="."
VERSION=""
DRY_RUN=false
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help) show_help ;;
        --user)         USER_MODE=true; shift ;;
        --all)          PLATFORM="all"; shift ;;
        --claude)       PLATFORM="claude"; shift ;;
        --opencode)     PLATFORM="opencode"; shift ;;
        --gemini)       PLATFORM="gemini"; shift ;;
        --release-dir)  RELEASE_DIR="$2"; shift 2 ;;
        --version)      VERSION="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --no-backup)    NO_BACKUP=true; shift ;;
        -*)
            log_error "未知选项: $1"
            echo "用法: bash install.sh --user [options]  或  bash install.sh <project> [options]"
            exit 1
            ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$1"
            else
                log_error "多余的参数: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# ── 确定安装目标路径 ──────────────────────────
if $USER_MODE; then
    TARGET="$HOME"
    INSTALL_MODE="用户级"
    INSTALL_MODE_DESC="跨所有项目可用"
else
    if [ -z "$TARGET" ]; then
        log_error "请指定 --user（用户级安装）或 <project-path>（项目级安装）"
        echo ""
        echo "  用户级（推荐）:  bash install.sh --user --all"
        echo "  项目级:          bash install.sh ~/my-project --opencode"
        exit 1
    fi
    if [ ! -d "$TARGET" ]; then
        log_error "目标路径不存在: $TARGET"
        exit 1
    fi
    TARGET="$(cd "$TARGET" && pwd)"
    INSTALL_MODE="项目级"
    INSTALL_MODE_DESC="仅当前项目可用"
fi

RELEASE_DIR="$(cd "$RELEASE_DIR" 2>/dev/null && pwd || echo "$RELEASE_DIR")"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — ${INSTALL_MODE}安装                 ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  安装模式: ${CYAN}${INSTALL_MODE} (${INSTALL_MODE_DESC})${NC}"
echo -e "  安装路径: ${CYAN}$TARGET${NC}"
echo -e "  平台:     ${CYAN}$PLATFORM${NC}"
echo ""

# ── 自动检测版本 ──────────────────────────────
if [ -z "$VERSION" ]; then
    for f in "$RELEASE_DIR"/secguardian-*-claude-code.zip; do
        if [ -f "$f" ]; then
            VERSION=$(basename "$f" | sed 's/secguardian-//; s/-claude-code.zip//')
            break
        fi
    done
    VERSION="${VERSION:-0.4.0}"
fi

log_info "检测到版本: v$VERSION"

# ── 查找发布包 ────────────────────────────────
find_claude_zip() {
    local candidates=(
        "$RELEASE_DIR/secguardian-${VERSION}-claude-code.zip"
    )
    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then echo "$c"; return 0; fi
    done
    local found=$(ls "$RELEASE_DIR"/secguardian-*-claude-code.zip 2>/dev/null | head -1)
    if [ -n "$found" ]; then echo "$found"; return 0; fi
    return 1
}

find_opencode_zip() {
    local candidates=(
        "$RELEASE_DIR/secguardian-${VERSION}-opencode.zip"
    )
    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then echo "$c"; return 0; fi
    done
    local found=$(ls "$RELEASE_DIR"/secguardian-*-opencode.zip 2>/dev/null | head -1)
    if [ -n "$found" ]; then echo "$found"; return 0; fi
    return 1
}

find_gemini_zip() {
    local candidates=(
        "$RELEASE_DIR/secguardian-${VERSION}-gemini-cli.zip"
    )
    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then echo "$c"; return 0; fi
    done
    local found=$(ls "$RELEASE_DIR"/secguardian-*-gemini-cli.zip 2>/dev/null | head -1)
    if [ -n "$found" ]; then echo "$found"; return 0; fi
    return 1
}

# ── 备份函数 ──────────────────────────────────
backup_dir() {
    local dir="$1"
    if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]; then
        local backup="$dir.backup.$(date +%Y%m%d-%H%M%S)"
        mv "$dir" "$backup"
        log_info "已备份: $backup"
    fi
}

# ── 安装 Claude Code (用户级: ~/.claude/extensions/ ; 项目级: <project>/.claude/extensions/) ──
install_claude() {
    local label="Claude Code"
    if $USER_MODE; then
        log_step "Claude Code → ~/.claude/extensions/ (用户级)"
    else
        log_step "Claude Code → .claude/extensions/ (项目级)"
    fi

    local zip_file=$(find_claude_zip)
    if [ -z "$zip_file" ]; then
        log_warn "未找到 Claude Code 发布包，跳过"
        log_info "期望文件: secguardian-${VERSION}-claude-code.zip"
        return 1
    fi

    local ext_dir="$TARGET/.claude/extensions"

    if $DRY_RUN; then
        echo "  [DRY-RUN] 解压 $zip_file → $ext_dir/"
        return 0
    fi

    $NO_BACKUP || backup_dir "$ext_dir"
    rm -rf "$ext_dir"
    mkdir -p "$ext_dir"

    unzip -qo "$zip_file" -d "$ext_dir/"
    log_done "已安装到 $ext_dir/"

    # Make binaries executable
    find "$ext_dir" -name 'secguardian-index*' -type f -exec chmod +x {} \; 2>/dev/null || true

    local count=$(find "$ext_dir" -maxdepth 1 -type d | wc -l | tr -d ' ')
    log_info "安装了 $((count - 1)) 个 extension"
}

# ── 安装 OpenCode (用户级: ~/.opencode/ ; 项目级: <project>/.opencode/) ──
install_opencode() {
    local label="OpenCode"
    if $USER_MODE; then
        log_step "OpenCode → ~/.opencode/ (用户级)"
    else
        log_step "OpenCode → .opencode/ (项目级)"
    fi

    local zip_file=$(find_opencode_zip)
    if [ -z "$zip_file" ]; then
        log_warn "未找到 OpenCode 发布包，跳过"
        log_info "期望文件: secguardian-${VERSION}-opencode.zip"
        return 1
    fi

    local oc_dir="$TARGET/.opencode"

    if $DRY_RUN; then
        echo "  [DRY-RUN] 解压 $zip_file → $oc_dir/"
        return 0
    fi

    $NO_BACKUP || backup_dir "$oc_dir"
    rm -rf "$oc_dir"
    mkdir -p "$oc_dir"

    unzip -qo "$zip_file" -d "$oc_dir/"
    log_done "已安装到 $oc_dir/"

    # Make binaries executable
    find "$oc_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
}

# ── 安装 Gemini CLI (用户级: ~/.gemini/ ; 项目级: <project>/.gemini/) ──
install_gemini() {
    local label="Gemini CLI"
    if $USER_MODE; then
        log_step "Gemini CLI → ~/.gemini/ (用户级)"
    else
        log_step "Gemini CLI → .gemini/ (项目级)"
    fi

    local zip_file=$(find_gemini_zip)
    if [ -z "$zip_file" ]; then
        log_warn "未找到 Gemini CLI 发布包，跳过"
        log_info "期望文件: secguardian-${VERSION}-gemini-cli.zip"
        return 1
    fi

    local gm_dir="$TARGET/.gemini"

    if $DRY_RUN; then
        echo "  [DRY-RUN] 解压 $zip_file → $gm_dir/"
        return 0
    fi

    $NO_BACKUP || backup_dir "$gm_dir"
    rm -rf "$gm_dir"
    mkdir -p "$gm_dir"

    unzip -qo "$zip_file" -d "$gm_dir/"
    log_done "已安装到 $gm_dir/"

    # Make binaries executable
    find "$gm_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
}

# ── 健康检查 ──────────────────────────────────
run_health_check() {
    log_step "健康检查"

    local indexer=""
    for candidate in \
        "$TARGET/.opencode/scripts/secguardian-index" \
        "$TARGET/.gemini/scripts/secguardian-index" \
        "$TARGET/.claude/extensions/secguard-secguardian/scripts/secguardian-index" \
        "$TARGET/.claude/extensions/secaudit-secguardian/scripts/secguardian-index" \
        "$TARGET/.claude/extensions/secreview-secguardian/scripts/secguardian-index"; do
        if [ -x "$candidate" ] && [ -f "$candidate" ]; then
            indexer="$candidate"
            break
        fi
    done

    if [ -z "$indexer" ]; then
        log_warn "未找到 secguardian-index wrapper（平台可能不支持）"
        return 0
    fi

    if $DRY_RUN; then
        echo "  [DRY-RUN] $indexer --health"
        return 0
    fi

    if "$indexer" --health 2>/dev/null; then
        log_done "索引器健康检查通过"
    else
        log_warn "索引器健康检查完成（退出码非0，但二进制可执行）"
    fi
}

# ── 安装摘要 ──────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  安装完成!${NC}"
    echo ""
    echo -e "  安装模式: ${CYAN}${INSTALL_MODE}${NC}"
    echo -e "  安装路径: ${CYAN}$TARGET${NC}"
    echo ""

    if [ -d "$TARGET/.claude/extensions" ] && [ "$(ls -A "$TARGET/.claude/extensions" 2>/dev/null)" ]; then
        echo -e "  ${GREEN}✓${NC} Claude Code:  $TARGET/.claude/extensions/"
        echo "     重启 Claude Code 后使用 /secguard, /secaudit, /secreview"
    fi

    if [ -d "$TARGET/.opencode/commands" ]; then
        echo -e "  ${GREEN}✓${NC} OpenCode:      $TARGET/.opencode/ (commands + skills + knowledge + scripts)"
        echo "     重启 OpenCode 后使用 /secguard, /secaudit, /secreview"
    fi

    if [ -d "$TARGET/.gemini/skills" ]; then
        echo -e "  ${GREEN}✓${NC} Gemini CLI:    $TARGET/.gemini/ (commands + skills + knowledge + scripts)"
        echo "     在 Gemini CLI 中运行 /skills reload"
    fi

    echo ""
    echo -e "  ${BOLD}扫描输出目录:${NC} .codeagent/<extension>/scans/<scan-id>/"
    echo ""

    if $USER_MODE; then
        echo -e "  ${BOLD}提示:${NC} 用户级安装使 SecGuardian 在所有项目中可用，无需每个项目重复安装。"
    fi
    echo ""
}

# ── 主流程 ─────────────────────────────────────
FAILURES=0

case "$PLATFORM" in
    all)
        install_claude   || FAILURES=$((FAILURES + 1))
        echo ""
        install_opencode || FAILURES=$((FAILURES + 1))
        echo ""
        install_gemini   || FAILURES=$((FAILURES + 1))
        ;;
    claude)
        install_claude   || FAILURES=$((FAILURES + 1))
        ;;
    opencode)
        install_opencode || FAILURES=$((FAILURES + 1))
        ;;
    gemini)
        install_gemini   || FAILURES=$((FAILURES + 1))
        ;;
esac

if ! $DRY_RUN && [ "$FAILURES" -eq 0 ]; then
    echo ""
    run_health_check
fi

echo ""
print_summary

if [ "$FAILURES" -gt 0 ]; then
    log_warn "$FAILURES 个平台安装失败（可能缺少对应的发布包）"
fi
