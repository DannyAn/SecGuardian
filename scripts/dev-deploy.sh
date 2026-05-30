#!/bin/bash
# SecGuardian — 一键构建 + 三平台部署（开发用）
#
# 用法:
#   bash scripts/dev-deploy.sh          # 构建 + 部署全部平台
#   bash scripts/dev-deploy.sh --user   # 构建 + 用户级部署
#   bash scripts/dev-deploy.sh -h       # 显示帮助
#
# 每次执行保证:
#   1. 清理旧 dist/ 产物
#   2. 重新跨平台编译 + 组装
#   3. 彻底清理旧部署目标再写入
#   4. 确保每次部署都是最新的代码，无残留

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

EXTRA_ARGS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            cat << 'EOF'
SecGuardian — 一键构建 + 三平台部署（开发用）

用法:
  bash scripts/dev-deploy.sh          # 构建 + 项目级部署至全部 3 个平台
  bash scripts/dev-deploy.sh --user   # 构建 + 用户级部署至全部 3 个平台
  bash scripts/dev-deploy.sh -h       # 显示此帮助
  bash scripts/dev-deploy.sh --uninstall  # 卸载全部项目级安装

每次执行保证:
  1. 清理旧 dist/ → 干净构建
  2. 重新跨平台编译 Go 索引器
  3. 重新组装 extension 包
  4. 清理旧部署目标目录再写入
  5. 每次部署都是最新的代码，无残留

如需单独部署某个平台:
  bash scripts/deploy.sh cc     # 仅 Claude Code
  bash scripts/deploy.sh nga    # 仅 OpenCode
  bash scripts/deploy.sh cac    # 仅 Gemini CLI

卸载:
  bash scripts/dev-deploy.sh --uninstall         # 项目级卸载
  bash scripts/dev-deploy.sh --user --uninstall  # 用户级卸载

调试帮助:
  bash scripts/package.sh -h
  bash scripts/deploy.sh -h
EOF
            exit 0
            ;;
        --user)      EXTRA_ARGS="$EXTRA_ARGS --user"; shift ;;
        --uninstall) EXTRA_ARGS="$EXTRA_ARGS --uninstall"; shift ;;
        *)           shift ;;
    esac
done

# Step 0: clean old dist/ for every dev build (guarantees fresh)
echo "═══ 清理旧 dist/ ═══"
rm -rf "$PROJECT_ROOT/dist"/*
echo "  ✓ dist/ 已清空"

# Step 1: rebuild
echo ""
echo "═══ 重新构建 ═══"
bash "$PROJECT_ROOT/scripts/package.sh"

# Step 2: deploy
echo ""
bash "$PROJECT_ROOT/scripts/deploy.sh" all $EXTRA_ARGS