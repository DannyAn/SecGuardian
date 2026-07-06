#!/bin/bash
# SecGuardian — 统一安装器
#
# 从 release 包中提取当前平台的扩展包并安装到指定 AI Agent。
# 在解压后的 secguardian-<version>/ 目录中运行：
#
# 用法:
#   bash install.sh                    # 自动检测平台，显示可用目标
#   bash install.sh claude             # 安装到 Claude Code
#   bash install.sh nga                # 安装到 OpenCode
#   bash install.sh cac                # 安装到 Gemini CLI
#   bash install.sh all                # 安装到全部三个平台
#   bash install.sh --help             # 查看完整帮助
#
# 平台缩写:
#   claude  → ~/.claude/plugins/secguardian/
#   nga     → ~/.config/opencode/extensions/secguardian/
#   cac     → ~/.gemini/extensions/secguardian/
#
# 支持平台: darwin-arm64, darwin-amd64, linux-amd64, linux-arm64, windows-amd64

set -euo pipefail

# ── 安装目标路径 ──────────────────────────────
TARGET_CLAUDE="$HOME/.claude/plugins/secguardian"
TARGET_NGA="$HOME/.config/opencode/extensions/secguardian"
TARGET_CAC="$HOME/.gemini/extensions/secguardian"

# ── 颜色 ──────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# ── 平台检测 ──────────────────────────────────
detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        darwin) os="darwin" ;;
        linux)  os="linux" ;;
        mingw*|msys*|cygwin*) os="windows" ;;
        *) echo "error: unknown OS: $os" >&2; return 1 ;;
    esac
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) echo "error: unknown arch: $arch" >&2; return 1 ;;
    esac
    echo "${os}-${arch}"
}

# ── 帮助 ──────────────────────────────────────
show_help() {
    cat << 'USAGE'
用法: bash install.sh [目标]

目标:
  claude      安装到 Claude Code  (~/.claude/plugins/secguardian/)
  nga         安装到 OpenCode      (~/.config/opencode/extensions/secguardian/)
  cac         安装到 Gemini CLI    (~/.gemini/extensions/secguardian/)
  all         安装到全部三个平台
  (无参数)    显示帮助

示例:
  bash install.sh claude         # 仅安装 Claude Code
  bash install.sh nga            # 仅安装 OpenCode
  bash install.sh all            # 安装到全部平台

说明:
  - 从当前目录自动检测匹配当前平台的压缩包
  - 支持的平台: darwin-arm64, darwin-amd64, linux-amd64, linux-arm64, windows-amd64
  - Windows: 从 Git Bash / WSL / MSYS2 中运行
  - 安装后重启 AI CLI 即可使用 /secguard /secaudit /secreview /secfix
USAGE
}

# ── 版本检测 ──────────────────────────────────
show_version() {
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    local pkg
    pkg=$(ls "$script_dir"/secguardian-*-*.tar.gz 2>/dev/null | head -1)
    if [ -n "$pkg" ]; then
        local ver
        ver=$(basename "$pkg" | sed 's/^secguardian-//;s/\(-[a-z]*-[a-z0-9]*\)*\.tar\.gz$//')
        echo "SecGuardian $ver"
    else
        echo "SecGuardian (unknown version)"
    fi
}

# ── 安装目标 ──────────────────────────────────
install_to() {
    local target="$1"
    local platform="$2"
    local script_dir="$3"
    local label="$4"

    echo ""
    echo -e "  → Installing to ${CYAN}${label}${NC} ..."

    # 找对应平台的压缩包
    local pkg_file=""
    if [ "$platform" = "windows-amd64" ]; then
        pkg_file=$(ls "$script_dir"/secguardian-*-windows-amd64.zip 2>/dev/null | head -1)
    else
        pkg_file=$(ls "$script_dir"/secguardian-*-"${platform}".tar.gz 2>/dev/null | head -1)
    fi

    if [ -z "$pkg_file" ] || [ ! -f "$pkg_file" ]; then
        echo -e "  ${RED}[FAIL]${NC} No platform package found for ${platform}"
        echo "    Expected: secguardian-*-${platform}.tar.gz in $script_dir/"
        return 1
    fi

    # 解压到临时目录
    local tmpdir
    tmpdir=$(mktemp -d)

    if echo "$pkg_file" | grep -q '\.zip$'; then
        unzip -qo "$pkg_file" -d "$tmpdir" 2>/dev/null || {
            echo -e "  ${RED}[FAIL]${NC} Failed to extract $(basename "$pkg_file")"
            rm -rf "$tmpdir"; return 1
        }
    else
        tar xzf "$pkg_file" -C "$tmpdir" 2>/dev/null || {
            echo -e "  ${RED}[FAIL]${NC} Failed to extract $(basename "$pkg_file")"
            rm -rf "$tmpdir"; return 1
        }
    fi

    # 创建目标目录并复制（合并而非覆盖整个目录）
    mkdir -p "$target"
    cp -r "$tmpdir"/* "$target/" 2>/dev/null || true

    # 确保可执行权限
    chmod +x "$target"/scripts/bin/secguardian-index 2>/dev/null || true
    chmod +x "$target"/scripts/secguardian-index 2>/dev/null || true
    find "$target"/scripts -name '*.py' -exec chmod +x {} \; 2>/dev/null || true

    rm -rf "$tmpdir"
    echo -e "  ${GREEN}[OK]${NC} Installed to ${CYAN}${target}${NC}"
}

# ── 主流程 ────────────────────────────────────
main() {
    local cmd="${1:-}"

    case "$cmd" in
        --help|-h|"")
            show_help
            exit 0
            ;;
        --version|-V)
            show_version
            exit 0
            ;;
    esac

    local platform
    platform=$(detect_platform)
    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    echo ""
    echo -e "${CYAN}SecGuardian Installer${NC}"
    echo -e "  Platform: ${YELLOW}${platform}${NC}"
    echo -e "  Package:  ${script_dir}"
    echo ""

    case "$cmd" in
        claude|claude-code)
            install_to "$TARGET_CLAUDE" "$platform" "$script_dir" "Claude Code"
            ;;
        nga|opencode)
            install_to "$TARGET_NGA" "$platform" "$script_dir" "OpenCode"
            ;;
        cac|gemini|gemini-cli)
            install_to "$TARGET_CAC" "$platform" "$script_dir" "Gemini CLI"
            ;;
        all)
            install_to "$TARGET_CLAUDE" "$platform" "$script_dir" "Claude Code"
            install_to "$TARGET_NGA" "$platform" "$script_dir" "OpenCode"
            install_to "$TARGET_CAC" "$platform" "$script_dir" "Gemini CLI"
            ;;
        *)
            echo -e "${RED}Unknown target:${NC} $cmd"
            echo "  Available: claude  nga  cac  all"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}Done.${NC} Restart your AI CLI to use /secguard /secaudit /secreview /secfix."
}

main "$@"
