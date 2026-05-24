#!/bin/bash
# SecGuardian — 统一构建 + 部署 + 打包脚本
#
# 用法: bash scripts/build.sh <target> [--zip]
#
# 目标:
#   all      三平台全部 (默认)
#   cc       Claude Code   → .claude/extensions/
#   nga      OpenCode      → .opencode/skills/ + .opencode/command/
#   cac      Gemini CLI    → .gemini/skills/ + .gemini/commands/
#
# 选项:
#   --zip    生成发布压缩包 → dist/archives/
#
# 实际逻辑委派到: package.sh + deploy.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-all}"
DO_ZIP=false

# 解析参数
if [ "${2:-}" = "--zip" ] || [ "${1:-}" = "--zip" ]; then
    DO_ZIP=true
    [ "$TARGET" = "--zip" ] && TARGET="all"
fi

# 验证目标
case "$TARGET" in
    all|cc|nga|cac) ;;
    *) echo "用法: bash scripts/build.sh [all|cc|nga|cac] [--zip]" && exit 1 ;;
esac

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  SecGuardian — 构建部署                      ║"
echo "║  目标: $TARGET                                  ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Step 1: 构建 dist/
echo "═══ 构建 extension 包 ═══"
bash "$PROJECT_ROOT/scripts/package.sh"

# Step 2: 部署
zip_flag=""
$DO_ZIP && zip_flag=" --zip"
bash "$PROJECT_ROOT/scripts/deploy.sh" "$TARGET" $zip_flag

echo ""
echo "✓ 完成。"
