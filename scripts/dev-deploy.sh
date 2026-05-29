#!/bin/bash
# SecGuardian — 一键构建 + 三平台部署
#
# 用法:
#   bash scripts/dev-deploy.sh       # 构建 + 部署全部平台
#   bash scripts/dev-deploy.sh -h    # 显示帮助
#
# 这是开发阶段最常用的命令，等价于:
#   bash scripts/package.sh && bash scripts/deploy.sh all
#
# 部署目标:
#   Claude Code  → .claude/extensions/
#   OpenCode     → .opencode/ (commands + skills + knowledge + scripts)
#   Gemini CLI   → .gemini/   (commands + skills + knowledge + scripts)

set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — 一键构建 + 三平台部署

用法:
  bash scripts/dev-deploy.sh         # 构建 + 部署至全部 3 个平台
  bash scripts/dev-deploy.sh -h      # 显示此帮助

这是开发阶段最常用的命令。它依次执行:
  1. scripts/package.sh — 跨平台编译 + 组装 dist/
  2. scripts/deploy.sh all — 部署至 Claude Code / OpenCode / Gemini CLI

部署后:
  - 重启 AI CLI
  - Claude Code:  /secguard, /secaudit, /secreview
  - OpenCode:     /secguard, /secaudit, /secreview
  - Gemini CLI:   /skills reload → /secguard, /secaudit, /secreview

如需单独部署某个平台:
  bash scripts/deploy.sh cc     # 仅 Claude Code
  bash scripts/deploy.sh nga    # 仅 OpenCode
  bash scripts/deploy.sh cac    # 仅 Gemini CLI

如需调试帮助:
  bash scripts/package.sh -h
  bash scripts/deploy.sh -h
EOF
    exit 0
fi

exec bash "$(dirname "$0")/deploy.sh" all