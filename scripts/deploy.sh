#!/bin/bash
# SecGuardian — 统一部署脚本
# 用法: bash scripts/deploy.sh <platform> [--project] [--zip] [--verify]
#       bash scripts/deploy.sh all
#       bash scripts/deploy.sh cc|nga|cac
#
# 默认行为: 自动先构建（package.sh）再部署
# 会先自动检查 dist/ 是否就绪，否则先执行 package.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$PROJECT_ROOT/dist"
DEPLOY_USER=true      # 默认用户级，--project 切换为项目级
DO_UNINSTALL=false
DO_ZIP=false
DO_BUILD=false
DO_VERIFY=false

# ── Help ──────────────────────────────────────
show_help() {
    cat << 'EOF'
SecGuardian — 部署脚本

将构建好的 dist/ 部署到 AI CLI 平台。

用法:
  bash scripts/deploy.sh <platform> [--project] [--zip]
  bash scripts/deploy.sh <platform> --uninstall

平台:
  all      三平台全部 (默认)
  cc       Claude Code    → .claude/plugins/secguardian/
  nga      OpenCode       → ~/.config/opencode/plugins/ + extensions/ (user, 默认) / .opencode/plugins/ + extensions/ (project)
  cac      Gemini CLI     → ~/.gemini/extensions/secguardian/ (user, 默认) / .gemini/extensions/secguardian/ (project)

选项:
  --project    部署到项目级目录（.opencode/ 等）
  --uninstall  卸载已安装的 secguardian 文件
  --zip        部署后生成发布压缩包 → dist/archives/
  --verify     部署后运行 dev-verify.sh 验证健康

示例:
  bash scripts/deploy.sh all --project       # 项目级部署
  bash scripts/deploy.sh all --uninstall     # 卸载全部
  bash scripts/deploy.sh all --project --uninstall
  bash scripts/deploy.sh all                     # 构建 + 部署到用户级（3 平台）
  bash scripts/deploy.sh all --verify             # 构建 + 部署到用户级 + 验证
  bash scripts/deploy.sh cc                 # 项目级部署 Claude Code
EOF
    exit 0
}

# ── 解析参数 ──────────────────────────────────
# 第一个参数可以是平台名(all/cc/nga/cac)或选项(--project等)
case "${1:-}" in
    all|cc|nga|cac) PLATFORM="$1"; shift 2>/dev/null || true ;;
    -h|--help|help) show_help ;;
    --*)            PLATFORM="all" ;;   # 选项当第一个参数 → 默认全平台
    "")             PLATFORM="all" ;;
    *) echo "未知参数: $1"; exit 1 ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) DEPLOY_USER=false; shift ;;
        --uninstall) DO_UNINSTALL=true; shift ;;
        --zip) DO_ZIP=true; shift ;;
        --verify) DO_VERIFY=true; shift ;;
        -h|--help|help) show_help ;;
        *) shift ;;
    esac
done

# ── 前置构建（默认执行，--uninstall 时跳过）───
if ! $DO_UNINSTALL; then
    echo "  → 正在构建 dist/..."
    bash "$PROJECT_ROOT/scripts/package.sh"
    echo "  ✓ 构建完成"
    echo ""
fi

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

# ── Indexer binary deployment (canonical naming) ──
# Copies the current platform's binary as 'secguardian-index' (no suffix)
# so users always see the same binary name regardless of platform.
deploy_indexer_binary() {
    local target_bin_dir="$1"
    mkdir -p "$target_bin_dir"
    local target="$target_bin_dir/secguardian-index"

    # Detect current platform
    local os_name arch_name
    case "$(uname -s)" in
        Darwin) os_name="darwin" ;;
        Linux)  os_name="linux" ;;
        *)      os_name="unknown" ;;
    esac
    case "$(uname -m)" in
        x86_64|amd64)  arch_name="amd64" ;;
        arm64|aarch64) arch_name="arm64" ;;
        *)             arch_name="unknown" ;;
    esac

    local bin_src="$PROJECT_ROOT/scripts/bin"
    local src="$bin_src/secguardian-index-${os_name}-${arch_name}"

    # If exact platform binary doesn't exist, try any available
    if [ ! -f "$src" ]; then
        src=$(ls "$bin_src"/secguardian-index-* 2>/dev/null | head -1)
    fi
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        log_info "no indexer binary found for ${os_name}-${arch_name} — skipping binary deployment"
        return 0
    fi

    # Idempotency: skip if same version already deployed
    if [ -x "$target" ]; then
        local existing_ver=$("$target" --version 2>/dev/null || echo "unknown")
        local new_ver=$("$src" --version 2>/dev/null || echo "unknown")
        if [ "$existing_ver" = "$new_ver" ] && [ -n "$existing_ver" ] && [ "$existing_ver" != "unknown" ]; then
            log_info "indexer binary already up-to-date ($existing_ver)"
            return 0
        fi
    fi

    # Atomic replacement
    cp "$src" "${target}.tmp"
    chmod +x "${target}.tmp"
    if "${target}.tmp" --version >/dev/null 2>&1; then
        mv "${target}.tmp" "$target"
        local ver=$("$target" --version 2>/dev/null || echo "unknown")
        log_info "indexer binary deployed: secguardian-index ($ver, ${os_name}-${arch_name})"
        return 0
    else
        rm -f "${target}.tmp"
        log_info "indexer binary verification failed — keeping existing version"
        return 1
    fi
}

# ── Claude Code (Official Plugin Format) ──────────
# Ref: https://code.claude.com/docs/en/plugins-reference
deploy_claude() {
    local plugin_name="secguardian"
    local plugin_dir="$TARGET_ROOT/.claude/plugins/$plugin_name"

    if $DEPLOY_USER; then
        log_step "Claude Code → ~/.claude/plugins/$plugin_name/ (用户级)"
    else
        log_step "Claude Code → .claude/plugins/$plugin_name/ (项目级)"
    fi

    # Clean old: remove legacy extensions/ format AND old plugin
    rm -rf "$TARGET_ROOT/.claude/extensions/secguard-secguardian" \
           "$TARGET_ROOT/.claude/extensions/secaudit-secguardian" \
           "$TARGET_ROOT/.claude/extensions/secreview-secguardian" \
           "$plugin_dir"

    mkdir -p "$plugin_dir/.claude-plugin" "$plugin_dir/commands" "$plugin_dir/skills" \
             "$plugin_dir/knowledge/protocols" "$plugin_dir/knowledge/standards" \
             "$plugin_dir/scripts/bin"

    # Write official plugin.json
    # 版本号从 manifest.json 读取，单一来源
    cat > "$plugin_dir/.claude-plugin/plugin.json" << JSON
{
  "name": "secguardian",
  "version": "$(jq -r '.version' "$PROJECT_ROOT/manifest.json")",
  "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案。60 检测器、17 审计技能、5 语言安全检视。",
  "author": { "name": "SecGuardian", "url": "https://github.com/DannyAn/SecGuardian" },
  "homepage": "https://github.com/DannyAn/SecGuardian",
  "keywords": ["security", "sast", "audit", "code-review", "vulnerability"]
}
JSON

    local total_skills=0 total_cmds=0
    for d in "$DIST"/*/; do
        # Commands — Claude Code platform
        if [ -d "$d/commands/claude" ]; then
            for f in "$d/commands/claude"/*.md; do
                [ -f "$f" ] && cp "$f" "$plugin_dir/commands/" && total_cmds=$((total_cmds + 1))
            done
        fi
        # Skills
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$plugin_dir/skills/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && total_skills=$((total_skills + 1))
            done
        fi
        # Knowledge: merge across all extensions
        for cat in languages protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$plugin_dir/knowledge/$cat/" \;
            fi
        done
    done
    log_done "$total_cmds commands, $total_skills skills"

    # ── Namespace commands: prevent collision with other plugins ──
    # Creates commands/secguardian/ subdirectory so commands are also
    # available as /secguardian:secguard etc. — safe even if another
    # plugin also registers /secguard /secaudit /secreview.
    mkdir -p "$plugin_dir/commands/secguardian"
    for f in "$plugin_dir/commands"/*.md; do
        [ -f "$f" ] && cp "$f" "$plugin_dir/commands/secguardian/$(basename "$f")"
    done
    log_done "namespace commands: /secguardian:secguard, /secguardian:secaudit, /secguardian:secreview"

    # Copy project-level knowledge (v2.0)
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$plugin_dir/knowledge/"
    [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$plugin_dir/knowledge/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$plugin_dir/knowledge/standards/" 2>/dev/null || true

    # Copy wrapper scripts, renderer, and binaries into plugin
    for wrapper in init-scan.sh secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$plugin_dir/scripts/$wrapper"
            chmod +x "$plugin_dir/scripts/$wrapper" 2>/dev/null || true
        fi
    done
    deploy_indexer_binary "$plugin_dir/scripts/bin"

    # ── Create skills/*/scripts/ symlinks ──────
    for sd in "$plugin_dir/skills"/*/; do
        [ -d "$sd" ] && ln -sfn ../../scripts "$sd/scripts"
    done
    log_info "skill scripts symlinks: ${total_skills} created"

    # ── Write .secguardian-env ──────────────────
    echo 'export SECGUARDIAN_HOME=$HOME/.claude/plugins/secguardian' > "$plugin_dir/.secguardian-env"

    # ── Register plugin with Claude Code ──────────────
    # Claude Code v2.1.x requires plugins to be installed via marketplace.
    # We set up a local marketplace that points to the plugin directory,
    # then register it so the plugin auto-discovers on next session.
    register_claude_plugin "$plugin_dir"

    echo ""
    log_info "Claude Code 命令（重启后生效）:"
    echo "    /secguard <path> [mode] [filters]"
    echo "    /secaudit <skill-name>"
    echo "    /secreview <path> [language]"
}

# ── Register plugin in Claude Code's plugin registry ─
# Sets up a local marketplace and installs the plugin via CLI,
# with JSON fallback if the CLI is unavailable.
register_claude_plugin() {
    local plugin_dir="$1"
    local plugin_version
    plugin_version=$(grep -m1 '"version"' "$plugin_dir/.claude-plugin/plugin.json" | sed 's/.*: *"\([^"]*\)".*/\1/')
    local marketplace_name="secguardian-local"
    local marketplace_dir="$HOME/.claude/plugins/marketplaces/$marketplace_name"
    local settings_file="$HOME/.claude/settings.json"
    local installed_file="$HOME/.claude/plugins/installed_plugins.json"
    local known_marketplaces_file="$HOME/.claude/plugins/known_marketplaces.json"

    # Create marketplace structure
    mkdir -p "$marketplace_dir/.claude-plugin" "$marketplace_dir/plugins"

    # Remove old flat marketplace.json (legacy)
    rm -f "$marketplace_dir/marketplace.json"

    # Symlink plugin into marketplace
    ln -sfn "$plugin_dir" "$marketplace_dir/plugins/secguardian"

    # Write marketplace manifest
    cat > "$marketplace_dir/.claude-plugin/marketplace.json" << JSON
{
  "name": "$marketplace_name",
  "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案。60 检测器、17 审计技能、5 语言安全检视。",
  "owner": { "name": "SecGuardian" },
  "plugins": [
    {
      "name": "secguardian",
      "description": "Security scan/audit/review commands — /secguard, /secaudit, /secreview",
      "version": "$plugin_version",
      "source": "./plugins/secguardian",
      "category": "security",
      "homepage": "https://github.com/DannyAn/SecGuardian",
      "author": { "name": "SecGuardian" },
      "keywords": ["security", "sast", "audit", "code-review", "vulnerability"]
    }
  ]
}
JSON

    # Try CLI-based install first
    if command -v claude &>/dev/null; then
        # Register marketplace
        claude plugin marketplace add "$marketplace_dir" 2>/dev/null || true
        # Force refresh: delete stale cache so CLI re-reads current files.
        # claude plugin install returns "already installed" without updating the
        # cache when the version string hasn't changed.
        rm -rf "$HOME/.claude/plugins/cache/$marketplace_name/secguardian/"
        claude plugin install "secguardian@$marketplace_name" 2>/dev/null && {
            log_done "plugin registered via claude CLI"
            return 0
        }
    fi

    # Fallback: manual JSON manipulation
    log_info "claude CLI unavailable — registering via JSON"

    # Register marketplace in known_marketplaces.json
    if [ -f "$known_marketplaces_file" ]; then
        python3 -c "
import json, sys
with open('$known_marketplaces_file') as f:
    data = json.load(f)
data['$marketplace_name'] = {
    'source': {'source': 'directory', 'path': '$marketplace_dir'},
    'installLocation': '$marketplace_dir',
    'lastUpdated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
with open('$known_marketplaces_file', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
    fi

    # Register in installed_plugins.json
    if [ -f "$installed_file" ]; then
        python3 -c "
import json
with open('$installed_file') as f:
    data = json.load(f)
key = 'secguardian@$marketplace_name'
entry = {
    'scope': 'user',
    'installPath': '$HOME/.claude/plugins/cache/$marketplace_name/secguardian/$plugin_version',
    'version': '$plugin_version',
    'installedAt': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'lastUpdated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
data['plugins'][key] = [entry]
with open('$installed_file', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
    fi

    # Enable in settings.json
    if [ -f "$settings_file" ]; then
        python3 -c "
import json
with open('$settings_file') as f:
    data = json.load(f)
if 'enabledPlugins' not in data:
    data['enabledPlugins'] = {}
data['enabledPlugins']['secguardian@$marketplace_name'] = True
with open('$settings_file', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
    fi

    # Cache the plugin files for the CLI-install path (mirrors what claude plugin install does)
    local cache_dir="$HOME/.claude/plugins/cache/$marketplace_name/secguardian/$plugin_version"
    if [ ! -d "$cache_dir" ]; then
        mkdir -p "$(dirname "$cache_dir")"
        cp -r "$plugin_dir" "$cache_dir"
    fi

    log_done "plugin registered via JSON fallback"
}

# ── 卸载 ──────────────────────────────────────
uninstall_claude() {
    local plugin_dir="$TARGET_ROOT/.claude/plugins/secguardian"
    local marketplace_name="secguardian-local"
    local marketplace_dir="$HOME/.claude/plugins/marketplaces/$marketplace_name"
    local cache_dir="$HOME/.claude/plugins/cache/$marketplace_name"
    local legacy_ext="$TARGET_ROOT/.claude/extensions"

    # Try CLI uninstall first
    if command -v claude &>/dev/null; then
        claude plugin uninstall "secguardian@$marketplace_name" 2>/dev/null || true
        claude plugin marketplace remove "$marketplace_name" 2>/dev/null || true
    fi

    # Clean marketplace structure
    [ -d "$marketplace_dir" ] && rm -rf "$marketplace_dir"
    [ -d "$cache_dir" ] && rm -rf "$cache_dir"

    # Clean plugin directory
    if [ -d "$plugin_dir" ]; then
        rm -rf "$plugin_dir"
        log_done "已移除: $plugin_dir"
    fi

    # Clean legacy extension-format plugins
    for name in secguard-secguardian secaudit-secguardian secreview-secguardian; do
        [ -d "$legacy_ext/$name" ] && rm -rf "$legacy_ext/$name"
    done

    # Clean JSON registrations (manual cleanup in case CLI missed them)
    local settings_file="$HOME/.claude/settings.json"
    local installed_file="$HOME/.claude/plugins/installed_plugins.json"
    local known_file="$HOME/.claude/plugins/known_marketplaces.json"

    for f in "$settings_file" "$installed_file" "$known_file"; do
        [ -f "$f" ] && python3 -c "
import json, sys
with open('$f') as fh:
    data = json.load(fh)
# Remove secguardian entries
if 'enabledPlugins' in data:
    data['enabledPlugins'].pop('secguardian@$marketplace_name', None)
    data['enabledPlugins'].pop('secguardian', None)
if 'extraKnownMarketplaces' in data:
    data['extraKnownMarketplaces'].pop('$marketplace_name', None)
if 'plugins' in data:
    data['plugins'].pop('secguardian@$marketplace_name', None)
    data['plugins'].pop('secguardian', None)
data.pop('$marketplace_name', None)
with open('$f', 'w') as fh:
    json.dump(data, fh, indent=2)
" 2>/dev/null || true
    done

    # NOTE: Do NOT delete scripts/secguardian-index — it is a source file, not a deployment artifact.
}

uninstall_opencode() {
    local brand="secguardian"
    local oc_dir="$TARGET_ROOT/.opencode"
    local oc_user_dir="$HOME/.config/opencode"
    for base in "$oc_dir" "$oc_user_dir"; do
        # Remove extension dir
        local ext_dir="$base/extensions/$brand"
        if [ -d "$ext_dir" ]; then
            rm -rf "$ext_dir"
            log_done "已移除: $ext_dir"
        fi
        # Remove plugin
        if [ -f "$base/plugins/secguardian.js" ]; then
            rm -f "$base/plugins/secguardian.js"
            log_done "已移除插件: $base/plugins/secguardian.js"
        fi
        # Clean legacy flat deployment if present
        for sub in commands skills knowledge scripts; do
            if [ -d "$base/$sub" ]; then
                if [ -f "$base/$sub/secaudit.md" ] || \
                   [ -f "$base/$sub/secguard.md" ] || \
                   [ -d "$base/$sub/secaudit-attack-surface-analysis" ] || [ -d "$base/$sub/secguard-attack-surface-analysis" ]; then
                    rm -rf "$base/$sub"
                    log_done "已移除 (legacy): $base/$sub"
                fi
            fi
        done
    done
}

uninstall_gemini() {
    local brand="secguardian"
    # Check both user-level and project-level paths
    for base in "$HOME/.gemini" "$PROJECT_ROOT/.gemini"; do
        local ext_dir="$base/extensions/$brand"
        if [ -d "$ext_dir" ]; then
            rm -rf "$ext_dir"
            log_done "已移除: $ext_dir"
        fi
        # Clean legacy flat deployment
        for sub in commands skills knowledge scripts GEMINI.md; do
            if [ -e "$base/$sub" ]; then
                # Only remove if it was our deployment
                if [ -f "$base/$sub/secaudit.toml" ] || \
                   [ -f "$base/$sub/secguard.toml" ] || \
                   [ -d "$base/$sub/secaudit-attack-surface-analysis" ] || [ -d "$base/$sub/secguard-attack-surface-analysis" ]; then
                    rm -rf "$base/$sub"
                    log_done "已移除 (legacy): $base/$sub"
                fi
            fi
        done
    done
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

# ── OpenCode (Plugin + Extension) ──────────────
# Ref: https://opencode.ai/docs/plugins
# OpenCode discovers plugins from ~/.config/opencode/plugins/ (user) or .opencode/plugins/ (project)
# The plugin registers secguard/secaudit/secreview commands + skills.paths at startup
# Extension assets live under extensions/secguardian/, discovered by plugin via relative path
deploy_opencode() {
    local brand="secguardian"
    if $DEPLOY_USER; then
        local opencode_dir="$HOME/.config/opencode"
        log_step "OpenCode → plugins/secguardian.js + extensions/$brand/ (用户级)"
    else
        local opencode_dir="$TARGET_ROOT/.opencode"
        log_step "OpenCode → plugins/secguardian.js + extensions/$brand/ (项目级)"
    fi
    local ext_dir="$opencode_dir/extensions/$brand"
    local skills_dir="$ext_dir/skills"
    local knowledge_dir="$ext_dir/knowledge"
    local scripts_dir="$ext_dir/scripts"

    # Clean old: remove stale extension dir, stale plugin, legacy flat deployment
    rm -rf "$ext_dir"
    rm -f "$opencode_dir/plugins/secguardian.js"
    for legacy_sub in skills knowledge scripts; do
        if [ -d "$opencode_dir/$legacy_sub" ]; then
            if [ -f "$opencode_dir/$legacy_sub/secaudit.md" ] || \
               [ -f "$opencode_dir/$legacy_sub/secguard.md" ] || \
               [ -d "$opencode_dir/$legacy_sub/secaudit-attack-surface-analysis" ] || \
               [ -d "$opencode_dir/$legacy_sub/threat-catalog.md" ] || \
               [ -f "$opencode_dir/$legacy_sub/secguardian-index" ]; then
                rm -rf "$opencode_dir/$legacy_sub"
                log_info "removed legacy flat deployment: $legacy_sub/"
            fi
        fi
    done

    mkdir -p "$ext_dir/commands" "$skills_dir" "$scripts_dir/bin" \
             "$knowledge_dir/languages" \
             "$knowledge_dir/protocols" "$knowledge_dir/standards" \
             "$opencode_dir/plugins" "$opencode_dir/commands"

    # Write codeagent-extension.json (informational manifest)
    cat > "$ext_dir/codeagent-extension.json" << JSON
{
  "name": "$brand",
  "version": "$(jq -r '.version' "$PROJECT_ROOT/manifest.json")",
  "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案"
}
JSON

    # ── Deploy plugin ────────────────────────────
    if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
        cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$opencode_dir/plugins/secguardian.js"
        log_done "opencode plugin: plugins/secguardian.js"
    fi

    # ── Deploy command templates — OpenCode platform ────
    local cmd_n=0 skill_n=0
    for d in "$DIST"/*/; do
        if [ -d "$d/commands/opencode" ]; then
            for f in "$d/commands/opencode"/*.md; do
                [ -f "$f" ] && cp "$f" "$ext_dir/commands/" && \
                cp "$f" "$opencode_dir/commands/" && cmd_n=$((cmd_n + 1))
            done
        fi
    done

    # ── Deploy skills ────────────────────────────
    for d in "$DIST"/*/; do
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$skills_dir/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
    done

    # ── Deploy knowledge ─────────────────────────
    for cat in languages protocols; do
        for d in "$DIST"/*/; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$knowledge_dir/$cat/" \;
            fi
        done
    done
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$knowledge_dir/"
    [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$knowledge_dir/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$knowledge_dir/standards/" 2>/dev/null || true

    log_done "$cmd_n commands, $skill_n skills, knowledge/ + scripts/"

    # ── Deploy scripts + indexer ─────────────────
    for wrapper in init-scan.sh secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
        if [ -f "$PROJECT_ROOT/scripts/$wrapper" ]; then
            cp "$PROJECT_ROOT/scripts/$wrapper" "$scripts_dir/$wrapper"
            chmod +x "$scripts_dir/$wrapper" 2>/dev/null || true
        fi
    done
    deploy_indexer_binary "$scripts_dir/bin"

    # ── Create skills/*/scripts/ symlinks ──────
    # Each skill gets scripts/ → ../../scripts, so path references stay skill-relative.
    for sd in "$skills_dir"/*/; do
        [ -d "$sd" ] && ln -sfn ../../scripts "$sd/scripts"
    done
    log_info "skill scripts symlinks: ${skill_n} created"

    # ── Write .secguardian-env ──────────────────
    echo 'export SECGUARDIAN_HOME=$HOME/.config/opencode/extensions/secguardian' > "$ext_dir/.secguardian-env"

    echo ""
    log_info "OpenCode 使用方式（重启后生效）:"
    echo "    /secguard <path> [filters]"
    echo "    /secaudit <skill-name> [path]"
    echo "    /secreview <path> [language]"
}

# ── Gemini CLI (Official Extension Format) ──────
# Ref: https://geminicli.com/docs/extensions/reference/
deploy_gemini() {
    local ext_name="secguardian"
    local ext_dir="$TARGET_ROOT/.gemini/extensions/$ext_name"

    if $DEPLOY_USER; then
        log_step "Gemini CLI → ~/.gemini/extensions/$ext_name/ (用户级)"
    else
        log_step "Gemini CLI → .gemini/extensions/$ext_name/ (项目级)"
    fi

    # Clean: remove old flat format AND old extension dir
    rm -rf "$TARGET_ROOT/.gemini/commands" "$TARGET_ROOT/.gemini/skills" \
           "$TARGET_ROOT/.gemini/knowledge" "$TARGET_ROOT/.gemini/scripts" \
           "$TARGET_ROOT/.gemini/GEMINI.md" \
           "$ext_dir"

    mkdir -p "$ext_dir/commands" "$ext_dir/skills" \
             "$ext_dir/knowledge/protocols" "$ext_dir/knowledge/standards" \
             "$ext_dir/scripts/bin"

    # Write official gemini-extension.json
    # 版本号从 manifest.json 读取，单一来源
    cat > "$ext_dir/gemini-extension.json" << JSON
{
  "name": "secguardian",
  "version": "$(jq -r '.version' "$PROJECT_ROOT/manifest.json")",
  "description": "SecGuardian XuanWu — 企业级白盒安全 AI Agent 辅助解决方案",
  "author": "SecGuardian",
  "homepage": "https://github.com/DannyAn/SecGuardian",
  "commands": ["commands/secaudit.toml", "commands/secguard.toml", "commands/secreview.toml"]
}
JSON

    local skill_n=0
    for d in "$DIST"/*/; do
        if [ -d "$d/skills" ]; then
            for sd in "$d/skills"/*/; do
                [ -d "$sd" ] && cp -r "$sd" "$ext_dir/skills/$(basename "$d" | sed 's/-secguardian//')-$(basename "$sd")" && skill_n=$((skill_n + 1))
            done
        fi
        for cat in languages protocols; do
            if [ -d "$d/knowledge/$cat" ]; then
                find "$d/knowledge/$cat" -name '*.md' -exec cp {} "$ext_dir/knowledge/$cat/" \;
            fi
        done
    done

    # Project-level knowledge (v2.0)
    [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ] && cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$ext_dir/knowledge/"
    [ -f "$PROJECT_ROOT/SECURITY.md" ] && cp "$PROJECT_ROOT/SECURITY.md" "$ext_dir/knowledge/"
    [ -d "$PROJECT_ROOT/knowledge/standards" ] && cp -r "$PROJECT_ROOT/knowledge/standards/"* "$ext_dir/knowledge/standards/" 2>/dev/null || true

    # Generate TOML commands
    log_info "生成 Gemini TOML 命令..."
    bash "$PROJECT_ROOT/scripts/gen-toml.sh" > /dev/null

    local toml_src="$PROJECT_ROOT/commands/gemini"
    local cmd_n=0
    if [ -d "$toml_src" ]; then
        for f in "$toml_src"/*.toml; do
            cp "$f" "$ext_dir/commands/"; cmd_n=$((cmd_n + 1))
        done
    fi

    # Wrapper scripts and binaries
    for wrapper in init-scan.sh secguardian-index secguardian-index.ps1 render-report.py validate-index.py validate-findings.py record-finding.py; do
        [ -f "$PROJECT_ROOT/scripts/$wrapper" ] && cp "$PROJECT_ROOT/scripts/$wrapper" "$ext_dir/scripts/"
    done
    chmod +x "$ext_dir/scripts/"* 2>/dev/null || true
    deploy_indexer_binary "$ext_dir/scripts/bin"

    # ── Create skills/*/scripts/ symlinks ──────
    for sd in "$ext_dir/skills"/*/; do
        [ -d "$sd" ] && ln -sfn ../../scripts "$sd/scripts"
    done
    log_info "skill scripts symlinks: ${skill_n} created"

    # ── Write .secguardian-env ──────────────────
    echo 'export SECGUARDIAN_HOME=$HOME/.gemini/extensions/secguardian' > "$ext_dir/.secguardian-env"
    chmod +x "$ext_dir/scripts/bin/"* 2>/dev/null || true

    # 生成 Gemini 上下文文件
    cat > "$ext_dir/GEMINI.md" << 'MD'
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
    echo "    /secaudit ./src python"
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

    # OpenCode: 官方插件结构 (plugins/secguardian.js + extensions/secguardian/)
    local opencode_root
    if [ -d "$HOME/.config/opencode/plugins" ]; then
        opencode_root="$HOME/.config/opencode"
    elif [ -d "$PROJECT_ROOT/.opencode/plugins" ]; then
        opencode_root="$PROJECT_ROOT/.opencode"
    fi
    if [ -n "${opencode_root:-}" ]; then
        local ver="$(jq -r '.version' "$PROJECT_ROOT/manifest.json")"
        local nga_zip="$archive_dir/secguardian-nga-v${ver}.zip"
        (cd "$opencode_root" && zip -rq "$nga_zip" plugins/secguardian.js extensions/secguardian/)
        log_done "$(basename "$nga_zip")"
    fi

    # Gemini CLI: extension format (under extensions/secguardian/)
    if [ -d "$TARGET_ROOT/.gemini/extensions/secguardian/skills" ]; then
        local cac_zip="$archive_dir/cac-secguardian.zip"
        (cd "$TARGET_ROOT/.gemini/extensions/secguardian/" && zip -rq "$cac_zip" .)
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
