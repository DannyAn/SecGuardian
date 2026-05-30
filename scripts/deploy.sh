#!/bin/bash
# SecGuardian — 统一部署脚本
# 用法: bash scripts/deploy.sh <platform> [--user] [--zip]
#       bash scripts/deploy.sh all
#       bash scripts/deploy.sh cc|nga|cac
#
# 前置条件: dist/ 已通过 package.sh 构建完成
# 会先自动检查 dist/ 是否就绪，否则先执行 package.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$PROJECT_ROOT/dist"
DEPLOY_USER=false   # 默认项目级，--user 切换为用户级

# ── Help ──────────────────────────────────────
show_help() {
    cat << 'EOF'
SecGuardian — 部署脚本

将构建好的 dist/ 部署到 AI CLI 平台。

用法:
  bash scripts/deploy.sh <platform> [--user] [--zip]

平台:
  all      三平台全部部署 (默认)
  cc       Claude Code    → .claude/extensions/
  nga      OpenCode       → .opencode/ (commands + skills + knowledge + scripts)
  cac      Gemini CLI     → .gemini/ (commands + skills + knowledge + scripts)

选项:
  --user   部署到用户家目录（推荐，跨项目共用）
  --zip    部署后生成发布压缩包 → dist/archives/

示例:
  bash scripts/deploy.sh all --user     # 用户级部署到 ~/
  bash scripts/deploy.sh cc             # 项目级部署 Claude Code
  bash scripts/deploy.sh all --zip      # 项目级部署 + 打包发布
EOF
    exit 0
}

# ── 解析参数 ──────────────────────────────────
PLATFORM="${1:-all}"
shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) DEPLOY_USER=true; shift ;;
        --zip) DO_ZIP=true; shift ;;
        -h|--help|help) show_help ;;
        *) shift ;;
    esac
done

case "$PLATFORM" in
    -h|--help|help) show_help ;;
    all|cc|nga|cac) ;;
    *)
        echo "未知参数: $PLATFORM"
        echo "用法: bash scripts/deploy.sh [all|cc|nga|cac|-h]"
        exit 1
        ;;
esac

# ── 部署目标路径 ──────────────────────────────
if $DEPLOY_USER; then
    TARGET_ROOT="$HOME"
    DEPLOY_MODE="用户级"
    DEPLOY_MODE_DESC="跨所有项目可用"
else
    TARGET_ROOT="$PROJECT_ROOT"
    DEPLOY_MODE="项目级"
    DEPLOY_MODE_DESC="仅当前项目可用"
fi

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

# ── Shared binary deployment (idempotent) ────────
deploy_binary() {
    local target_dir="$1"
    mkdir -p "$target_dir"
    local target="$target_dir/secguardian-index"

    # Idempotency check: if existing binary reports same version, skip
    if [ -x "$target" ]; then
        local existing_ver=$("$target" --version 2>/dev/null || echo "unknown")
        for d in "$DIST"/*/; do
            if [ -x "$d/scripts/secguardian-index" ]; then
                local new_ver=$("$d/scripts/secguardian-index" --version 2>/dev/null || echo "unknown")
                if [ "$existing_ver" = "$new_ver" ] && [ -n "$existing_ver" ] && [ "$existing_ver" != "unknown" ]; then
                    log_info "indexer binary already up-to-date ($existing_ver) at $target_dir/"
                    return 0
                fi
            fi
        done
    fi

    # Atomic replacement: write to .tmp first, then mv
    for d in "$DIST"/*/; do
        if [ -x "$d/scripts/secguardian-index" ]; then
            cp "$d/scripts/secguardian-index" "${target}.tmp"
            chmod +x "${target}.tmp"
            # Verify the new binary works before replacing
            if "${target}.tmp" --version >/dev/null 2>&1; then
                mv "${target}.tmp" "$target"
                local ver=$("$target" --version 2>/dev/null || echo "unknown")
                log_info "indexer binary deployed ($ver) to $target_dir/"
                return 0
            else
                rm -f "${target}.tmp"
                log_info "indexer binary verification failed — keeping existing version"
                return 1
            fi
        fi
    done
    return 1
}

# ── Claude Code ────────────────────────────────
deploy_claude() {
    log_step "Claude Code → .claude/extensions/"
    local ext_dir="$TARGET_ROOT/.claude/extensions"
    rm -rf "$ext_dir"
    mkdir -p "$ext_dir"

    for d in "$DIST"/*/; do
        local name=$(basename "$d")
        cp -r "$d" "$ext_dir/$name"
        local s=$(find "$d/skills" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
        local c=$(ls "$d/commands/" 2>/dev/null | wc -l | tr -d ' ')
        log_done "$name — $c commands, $s skills"
    done

    deploy_binary "$PROJECT_ROOT/scripts" 2>/dev/null || true

    echo ""
    log_info "Claude Code 命令（重启后生效）:"
    echo "    /secguard <path> [mode] [filters]"
    echo "    /secaudit <skill-name>"
    echo "    /secreview <path> [language]"
}

# ── OpenCode ────────────────────────────────────
deploy_opencode() {
    log_step "OpenCode → .opencode/ (完整布局: commands/ + skills/ + knowledge/ + scripts/)"

    local opencode_dir="$TARGET_ROOT/.opencode"
    local cmd_dir="$opencode_dir/commands"
    local skills_dir="$opencode_dir/skills"
    local knowledge_dir="$opencode_dir/knowledge"
    local scripts_dir="$opencode_dir/scripts"

    # Clean and recreate target dirs
    rm -rf "$cmd_dir" "$skills_dir" "$knowledge_dir" "$scripts_dir"
    mkdir -p "$cmd_dir" "$skills_dir" "$scripts_dir/bin" \
             "$knowledge_dir/concepts" "$knowledge_dir/languages" \
             "$knowledge_dir/detectors" "$knowledge_dir/protocols"

    local cmd_n=0 skill_n=0
    for d in "$DIST"/*/; do
        # Commands: .md files are OpenCode slash commands
        if [ -d "$d/commands" ]; then
            for f in "$d/commands"/*.md; do
                [ -f "$f" ] && cp "$f" "$cmd_dir/" && cmd_n=$((cmd_n + 1))
            done
        fi
        # Skills: all skill directories
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$skills_dir/$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
        # Knowledge: merge across all extensions
        for cat in concepts languages detectors protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
            fi
        done
    done
    log_done "$cmd_n commands (.md), $skill_n skills"

    # Copy wrapper scripts and binaries
    for wrapper in secguardian-index secguardian-index.ps1; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$scripts_dir/$wrapper"
            chmod +x "$scripts_dir/$wrapper" 2>/dev/null || true
        fi
    done
    local bin_src="$PROJECT_ROOT/scripts/bin"
    if [ -d "$bin_src" ]; then
        cp -r "$bin_src/"* "$scripts_dir/bin/" 2>/dev/null || true
        chmod +x "$scripts_dir/bin/"* 2>/dev/null || true
        log_done "cross-platform binaries in .opencode/scripts/bin/"
    fi

    echo ""
    log_info "OpenCode 使用方式（重启后生效）:"
    echo "    /secaudit (command from .md file)"
    echo "    /secguard (command from .md file)"
    echo "    /secreview (command from .md file)"
}

# ── Gemini CLI ───────────────────────────────────
deploy_gemini() {
    log_step "Gemini CLI → .gemini/ (commands/ + skills/ + knowledge/ + scripts/)"

    local gemini_dir="$TARGET_ROOT/.gemini"
    local skills_dir="$gemini_dir/skills"
    local cmd_dir="$gemini_dir/commands"
    local knowledge_dir="$gemini_dir/knowledge"
    local scripts_dir="$gemini_dir/scripts"

    # Clean and recreate target dirs
    rm -rf "$skills_dir" "$cmd_dir" "$knowledge_dir" "$scripts_dir"
    mkdir -p "$skills_dir" "$cmd_dir" "$scripts_dir/bin" \
             "$knowledge_dir/concepts" "$knowledge_dir/languages" \
             "$knowledge_dir/detectors" "$knowledge_dir/protocols"

    local skill_n=0
    for d in "$DIST"/*/; do
        # Skills: all skill directories
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$skills_dir/$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
        # Knowledge: merge across all extensions at top level
        for cat in concepts languages detectors protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
            fi
        done
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

    # Copy wrapper scripts and cross-platform binaries
    for wrapper in secguardian-index secguardian-index.ps1; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$scripts_dir/$wrapper"
            chmod +x "$scripts_dir/$wrapper" 2>/dev/null || true
        fi
    done
    local bin_src="$PROJECT_ROOT/scripts/bin"
    if [ -d "$bin_src" ]; then
        cp -r "$bin_src/"* "$scripts_dir/bin/" 2>/dev/null || true
        chmod +x "$scripts_dir/bin/"* 2>/dev/null || true
    fi

    # 生成 Gemini 上下文文件
    cat > "$gemini_dir/GEMINI.md" << 'MD'
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

## 辅助工具

本项目提供了预编译的代码索引器：

| 平台 | 脚本 |
|------|------|
| macOS / Linux | `scripts/secguardian-index --path <dir> --output <file>` |
| Windows | `scripts/secguardian-index.ps1 --path <dir> --output <file>` |

索引器命令：
- `--path <dir>` — 指定源码目录
- `--output <file>` — 指定索引输出文件（JSON）
- `--version` — 查看版本
- `--health` — 自检可用性
MD

    log_done "$skill_n skills + $cmd_n commands (.toml) + knowledge/ + scripts/ + GEMINI.md"

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
        [ "$name" = "release" ] && continue
        local zipfile="$archive_dir/cc-${name}.zip"
        (cd "$DIST" && zip -rq "$zipfile" "$name")
        log_done "cc-${name}.zip"
    done

    # OpenCode: 完整布局 (commands/ + skills/ + knowledge/ + scripts/)
    if [ -d "$TARGET_ROOT/.opencode/commands" ]; then
        local nga_zip="$archive_dir/nga-secguardian.zip"
        (cd "$TARGET_ROOT/.opencode" && zip -rq "$nga_zip" commands/ skills/ knowledge/ scripts/ 2>/dev/null || \
         zip -rq "$nga_zip" commands/)
        log_done "nga-secguardian.zip"
    fi

    # Gemini CLI: 完整布局 (skills/ + knowledge/ + commands/ + scripts/ + GEMINI.md)
    if [ -d "$TARGET_ROOT/.gemini/skills" ]; then
        local cac_zip="$archive_dir/cac-secguardian.zip"
        (cd "$TARGET_ROOT/.gemini" && zip -rq "$cac_zip" skills/ knowledge/ commands/ scripts/ GEMINI.md 2>/dev/null || \
         zip -rq "$cac_zip" skills/ commands/ GEMINI.md)
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
