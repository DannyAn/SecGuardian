#!/bin/bash
# SecGuardian — 共享扫描初始化脚本
#
# 被三个命令模板（secguard/secaudit/secreview）的 Step 1 调用，
# 替代复制粘贴的 ~40 行 bash 初始化代码。
#
# 用法:  source scripts/init-scan.sh <command> <path>
#
#   <command>  secguard | secaudit | secreview
#   <path>     扫描目标路径（如 ./src）
#
# 设置（被 source 后，在调用者 shell 中可用）:
#   SECGUARDIAN_HOME  插件根目录
#   USER_PROJECT      用户项目根目录（<path> 的父目录）
#   SCAN_ID           扫描 ID
#   SCAN_DIR          扫描输出目录
#   RECORDER          record-finding.py 路径
#
# 副作用:
#   创建 $SCAN_DIR 及子目录
#   写入 .scan_state.<command> 供后续 bash 调用 source
#
# 示例:
#   source /path/to/scripts/init-scan.sh secguard ./src
#   source /path/to/scripts/init-scan.sh secreview ./src

set -euo pipefail

# ── 参数解析 ──────────────────────────────
COMMAND="${1:?FATAL: missing command — need secguard|secaudit|secreview}"
SCAN_PATH="${2:?FATAL: missing scan path}"

case "$COMMAND" in
  secguard)  SCAN_ID_PREFIX="sc";  SUBDIR="secguard"  ;;
  secaudit)  SCAN_ID_PREFIX="sec"; SUBDIR="secaudit"  ;;
  secreview) SCAN_ID_PREFIX="pr";  SUBDIR="secreview" ;;
  *) echo "FATAL: unknown command '$COMMAND' (must be secguard/secaudit/secreview)"; exit 1 ;;
esac

# ── Phase A: SECGUARDIAN_HOME 自动发现 ────
# 如果调用者已设置，优先使用（跳过搜索）
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
  for candidate in \
    "/root/.config/opencode/extensions/secguardian" \
    "$HOME/.config/opencode/extensions/secguardian" \
    "$HOME/.claude/plugins/secguardian" \
    "$HOME/.gemini/extensions/secguardian" \
    "."; do
    if [ -f "$candidate/scripts/record-finding.py" ]; then
      export SECGUARDIAN_HOME="$candidate"
      break
    fi
  done
fi
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
  echo "FATAL: Cannot locate secguardian installation (no SECGUARDIAN_HOME with scripts/)"
  echo "  Tried: /root/.config/opencode/extensions/secguardian,"
  echo "         \$HOME/.config/opencode/extensions/secguardian,"
  echo "         \$HOME/.claude/plugins/secguardian,"
  echo "         \$HOME/.gemini/extensions/secguardian,"
  echo "         . (project root)"
  exit 1
fi
echo "SECGUARDIAN_HOME=$SECGUARDIAN_HOME"

# ── Phase B: 索引器健康检查 ──────────────
if ! "$SECGUARDIAN_HOME/scripts/secguardian-index" --health; then
  echo "FATAL: secguardian-index health check failed"
  exit 1
fi

# ── Phase C: 扫描路径确认 + USER_PROJECT ─
test -d "$SCAN_PATH" || { echo "FATAL: scan path $SCAN_PATH not found"; exit 1; }
USER_PROJECT="$(cd "$(dirname "$SCAN_PATH")" && pwd)"
cd "$USER_PROJECT"
echo "USER_PROJECT=$USER_PROJECT"

# ── Phase D: SCAN_ID 生成 + 目录创建 ────
if command -v openssl &>/dev/null; then
  SCAN_ID="${SCAN_ID_PREFIX}-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)"
else
  SCAN_ID="${SCAN_ID_PREFIX}-$(date +%Y%m%d-%H%M%S)-${RANDOM:-0}"
fi
SCAN_DIR="$USER_PROJECT/.codeagent/secguardian/$SUBDIR/scans/$SCAN_ID"
mkdir -p "$SCAN_DIR"
echo "SCAN_ID=$SCAN_ID"
echo "SCAN_DIR=$SCAN_DIR"

# ── Phase E: 命令特有子目录 ──────────────
case "$COMMAND" in
  secguard)  mkdir -p "$SCAN_DIR/workers" "$SCAN_DIR/findings" ;;
  secaudit)  mkdir -p "$SCAN_DIR/findings" ;;
  secreview) mkdir -p "$SCAN_DIR/findings" ;;
esac

# ── Phase F: 状态文件持久化 ──────────────
RECORDER="$SECGUARDIAN_HOME/scripts/record-finding.py"
cat > "$USER_PROJECT/.codeagent/secguardian/.scan_state.$COMMAND" << STATEEOF
USER_PROJECT="$USER_PROJECT"
SCAN_ID="$SCAN_ID"
SCAN_DIR="$SCAN_DIR"
SECGUARDIAN_HOME="$SECGUARDIAN_HOME"
RECORDER="$RECORDER"
STATEEOF
echo "  init complete: $SCAN_DIR"
