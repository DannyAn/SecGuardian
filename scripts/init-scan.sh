#!/bin/bash
# SecGuardian — 共享扫描初始化脚本
#
# 被三个命令模板（secguard/secaudit/secreview）的 Step 1 调用。
# SECGUARDIAN_HOME 从脚本自身路径推导（<install>/scripts/init-scan.sh），
# 不进行多路径遍历搜索 — 减少不必要的权限弹窗。
#
# 用法:  source scripts/init-scan.sh <command> <path> [language]
#
#   <command>    secguard | secaudit | secreview
#   <path>       扫描目标路径（如 ./src）
#   <language>   可选，语言（cpp/java/python/go/js）。未传时从文件扩展名自动检测
#
# 设置（被 source 后，在调用者 shell 中可用）:
#   SECGUARDIAN_HOME, USER_PROJECT, SCAN_ID, SCAN_DIR, SCAN_LANG, RECORDER
#
# 副作用:
#   创建 $SCAN_DIR 及子目录
#   写入 .scan_state.<command> 供后续 bash 调用 source
#
# 示例:
#   source /path/to/scripts/init-scan.sh secguard ./src cpp
#   source /path/to/scripts/init-scan.sh secreview ./src

set -euo pipefail

# ── 参数解析 ──────────────────────────────
COMMAND="${1:?FATAL: missing command — need secguard|secaudit|secreview}"
SCAN_PATH="${2:?FATAL: missing scan path}"
SCAN_LANG_IN="${3:-}"  # 可选，未传时自动检测

case "$COMMAND" in
  secguard)  SCAN_ID_PREFIX="sc";  SUBDIR="secguard"  ;;
  secaudit)  SCAN_ID_PREFIX="sec"; SUBDIR="secaudit"  ;;
  secreview) SCAN_ID_PREFIX="pr";  SUBDIR="secreview" ;;
  *) echo "FATAL: unknown command '$COMMAND' (must be secguard/secaudit/secreview)"; exit 1 ;;
esac

# ── Phase A: SECGUARDIAN_HOME 从自身路径推导 ────
# init-scan.sh 位于 <install>/scripts/init-scan.sh，2 层父目录即安装根
# zsh compat: BASH_SOURCE is bash-only, zsh uses $0.
# MUST use ${var+x} check (NOT ${BASH_SOURCE[0]:-$0}) —zsh set -u fails on
# subscript of unset array before fallback is evaluated.
if [ -n "${BASH_SOURCE+x}" ]; then
  SRC="${BASH_SOURCE[0]}"
else
  SRC="$0"
fi
# Use cd -P to resolve symlinks ($SRC may be skills/{lang}/scripts/ → ../../scripts/)
SCRIPT_DIR="$(cd -P "$(dirname "$SRC")" && pwd)"
SECGUARDIAN_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
echo "SECGUARDIAN_HOME=$SECGUARDIAN_HOME"

# ── Phase B: 扫描路径确认 + USER_PROJECT ──
test -d "$SCAN_PATH" || { echo "FATAL: scan path $SCAN_PATH not found"; exit 1; }
USER_PROJECT="$(cd "$(dirname "$SCAN_PATH")" && pwd)"
cd "$USER_PROJECT"
echo "USER_PROJECT=$USER_PROJECT"

# ── Phase C: 语言检测 ─────────────────────
# 优先使用调用者传入的语言；未传入时从文件扩展名自动检测
SCAN_LANG="$SCAN_LANG_IN"
case "$SCAN_LANG" in
  c|cc|cxx) SCAN_LANG="cpp" ;;
  javascript|typescript|ts) SCAN_LANG="js" ;;
esac
if [ -z "$SCAN_LANG" ]; then
  if find "$SCAN_PATH" -maxdepth 4 -name '*.java' 2>/dev/null | grep -q .; then
    SCAN_LANG="java"
  elif find "$SCAN_PATH" -maxdepth 4 -name '*.py' 2>/dev/null | grep -q .; then
    SCAN_LANG="python"
  elif find "$SCAN_PATH" -maxdepth 4 -name '*.go' 2>/dev/null | grep -q .; then
    SCAN_LANG="go"
  elif find "$SCAN_PATH" -maxdepth 4 \( -name '*.cpp' -o -name '*.cc' -o -name '*.c' -o -name '*.hpp' -o -name '*.h' \) 2>/dev/null | grep -q .; then
    SCAN_LANG="cpp"
  elif find "$SCAN_PATH" -maxdepth 4 \( -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' \) 2>/dev/null | grep -q .; then
    SCAN_LANG="js"
  else
    SCAN_LANG="unknown"
  fi
fi
echo "SCAN_LANG=$SCAN_LANG"

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

# ── Phase E: 确定 skill 脚本目录 ───────────
# 每个 skill 下有 scripts/ symlink → ../../scripts/（同一物理文件）
case "$COMMAND" in
  secguard)  SKILL_DIR="secguard-${SCAN_LANG}" ;;
  secaudit)  SKILL_DIR="secaudit-secaudit" ;;
  secreview) SKILL_DIR="secreview-${SCAN_LANG}" ;;
esac
SCRIPTS_DIR="$SECGUARDIAN_HOME/skills/${SKILL_DIR}/scripts"
RULES_DIR="$SECGUARDIAN_HOME/skills/${SKILL_DIR}/rules"
if [ "$COMMAND" = "secguard" ] && [ ! -d "$RULES_DIR" ]; then
  echo "FATAL: rules directory not found: $RULES_DIR"
  exit 1
fi

# ── Phase F: 命令特有子目录 ──────────────
case "$COMMAND" in
  secguard)
    mkdir -p "$SCAN_DIR/workers" "$SCAN_DIR/findings"
    # 为已知 detector 预创建 workers/ 子目录，确保每个 Worker 有输出位置
    if [ "$SCAN_LANG" = "cpp" ]; then
      for det in buffer_overflow null_dereference memory_leak double_free \
          use_after_free integer_overflow resource_leak command_injection \
          input_validation hardcoded_secrets must_check mismatched_free \
          api_semantic_misuse lock_misuse error_propagation uninitialized; do
        mkdir -p "$SCAN_DIR/workers/$det"
      done
    fi
    ;;
  secaudit)  mkdir -p "$SCAN_DIR/findings" ;;
  secreview) mkdir -p "$SCAN_DIR/findings" ;;
esac

# ── Phase G: 状态文件持久化 ──────────────
RECORDER="$SCRIPTS_DIR/record-finding.py"
cat > "$USER_PROJECT/.codeagent/secguardian/.scan_state.$COMMAND" << STATEEOF
USER_PROJECT="$USER_PROJECT"
SCAN_PATH="$SCAN_PATH"
SCAN_LANG="$SCAN_LANG"
SCAN_ID="$SCAN_ID"
SCAN_DIR="$SCAN_DIR"
SECGUARDIAN_HOME="$SECGUARDIAN_HOME"
SCRIPTS_DIR="$SCRIPTS_DIR"
SKILL_DIR="$SKILL_DIR"
RULES_DIR="$RULES_DIR"
RECORDER="$RECORDER"
STATEEOF
echo "  init complete: $SCAN_DIR"
