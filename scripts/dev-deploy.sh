#!/bin/bash
# SecGuardian — 一键构建 + 三平台部署（开发用）
#
# 用法:
#   bash scripts/dev-deploy.sh               # 构建 + 部署全部平台
#   bash scripts/dev-deploy.sh --user        # 构建 + 用户级部署
#   bash scripts/dev-deploy.sh --reset       # 完整重置: 卸载 → 构建 → 部署 → 验证
#   bash scripts/dev-deploy.sh --verify      # 部署后自动验证
#   bash scripts/dev-deploy.sh --reset --verify  # 完整重置 + 验证
#   bash scripts/dev-deploy.sh --uninstall   # 仅卸载项目级安装
#   bash scripts/dev-deploy.sh --clean-scans # 同时清理 .codeagent/ 扫描数据
#   bash scripts/dev-deploy.sh -h            # 显示帮助
#
# 每次执行保证:
#   1. 清理旧 dist/ 产物
#   2. 重新跨平台编译 + 组装
#   3. 彻底清理旧部署目标再写入
#   4. 确保每次部署都是最新的代码，无残留

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DO_USER=false
DO_RESET=false
DO_VERIFY=false
DO_UNINSTALL=false
DO_CLEAN_SCANS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            cat << 'EOF'
SecGuardian — 一键构建 + 三平台部署（开发用）

用法:
  bash scripts/dev-deploy.sh               # 构建 + 项目级部署至全部 3 个平台
  bash scripts/dev-deploy.sh --user        # 构建 + 用户级部署至全部 3 个平台
  bash scripts/dev-deploy.sh --reset       # 完整重置: 卸载 → 构建 → 部署 → 验证
  bash scripts/dev-deploy.sh --verify      # 部署后自动验证部署健康
  bash scripts/dev-deploy.sh --uninstall   # 仅卸载项目级安装
  bash scripts/dev-deploy.sh --clean-scans # 一并清理 .codeagent/ 扫描输出
  bash scripts/dev-deploy.sh -h            # 显示此帮助

覆盖场景:
  日常开发:
    bash scripts/dev-deploy.sh             # 修改 skills/knowledge 后重新部署

  修改索引器后:
    bash scripts/dev-deploy.sh --verify    # 重新部署 + 验证索引器正常工作

  完整自检:
    bash scripts/dev-deploy.sh --reset     # 卸载干净 → 重装 → 验证一切正常

  完全清理:
    bash scripts/dev-deploy.sh --uninstall --clean-scans   # 抹掉一切痕迹

调试帮助:
  bash scripts/package.sh -h
  bash scripts/deploy.sh -h
  bash scripts/dev-verify.sh -h
EOF
            exit 0
            ;;
        --user)          DO_USER=true; shift ;;
        --reset)         DO_RESET=true; shift ;;
        --verify)        DO_VERIFY=true; shift ;;
        --uninstall)     DO_UNINSTALL=true; shift ;;
        --clean-scans)   DO_CLEAN_SCANS=true; shift ;;
        *)              shift ;;
    esac
done

# ── Build deploy.sh extra args ──────────────
EXTRA_ARGS=""
$DO_USER && EXTRA_ARGS="$EXTRA_ARGS --user"

# ── Handle uninstall-only path ──────────────
if $DO_UNINSTALL && ! $DO_RESET; then
    echo "═══ 卸载项目级部署 ═══"
    bash "$PROJECT_ROOT/scripts/deploy.sh" all --uninstall $EXTRA_ARGS
    if $DO_CLEAN_SCANS; then
        echo ""
        echo "═══ 清理扫描数据 ═══"
        for dir in "$PROJECT_ROOT/.codeagent"/*/; do
            [ -d "$dir" ] && rm -rf "$dir" && echo "  ✓ 已移除: $dir"
        done
        echo "  ✓ .codeagent/ 扫描数据已清空"
    fi
    echo ""
    echo "卸载完成。重新部署: bash scripts/dev-deploy.sh"
    exit 0
fi

# ── Reset: uninstall first ──────────────────
if $DO_RESET; then
    echo "╔══════════════════════════════════════════════╗"
    echo "║  SecGuardian — 完整重置 (RESET)              ║"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "═══ 第1步: 卸载旧部署 ═══"
    bash "$PROJECT_ROOT/scripts/deploy.sh" all --uninstall $EXTRA_ARGS
    echo ""
fi

if $DO_CLEAN_SCANS; then
    echo "═══ 清理扫描数据 ═══"
    for dir in "$PROJECT_ROOT/.codeagent"/*/; do
        [ -d "$dir" ] && rm -rf "$dir" && echo "  ✓ 已移除: $dir"
    done
    echo "  ✓ .codeagent/ 扫描数据已清空"
    echo ""
fi

# ── Step 0: clean old dist/ ──────────────────
echo "═══ 清理旧 dist/ ═══"
rm -rf "$PROJECT_ROOT/dist"/*
echo "  ✓ dist/ 已清空"

# ── Step 1: rebuild ─────────────────────────
echo ""
echo "═══ 重新构建 ═══"
bash "$PROJECT_ROOT/scripts/package.sh"

# ── Step 2: deploy ──────────────────────────
echo ""
$DO_RESET && echo "═══ 第3步: 重新部署 ═══"
bash "$PROJECT_ROOT/scripts/deploy.sh" all $EXTRA_ARGS

# ── Step 3: verify (optional) ───────────────
if $DO_VERIFY || $DO_RESET; then
    echo ""
    echo "═══ 验证部署 ═══"
    bash "$PROJECT_ROOT/scripts/dev-verify.sh"
    VERIFY_EXIT=$?
    echo ""
    if [ $VERIFY_EXIT -eq 0 ]; then
        echo "✓ 部署验证通过"
    else
        echo "✗ 部署验证发现问题，请检查上述 [FAIL] 项"
        exit 1
    fi
fi

# ── Summary ──────────────────────────────────
if $DO_RESET; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║  ✓ 重置完成                                  ║"
    echo "╚══════════════════════════════════════════════╝"
fi
