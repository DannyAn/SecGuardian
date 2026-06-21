#!/bin/bash
# SecGuardian — 版本号同步脚本
#
# 用法: bash scripts/sync-version.sh <new-version>
#       bash scripts/sync-version.sh 0.2.0
#
# 同步以下文件中的版本号:
#   - manifest.json (顶级 version)
#   - extensions/secguard-secguardian/extension.json
#   - extensions/secaudit-secguardian/extension.json
#   - extensions/secreview-secguardian/extension.json
#
# 无参数时打印当前版本号。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

FILES=(
    "$PROJECT_ROOT/manifest.json"
    "$PROJECT_ROOT/extensions/secguard-secguardian/extension.json"
    "$PROJECT_ROOT/extensions/secaudit-secguardian/extension.json"
    "$PROJECT_ROOT/extensions/secreview-secguardian/extension.json"
)

CURRENT=$(jq -r '.version' "$PROJECT_ROOT/manifest.json")

# ── Help ──────────────────────────────────────
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
    cat << EOF
SecGuardian — 版本号同步脚本

同步 manifest.json 和 3 个 extension.json 中的版本号。

用法:
  bash scripts/sync-version.sh               # 显示当前版本
  bash scripts/sync-version.sh <new-version>  # 同步到新版本
  bash scripts/sync-version.sh -h             # 显示此帮助

同步文件:
  - manifest.json
  - extensions/secguard-secguardian/extension.json
  - extensions/secaudit-secguardian/extension.json
  - extensions/secreview-secguardian/extension.json

当前版本: $CURRENT

示例:
  bash scripts/sync-version.sh          # 查看当前版本
  bash scripts/sync-version.sh 0.2.0    # 升级到 0.2.0
EOF
    exit 0
fi

NEW_VERSION="$1"

# 验证版本号格式（宽松: x.y.z）
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "错误: 版本号格式不正确，应为 x.y.z (如 0.2.0)"
    exit 1
fi

echo "==> 版本同步: $CURRENT → $NEW_VERSION"

for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  [SKIP] $f — 文件不存在"
        continue
    fi
    tmp="${f}.tmp"
    jq --arg v "$NEW_VERSION" '.version = $v' "$f" > "$tmp"
    mv "$tmp" "$f"
    echo "  ✓ $f"
done

# 同步 internal/main.go 中的版本常量
MAIN_GO="$PROJECT_ROOT/internal/main.go"
if [ -f "$MAIN_GO" ]; then
    sed -i.bak "s/const version = \".*\"/const version = \"$NEW_VERSION\"/" "$MAIN_GO"
    rm -f "${MAIN_GO}.bak"
    echo "  ✓ $MAIN_GO"
else
    echo "  [SKIP] internal/main.go — 文件不存在"
fi

echo ""
echo "版本同步完成: $NEW_VERSION"
echo "提示: 还需要更新 README.md 和 CHANGELOG 中的版本引用（如有）。"
