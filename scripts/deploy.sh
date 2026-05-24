#!/bin/bash
# SecGuardian — 统一部署脚本
# 用法: bash scripts/deploy.sh <platform>
#       bash scripts/deploy.sh all
#       bash scripts/deploy.sh cc|nga|cac
#
# 前置条件: dist/ 已通过 package.sh 构建完成
# 会先自动检查 dist/ 是否就绪，否则先执行 package.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$PROJECT_ROOT/dist"
# ── Help ──────────────────────────────────────
show_help() {
    cat << 'EOF'
SecGuardian — 部署脚本

将构建好的 dist/ 部署到 AI CLI 平台。

用法:
  bash scripts/deploy.sh <platform> [--zip]

平台:
  all      三平台全部部署 (默认)
  cc       Claude Code    → .claude/extensions/
  nga      OpenCode       → .opencode/skills/ + .opencode/command/
  cac      Gemini CLI     → .gemini/skills/ + .gemini/commands/

选项:
  --zip    部署后生成发布压缩包 → dist/archives/

示例:
  bash scripts/deploy.sh all           # 部署到三平台
  bash scripts/deploy.sh cc            # 仅 Claude Code
  bash scripts/deploy.sh all --zip     # 部署三平台 + 打包发布
EOF
    exit 0
}

PLATFORM="${1:-all}"
case "$PLATFORM" in
    -h|--help|help) show_help ;;
    all|cc|nga|cac) ;;
    *)
        echo "未知参数: $PLATFORM"
        echo "用法: bash scripts/deploy.sh [all|cc|nga|cac|-h]"
        exit 1
        ;;
esac

# ── 工具函数 ──────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_step()  { echo -e "${BOLD}═══ $1 ═══${NC}"; }
log_info()  { echo -e "${CYAN}  →${NC} $1"; }
log_done()  { echo -e "${GREEN}  ✓${NC} $1"; }

# ── 前置检查 ──────────────────────────────────
ensure_dist() {
    if [ ! -d "$DIST" ] || [ -z "$(ls -A "$DIST" 2>/dev/null)" ]; then
        log_info "dist/ 为空，先执行构建..."
        bash "$PROJECT_ROOT/scripts/package.sh"
    fi
}

# ── Claude Code ────────────────────────────────
deploy_claude() {
    log_step "Claude Code → .claude/extensions/"
    local ext_dir="$PROJECT_ROOT/.claude/extensions"
    rm -rf "$ext_dir"
    mkdir -p "$ext_dir"

    for d in "$DIST"/*/; do
        local name=$(basename "$d")
        cp -r "$d" "$ext_dir/$name"
        local s=$(find "$d/skills" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
        local c=$(ls "$d/commands/" 2>/dev/null | wc -l | tr -d ' ')
        log_done "$name — $c commands, $s skills"
    done

    echo ""
    log_info "Claude Code 命令（重启后生效）:"
    echo "    /secguard <path> [mode] [filters]"
    echo "    /secaudit <skill-name>"
    echo "    /secreview <path> [language]"
}

# ── OpenCode ────────────────────────────────────
deploy_opencode() {
    log_step "OpenCode → .opencode/skills/ + .opencode/command/"

    local skills_dir="$PROJECT_ROOT/.opencode/skills"
    local cmd_dir="$PROJECT_ROOT/.opencode/command"
    rm -rf "$skills_dir" "$cmd_dir"
    mkdir -p "$skills_dir" "$cmd_dir"

    local skill_n=0
    for d in "$DIST"/*/; do
        [ -d "$d/skills" ] && for sd in "$d/skills"/*/; do
            cp -r "$sd" "$skills_dir/$(basename "$sd")"; skill_n=$((skill_n + 1))
        done
        [ -d "$d/knowledge" ] && cp -r "$d/knowledge" "$skills_dir/.knowledge-$(basename "$d")"
    done

    for d in "$DIST"/*/; do
        [ -d "$d/commands" ] && cp "$d/commands"/*.md "$cmd_dir/" 2>/dev/null || true
    done

    local cmd_n=$(ls "$cmd_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
    log_done "$skill_n skills + $cmd_n commands (.md)"

    echo ""
    log_info "OpenCode 使用方式（重启后生效）:"
    echo "    skill secguard-cpp"
    echo "    skill secaudit-taint-analysis"
    echo "    skill secreview-java"
    echo "    /secguard ./src cpp"
}

# ── Gemini CLI ───────────────────────────────────
deploy_gemini() {
    log_step "Gemini CLI → .gemini/skills/ + .gemini/commands/"

    local skills_dir="$PROJECT_ROOT/.gemini/skills"
    local cmd_dir="$PROJECT_ROOT/.gemini/commands"
    rm -rf "$skills_dir" "$cmd_dir"
    mkdir -p "$skills_dir" "$cmd_dir"

    local skill_n=0
    for d in "$DIST"/*/; do
        [ -d "$d/skills" ] && for sd in "$d/skills"/*/; do
            cp -r "$sd" "$skills_dir/$(basename "$sd")"; skill_n=$((skill_n + 1))
        done
        [ -d "$d/knowledge" ] && cp -r "$d/knowledge" "$skills_dir/.knowledge-$(basename "$d")"
    done

    # 自动从 .md 命令生成 TOML，再拷贝
    log_info "生成 Gemini TOML 命令..."
    bash "$PROJECT_ROOT/scripts/gen-toml.sh" > /dev/null

    local toml_src="$PROJECT_ROOT/commands/gemini"
    local cmd_n=0
    if [ -d "$toml_src" ]; then
        for f in "$toml_src"/*.toml; do
            cp "$f" "$cmd_dir/"; cmd_n=$((cmd_n + 1))
        done
    fi

    # 生成 Gemini 上下文文件
    cat > "$PROJECT_ROOT/.gemini/GEMINI.md" << 'MD'
# SecGuardian - 安全守卫

本项目配置了 SecGuardian 安全扫描能力。

## 可用安全命令

| 命令 | 用途 |
|------|------|
| `/secguard <path> [mode] [filters]` | 安全加固项排查 — 代码级漏洞检测 |
| `/secaudit <skill-name>` | 安全专项审计 — 深度安全分析 |
| `/secreview <path> [language]` | 安全规范检视 — 反模式和最佳实践 |

## 扫描输出

所有扫描结果写入 `.codeagent/<extension>/scans/<scan-id>/`。
MD

    log_done "$skill_n skills + $cmd_n commands (.toml) + GEMINI.md"

    echo ""
    log_info "Gemini CLI 使用方式:"
    echo "    /skills reload     # 重新扫描 skills"
    echo "    /secguard ./src cpp"
    echo "    /secaudit taint-analysis"
    echo "    /secreview ./src java"
}

# ── 打包发布 ────────────────────────────────────
do_zip() {
    local archive_dir="$DIST/archives"
    log_step "生成发布压缩包 → $archive_dir/"
    rm -rf "$archive_dir"
    mkdir -p "$archive_dir"

    # Claude Code: 每个 extension 一个 zip
    for d in "$DIST"/*/; do
        local name=$(basename "$d")
        [ "$name" = "archives" ] && continue
        local zipfile="$archive_dir/cc-${name}.zip"
        (cd "$DIST" && zip -rq "$zipfile" "$name")
        log_done "cc-${name}.zip"
    done

    # OpenCode: skills + commands 打成一个 zip
    if [ -d "$PROJECT_ROOT/.opencode/skills" ]; then
        local nga_zip="$archive_dir/nga-secguardian.zip"
        (cd "$PROJECT_ROOT/.opencode" && zip -rq "$nga_zip" skills/ command/)
        log_done "nga-secguardian.zip"
    fi

    # Gemini CLI: skills + commands 打成一个 zip
    if [ -d "$PROJECT_ROOT/.gemini/skills" ]; then
        local cac_zip="$archive_dir/cac-secguardian.zip"
        (cd "$PROJECT_ROOT/.gemini" && zip -rq "$cac_zip" skills/ commands/ GEMINI.md)
        log_done "cac-secguardian.zip"
    fi

    log_info "输出: $archive_dir/"
}

# ── 主流程 ──────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║${NC}  SecGuardian — 部署 ${PLATFORM}                             ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

ensure_dist

case "$PLATFORM" in
    all)
        deploy_claude
        echo ""
        deploy_opencode
        echo ""
        deploy_gemini
        ;;
    cc)  deploy_claude ;;
    nga) deploy_opencode ;;
    cac) deploy_gemini ;;
esac

# 如果带 --zip 参数则额外打包
if [ "${2:-}" = "--zip" ]; then
    echo ""
    do_zip
fi

echo ""
echo -e "${GREEN}部署完成。${NC}"
