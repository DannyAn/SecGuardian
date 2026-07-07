#!/bin/bash
# SecGuardian — 统一卸载器
#
# 从指定 AI Agent 卸载 SecGuardian。
#
# 用法:
#   bash uninstall.sh claude             # 卸载 Claude Code
#   bash uninstall.sh nga                # 卸载 OpenCode
#   bash uninstall.sh cac                # 卸载 Gemini CLI
#   bash uninstall.sh all                # 卸载全部三个平台
#   bash uninstall.sh --help             # 查看帮助

set -euo pipefail

CLAUDE_DIR="$HOME/.claude/plugins/secguardian"
NGA_DIR="$HOME/.config/opencode/extensions/secguardian"
CAC_DIR="$HOME/.gemini/extensions/secguardian"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

show_help() {
    cat << 'USAGE'
用法: bash uninstall.sh [目标]

目标:
  claude      卸载 Claude Code  (rm -rf ~/.claude/plugins/secguardian/)
  nga         卸载 OpenCode      (rm -rf ~/.config/opencode/extensions/secguardian/)
  cac         卸载 Gemini CLI    (rm -rf ~/.gemini/extensions/secguardian/)
  all         卸载全部三个平台
  --help      显示此帮助
USAGE
}

uninstall_one() {
    local dir="$1" label="$2"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo -e "  ${GREEN}[OK]${NC} Removed ${CYAN}${dir}${NC}"
    else
        echo -e "  ${CYAN}[--]${NC} Not installed: ${dir}"
    fi
}

main() {
    local cmd="${1:-}"

    if [ "$cmd" = "--help" ] || [ "$cmd" = "-h" ] || [ -z "$cmd" ]; then
        show_help
        exit 0
    fi

    echo ""
    echo -e "${CYAN}SecGuardian Uninstaller${NC}"
    echo ""

    case "$cmd" in
        claude|claude-code)
            uninstall_one "$CLAUDE_DIR" "Claude Code"
            ;;
        nga|opencode)
            uninstall_one "$NGA_DIR" "OpenCode"
            ;;
        cac|gemini|gemini-cli)
            uninstall_one "$CAC_DIR" "Gemini CLI"
            ;;
        all)
            uninstall_one "$CLAUDE_DIR" "Claude Code"
            uninstall_one "$NGA_DIR" "OpenCode"
            uninstall_one "$CAC_DIR" "Gemini CLI"
            ;;
        *)
            echo -e "${RED}Unknown target:${NC} $cmd"
            echo "  Available: claude  nga  cac  all"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}Done.${NC}"
}

main "$@"
