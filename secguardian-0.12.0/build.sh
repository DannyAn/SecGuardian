#!/bin/bash
# SecGuardian — 统一构建 + 部署 + 打包脚本
#
# 用法: bash build.sh <target> [--zip]
#
# 目标:
#   all      三平台全部 (默认)
#   cc       Claude Code   → .claude/extensions/
#   nga      OpenCode      → .opencode/ (commands + skills + knowledge + scripts)
#   cac      Gemini CLI    → .gemini/   (commands + skills + knowledge + scripts)
#
# 选项:
#   --zip    生成发布压缩包 → dist/archives/
#
# 实际逻辑委派到: package.sh + deploy.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — 统一构建 + 部署 + 打包脚本

用法:
  bash build.sh <target> [--zip]
  bash build.sh -h

目标 (target):
  all      构建并部署到全部三个平台 (默认)
  cc       仅构建并部署到 Claude Code  → .claude/extensions/
  nga      仅构建并部署到 OpenCode     → .opencode/
  cac      仅构建并部署到 Gemini CLI   → .gemini/

选项:
  --zip    部署后生成发布压缩包 → dist/archives/

示例:
  bash build.sh all              # 构建 + 全平台部署
  bash build.sh cc               # 仅构建 + Claude Code 部署
  bash build.sh all --zip        # 构建 + 全平台部署 + 打包发布
  bash build.sh --zip            # 仅打包 (不部署)

注意:
  - 构建阶段会尝试跨平台编译 Go 索引器 (darwin-arm64/amd64, linux-amd64, windows-amd64)
  - 如果 Go 不可用，索引器二进制不会被编译，但 wrapper 脚本和 knowledge 仍会正常打包
  - 发布包在 dist/archives/ 下
  - 对于日常开发，推荐使用 bash scripts/deploy.sh all
EOF
    exit 0
fi

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
    *) echo "用法: bash build.sh [all|cc|nga|cac] [--zip]" && exit 1 ;;
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
