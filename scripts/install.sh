#!/bin/bash
# SecGuardian — 统一安装器
#
# 从 release 包中提取当前平台的扩展包并安装到指定 AI Agent。
# 在解压后的 secguardian-<version>/ 目录中运行：
#
# 用法:
#   bash install.sh                    # 显示帮助
#   bash install.sh claude             # 安装到 Claude Code
#   bash install.sh nga                # 安装到 OpenCode
#   bash install.sh cac                # 安装到 Gemini CLI
#   bash install.sh all                # 安装到全部三个平台
#   bash install.sh --help             # 查看完整帮助
#
# 平台缩写:
#   claude / claude-code  → ~/.claude/plugins/secguardian/
#   nga    / opencode     → ~/.config/opencode/extensions/secguardian/
#   cac    / gemini       → ~/.gemini/extensions/secguardian/
#
# 每 OS/arch 的压缩包本身也是有效的 extension manager 安装包。
# 例如 Claude Code 用户可直接:
#   claude plugin install secguardian-0.14.0-darwin-arm64.tar.gz
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
  - 内包也支持直接通过 extension manager 安装：
      claude plugin install secguardian-0.14.0-darwin-arm64.tar.gz
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

# ── 提取平台压缩包 ────────────────────────────
# 在当前目录找到匹配当前 OS/arch 的压缩包，解压到临时目录并打印路径
extract_bundle() {
    local platform="$1"
    local script_dir="$2"
    local pkg_file

    if [ "$platform" = "windows-amd64" ]; then
        pkg_file=$(ls "$script_dir"/secguardian-*-windows-amd64.zip 2>/dev/null | head -1)
    else
        pkg_file=$(ls "$script_dir"/secguardian-*-"${platform}".tar.gz 2>/dev/null | head -1)
    fi

    if [ -z "$pkg_file" ] || [ ! -f "$pkg_file" ]; then
        echo -e "  ${RED}[FAIL]${NC} No platform package found for ${platform}" >&2
        echo "    Expected: secguardian-*-${platform}.tar.gz in $script_dir/" >&2
        return 1
    fi

    local tmpdir
    tmpdir=$(mktemp -d)

    if echo "$pkg_file" | grep -q '\.zip$'; then
        unzip -qo "$pkg_file" -d "$tmpdir" 2>/dev/null || {
            echo -e "  ${RED}[FAIL]${NC} Failed to extract $(basename "$pkg_file")" >&2
            rm -rf "$tmpdir"
            return 1
        }
    else
        tar xzf "$pkg_file" -C "$tmpdir" 2>/dev/null || {
            echo -e "  ${RED}[FAIL]${NC} Failed to extract $(basename "$pkg_file")" >&2
            rm -rf "$tmpdir"
            return 1
        }
    fi

    echo "$tmpdir"
}

# ── 安装到 Claude Code ────────────────────────
# 需要: .claude-plugin/plugin.json (official manifest)
#       commands/*.md             (slash commands)
#       commands/secguardian/*.md  (namespace commands)
#       skills/ + knowledge/ + scripts/ (共享内容)
# 内包本身就是有效的 Claude Code 插件目录，可直接 claude plugin install
install_claude() {
    local src="$1"
    local target="$TARGET_CLAUDE"

    rm -rf "$target"
    mkdir -p "$target"

    # 复制全部内容（内包已包含 Claude 需要的所有文件）
    cp -r "$src/." "$target/"

    # 清理不属于 Claude 的额外文件
    rm -f "$target/codeagent-extension.json" 2>/dev/null || true
    rm -f "$target/gemini-extension.json" 2>/dev/null || true
    rm -f "$target/GEMINI.md" 2>/dev/null || true
    rm -f "$target/plugins/secguardian.js" 2>/dev/null || true
    # 删除 Gemini 专用的 .toml 命令
    for f in "$target/commands/"*.toml; do [ -f "$f" ] && rm "$f"; done 2>/dev/null || true
    rm -rf "$target/plugins" 2>/dev/null || true

    # 写入正确 SECGUARDIAN_HOME
    echo 'export SECGUARDIAN_HOME=$HOME/.claude/plugins/secguardian' > "$target/.secguardian-env"

    # 确保可执行权限
    chmod +x "$target/scripts/bin/secguardian-index" 2>/dev/null || true

    echo -e "  ${GREEN}[OK]${NC} Installed to ${CYAN}${target}${NC}"
    echo -e "  ${CYAN}[info]${NC} Restart Claude Code, then run: /secguard --help"
}

# ── 安装到 OpenCode ───────────────────────────
# 需要: codeagent-extension.json (informational manifest)
#       commands/*.md             (slash commands)
#       plugins/secguardian.js    (opencode plugin, 复制到 plugins/ 目录)
#       skills/ + knowledge/ + scripts/ (共享内容)
install_opencode() {
    local src="$1"
    local target="$TARGET_NGA"
    local plugins_dir="$(dirname "$(dirname "$TARGET_NGA")")/plugins"

    rm -rf "$target"
    mkdir -p "$target" "$plugins_dir"

    # 复制全部内容
    cp -r "$src/." "$target/"

    # 清理不属于 OpenCode 的额外文件
    rm -f "$target/.claude-plugin/plugin.json" 2>/dev/null || true
    rm -rf "$target/.claude-plugin" 2>/dev/null || true
    rm -f "$target/gemini-extension.json" 2>/dev/null || true
    rm -f "$target/GEMINI.md" 2>/dev/null || true
    # 删除 Gemini 专用的 .toml 命令
    for f in "$target/commands/"*.toml; do [ -f "$f" ] && rm "$f"; done 2>/dev/null || true

    # 安装 OpenCode plugin (plugins/ 目录, 非 extensions/)
    if [ -f "$src/plugins/secguardian.js" ]; then
        mkdir -p "$plugins_dir"
        cp "$src/plugins/secguardian.js" "$plugins_dir/secguardian.js"
    fi

    # 写入正确 SECGUARDIAN_HOME
    echo 'export SECGUARDIAN_HOME=$HOME/.config/opencode/extensions/secguardian' > "$target/.secguardian-env"

    # 确保可执行权限
    chmod +x "$target/scripts/bin/secguardian-index" 2>/dev/null || true

    echo -e "  ${GREEN}[OK]${NC} Installed to ${CYAN}${target}${NC}"
    echo -e "  ${CYAN}[info]${NC} Restart OpenCode, then run: /secguard --help"
}

# ── 安装到 Gemini CLI (cac) ───────────────────
# 需要: gemini-extension.json (official manifest)
#       commands/*.toml          (TOML 格式 slash commands, 非 .md)
#       GEMINI.md                (Gemini context file)
#       skills/ + knowledge/ + scripts/ (共享内容)
install_gemini() {
    local src="$1"
    local target="$TARGET_CAC"

    rm -rf "$target"
    mkdir -p "$target"

    # 复制全部内容
    cp -r "$src/." "$target/"

    # 清理不属于 Gemini 的额外文件
    rm -f "$target/.claude-plugin/plugin.json" 2>/dev/null || true
    rm -rf "$target/.claude-plugin" 2>/dev/null || true
    rm -f "$target/codeagent-extension.json" 2>/dev/null || true

    # 清理 .md 命令文件 (Gemini 只使用 .toml)
    for f in "$target/commands/"*.md; do
        [ -f "$f" ] && rm "$f"
    done
    rm -rf "$target/commands/secguardian" 2>/dev/null || true

    # 写入正确 SECGUARDIAN_HOME
    echo 'export SECGUARDIAN_HOME=$HOME/.gemini/extensions/secguardian' > "$target/.secguardian-env"

    # 确保可执行权限
    chmod +x "$target/scripts/bin/secguardian-index" 2>/dev/null || true

    echo -e "  ${GREEN}[OK]${NC} Installed to ${CYAN}${target}${NC}"
    echo -e "  ${CYAN}[info]${NC} Restart Gemini CLI, then run: /secguard --help"
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
    echo ""

    # 提取内包
    local src
    src=$(extract_bundle "$platform" "$script_dir") || {
        echo ""
        echo -e "${RED}Installation failed.${NC}"
        echo "  Make sure the platform bundle exists in: $script_dir/"
        echo "  Expected: secguardian-*-${platform}.tar.gz"
        exit 1
    }

    case "$cmd" in
        claude|claude-code)
            install_claude "$src"
            ;;
        nga|opencode)
            install_opencode "$src"
            ;;
        cac|gemini|gemini-cli)
            install_gemini "$src"
            ;;
        all)
            install_claude "$src"
            install_opencode "$src"
            install_gemini "$src"
            ;;
        *)
            rm -rf "$src"
            echo -e "${RED}Unknown target:${NC} $cmd"
            echo "  Available: claude  nga  cac  all"
            exit 1
            ;;
    esac

    # 清理临时目录
    rm -rf "$src"

    echo ""
    echo -e "${GREEN}Done.${NC} Restart your AI CLI to use /secguard /secaudit /secreview /secfix."
}

main "$@"
