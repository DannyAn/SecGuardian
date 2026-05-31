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
DEPLOY_USER=false     # 默认项目级，--user 切换为用户级
DO_UNINSTALL=false
DO_ZIP=false

# ── Help ──────────────────────────────────────
show_help() {
    cat << 'EOF'
SecGuardian — 部署脚本

将构建好的 dist/ 部署到 AI CLI 平台。

用法:
  bash scripts/deploy.sh <platform> [--user] [--zip]
  bash scripts/deploy.sh <platform> --uninstall

平台:
  all      三平台全部 (默认)
  cc       Claude Code    → .claude/extensions/
  nga      OpenCode       → .opencode/ (commands + skills + knowledge + scripts)
  cac      Gemini CLI     → .gemini/ (commands + skills + knowledge + scripts)

选项:
  --user       部署到用户家目录（推荐，跨项目共用）
  --uninstall  卸载已安装的 secguardian 文件
  --zip        部署后生成发布压缩包 → dist/archives/

示例:
  bash scripts/deploy.sh all --user          # 用户级部署
  bash scripts/deploy.sh all --uninstall     # 卸载全部
  bash scripts/deploy.sh all --user --uninstall  # 卸载用户级安装
  bash scripts/deploy.sh cc                 # 项目级部署 Claude Code
EOF
    exit 0
}

# ── 解析参数 ──────────────────────────────────
PLATFORM="${1:-all}"
shift 2>/dev/null || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) DEPLOY_USER=true; shift ;;
        --uninstall) DO_UNINSTALL=true; shift ;;
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
    mkdir -p "$ext_dir"

    # Only remove our own extensions, leave others intact
    for our_name in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        rm -rf "$ext_dir/$our_name"
    done

    for d in "$DIST"/*/; do
        local name=$(basename "$d")
        rm -rf "$ext_dir/$name"  # Clean old version of this extension first
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

# ── 卸载 ──────────────────────────────────────
uninstall_claude() {
    local ext_dir="$TARGET_ROOT/.claude/extensions"
    local removed=0
    for name in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        if [ -d "$ext_dir/$name" ]; then
            rm -rf "$ext_dir/$name"
            log_done "已移除: $ext_dir/$name"
            removed=$((removed + 1))
        fi
    done
    if [ "$removed" -eq 0 ]; then
        log_info "Claude Code: 未找到已安装的 extension"
    fi
}

uninstall_opencode() {
    local oc_dir="$TARGET_ROOT/.opencode"
    local removed=0
    for sub in commands skills knowledge scripts; do
        if [ -d "$oc_dir/$sub" ]; then
            # Only remove if it looks like secguardian content
            rm -rf "$oc_dir/$sub"
            if [ "$sub" = "skills" ]; then
                log_done "已移除: $oc_dir/$sub/ (25 个 skill)"
            else
                log_done "已移除: $oc_dir/$sub/"
            fi
            removed=$((removed + 1))
        fi
    done
    if [ "$removed" -eq 0 ]; then
        log_info "OpenCode: 未找到已安装的 secguardian 内容"
    fi
}

uninstall_gemini() {
    local gm_dir="$TARGET_ROOT/.gemini"
    local removed=0
    for sub in commands skills knowledge scripts GEMINI.md; do
        if [ -e "$gm_dir/$sub" ]; then
            rm -rf "$gm_dir/$sub"
            log_done "已移除: $gm_dir/$sub"
            removed=$((removed + 1))
        fi
    done
    if [ "$removed" -eq 0 ]; then
        log_info "Gemini CLI: 未找到已安装的 secguardian 内容"
    fi
}

do_uninstall() {
    local plat="$1"
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  SecGuardian — 卸载 (${DEPLOY_MODE})                ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  目标: ${CYAN}$TARGET_ROOT${NC}"
    echo ""

    case "$plat" in
        all)
            uninstall_claude
            uninstall_opencode
            uninstall_gemini
            ;;
        cc)  uninstall_claude ;;
        nga) uninstall_opencode ;;
        cac) uninstall_gemini ;;
    esac

    echo ""
    log_done "卸载完成"
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
             "$knowledge_dir/languages" "$knowledge_dir/detectors" \
             "$knowledge_dir/protocols" "$knowledge_dir/standards"

    local cmd_n=0 skill_n=0
    for d in "$DIST"/*/; do
        # Commands: .md files are OpenCode slash commands
        if [ -d "$d/commands" ]; then
            for f in "$d/commands"/*.md; do
                [ -f "$f" ] && cp "$f" "$cmd_dir/" && cmd_n=$((cmd_n + 1))
            done
        fi
        # Skills: deploy under secguardian-xuanwu extension namespace
        local ext_skills="$skills_dir/secguardian-xuanwu"
        mkdir -p "$ext_skills"
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$ext_skills/$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
        # Knowledge: merge across all extensions
        for cat in languages detectors protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
            fi
        done
    done
    log_done "$cmd_n commands (.md), $skill_n skills"

    # Copy project-level knowledge (v2.0)
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$knowledge_dir/"
    [ -f "$PROJECT_ROOT/knowledge/report-template.md" ] && cp "$PROJECT_ROOT/knowledge/report-template.md" "$knowledge_dir/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$knowledge_dir/standards/" 2>/dev/null || true

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
             "$knowledge_dir/languages" "$knowledge_dir/detectors" \
             "$knowledge_dir/protocols" "$knowledge_dir/standards"

    local skill_n=0
    local ext_skills="$skills_dir/secguardian-xuanwu"
    mkdir -p "$ext_skills"
    for d in "$DIST"/*/; do
        # Skills: deploy under secguardian-xuanwu extension namespace
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$ext_skills/$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
        # Knowledge: merge across all extensions at top level
        for cat in languages detectors protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
            fi
        done
    done

    # Copy project-level knowledge (v2.0)
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$knowledge_dir/"
    [ -f "$PROJECT_ROOT/knowledge/report-template.md" ] && cp "$PROJECT_ROOT/knowledge/report-template.md" "$knowledge_dir/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$knowledge_dir/standards/" 2>/dev/null || true

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
echo -e "${BOLD}║${NC}  SecGuardian — ${DEPLOY_MODE} ${PLATFORM}                             ${BOLD}║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

if $DO_UNINSTALL; then
    do_uninstall "$PLATFORM"
    echo ""
    echo -e "${GREEN}卸载完成。${NC}"
    exit 0
fi

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
if $DO_ZIP; then
    echo ""
    do_zip
fi

echo ""
echo -e "${GREEN}部署完成。${NC}"
