#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  SecGuardian — Installer (macOS / Linux)                   ║
# ║  将发布包安装到目标项目的 AI Agent 目录中                     ║
# ╚══════════════════════════════════════════════════════════════╝
#
# 用法:
#   bash install.sh <target-project> [options]
#
# 选项:
#   --all       安装全部三个平台 (默认)
#   --claude    仅安装 Claude Code    → <project>/.claude/extensions/
#   --opencode  仅安装 OpenCode       → <project>/.opencode/
#   --gemini    仅安装 Gemini CLI     → <project>/.gemini/
#   --release-dir <dir>  指定发布包所在目录 (默认: 当前目录)
#   --version <ver>      指定版本号 (默认: 自动检测)
#   --dry-run            仅显示将要执行的操作，不实际安装
#   --no-backup          不备份已有安装
#
# 示例:
#   bash install.sh ~/my-project                          # 安装全部平台
#   bash install.sh ~/my-project --opencode               # 仅安装 OpenCode
#   bash install.sh ~/my-project --release-dir ./release  # 从指定目录安装
#   bash install.sh ~/my-project --dry-run                # 预览操作

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
    head -28 "$0" | tail -20
    exit 0
}

# ── 参数解析 ──────────────────────────────────
TARGET=""
PLATFORM="all"
RELEASE_DIR="."
VERSION=""
DRY_RUN=false
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help) show_help ;;
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
            echo "用法: bash install.sh <target-project> [options]"
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

if [ -z "$TARGET" ]; then
    log_error "缺少目标项目路径"
    echo "用法: bash install.sh <target-project> [options]"
    echo "示例: bash install.sh ~/my-project"
    exit 1
fi

# ── 验证目标路径 ──────────────────────────────
if [ ! -d "$TARGET" ]; then
    log_error "目标路径不存在: $TARGET"
    exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
RELEASE_DIR="$(cd "$RELEASE_DIR" 2>/dev/null && pwd || echo "$RELEASE_DIR")"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — 安装到目标项目                ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  目标项目: ${CYAN}$TARGET${NC}"
echo -e "  平台:     ${CYAN}$PLATFORM${NC}"
echo ""

# ── 自动检测版本 ──────────────────────────────
if [ -z "$VERSION" ]; then
    # Try to find version from zip filenames
    for f in "$RELEASE_DIR"/secguardian-*-claude-code.zip; do
        if [ -f "$f" ]; then
            VERSION=$(basename "$f" | sed 's/secguardian-//; s/-claude-code.zip//')
            break
        fi
    done
    # Fallback: try dist/archives/
    if [ -z "$VERSION" ]; then
        for f in "$RELEASE_DIR"/cc-secguard-*.zip; do
            if [ -f "$f" ]; then
                VERSION="0.3.1"  # default fallback
                break
            fi
        done
    fi
    VERSION="${VERSION:-0.3.1}"
fi

log_info "检测到版本: v$VERSION"

# ── 查找发布包 ────────────────────────────────
find_claude_zip() {
    # Try versioned name first, then legacy name
    local candidates=(
        "$RELEASE_DIR/secguardian-${VERSION}-claude-code.zip"
        "$RELEASE_DIR/cc-secaudit-secguardian.zip"
    )
    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then echo "$c"; return 0; fi
    done
    # Try glob
    local found=$(ls "$RELEASE_DIR"/secguardian-*-claude-code.zip 2>/dev/null | head -1)
    if [ -n "$found" ]; then echo "$found"; return 0; fi
    return 1
}

find_opencode_zip() {
    local candidates=(
        "$RELEASE_DIR/secguardian-${VERSION}-opencode.zip"
        "$RELEASE_DIR/nga-secguardian.zip"
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
        "$RELEASE_DIR/cac-secguardian.zip"
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

# ── 安装 Claude Code ──────────────────────────
install_claude() {
    log_step "Claude Code → .claude/extensions/"

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
    log_done "已安装到 .claude/extensions/"

    # Make binaries executable
    find "$ext_dir" -name 'secguardian-index*' -type f -exec chmod +x {} \; 2>/dev/null || true

    # Verify
    local count=$(find "$ext_dir" -maxdepth 1 -type d | wc -l | tr -d ' ')
    log_info "安装了 $((count - 1)) 个 extension"
}

# ── 安装 OpenCode ─────────────────────────────
install_opencode() {
    log_step "OpenCode → .opencode/"

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
    log_done "已安装到 .opencode/"

    # Make binaries executable
    find "$oc_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
}

# ── 安装 Gemini CLI ───────────────────────────
install_gemini() {
    log_step "Gemini CLI → .gemini/"

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
    log_done "已安装到 .gemini/"

    # Make binaries executable
    find "$gm_dir/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
}

# ── 健康检查 ──────────────────────────────────
run_health_check() {
    log_step "健康检查"

    local indexer=""
    # Check all possible locations
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
        log_warn "索引器健康检查失败（可能缺少源码文件，但二进制可执行）"
    fi
}

# ── 安装摘要 ──────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  安装完成!${NC}"
    echo ""
    echo -e "  目标项目: ${CYAN}$TARGET${NC}"
    echo ""

    # Check what was installed
    if [ -d "$TARGET/.claude/extensions" ] && [ "$(ls -A "$TARGET/.claude/extensions" 2>/dev/null)" ]; then
        echo -e "  ${GREEN}✓${NC} Claude Code:  .claude/extensions/"
        echo "     重启 Claude Code 后使用 /secguard, /secaudit, /secreview"
    fi

    if [ -d "$TARGET/.opencode/commands" ]; then
        echo -e "  ${GREEN}✓${NC} OpenCode:      .opencode/ (commands + skills + knowledge + scripts)"
        echo "     重启 OpenCode 后使用 /secguard, /secaudit, /secreview"
    fi

    if [ -d "$TARGET/.gemini/skills" ]; then
        echo -e "  ${GREEN}✓${NC} Gemini CLI:    .gemini/ (commands + skills + knowledge + scripts)"
        echo "     在 Gemini CLI 中运行 /skills reload"
    fi

    echo ""
    echo -e "  ${BOLD}扫描输出目录:${NC} .codeagent/<extension>/scans/<scan-id>/"
    echo ""
    echo -e "  ${BOLD}快速验证:${NC}"
    echo "    cd $TARGET"
    if [ -x "$TARGET/.opencode/scripts/secguardian-index" ]; then
        echo "    .opencode/scripts/secguardian-index --health"
    elif [ -x "$TARGET/.gemini/scripts/secguardian-index" ]; then
        echo "    .gemini/scripts/secguardian-index --health"
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

if ! $DRY_RUN && [ "$FAILURES" -eq 0 ] || [ "$PLATFORM" != "all" ] && [ "$FAILURES" -lt 1 ]; then
    echo ""
    run_health_check
fi

echo ""
print_summary

if [ "$FAILURES" -gt 0 ]; then
    log_warn "$FAILURES 个平台安装失败（可能缺少对应的发布包）"
fi
