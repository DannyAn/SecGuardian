#!/bin/bash
# SecGuardian — Extension 打包脚本
#
# 读取 extensions/<name>/extension.json，生成独立扩展包。
#
# 用法:
#   bash scripts/package.sh       # 构建全部 extension
#   bash scripts/package.sh -h    # 显示帮助
#
# 输出: dist/<extension-name>/
#   ├── extension.json
#   ├── commands/claude/<cmd>.md
#   ├── commands/opencode/<cmd>.md
#   ├── skills/<skill-name>/rules.md
#   ├── knowledge/protocols/
#   ├── knowledge/standards/
#   └── scripts/
#       ├── secguardian-index      (shell wrapper)
#       ├── secguardian-index.ps1  (powershell wrapper)
#       └── bin/
#           ├── secguardian-index-darwin-arm64
#           ├── secguardian-index-darwin-amd64
#           ├── secguardian-index-linux-amd64
#           └── secguardian-index-windows-amd64.exe

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo ">>> Generating Gemini .toml files from commands/claude/..."
bash "$PROJECT_ROOT/scripts/gen-toml.sh"

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — Extension 打包脚本

读取 extensions/<name>/extension.json，组装完整的扩展包。

用法:
  bash scripts/package.sh           # 构建全部 extension（生成到 dist/）
  bash scripts/package.sh -h        # 显示此帮助

构建流程:
  1. 读取 extension.json 中的 skills/languages/detectors/protocols/standards 清单
  2. 从 skills/ 目录复制 rules.md + references/
  3. 从 knowledge/ 目录复制对应的安全知识文件
  4. 从 commands/ 目录复制 slash command 定义
  5. 跨平台编译 secguardian-index 二进制，放入 scripts/bin/
  6. 复制跨平台 wrapper 脚本 scripts/secguardian-index*
  7. 输出到 dist/<extension-name>/

示例:
  bash scripts/package.sh           # 构建
  bash scripts/package.sh && bash scripts/deploy.sh all  # 构建 + 部署
EOF
    exit 0
fi

EXTENSIONS_DIR="$PROJECT_ROOT/extensions"
DIST="$PROJECT_ROOT/dist"

echo "==> Packaging SecGuardian extensions..."

# ── Pre-build: Compile Go indexer binary ──────────
BUILD_BIN_DIR="$PROJECT_ROOT/scripts/bin"
mkdir -p "$BUILD_BIN_DIR"

# Clean up stale binaries without platform suffix (legacy build artifact)
find "$BUILD_BIN_DIR" -name 'secguardian-index' ! -name 'secguardian-index-*' -type f -delete 2>/dev/null || true

# Build matrix: (target, os, arch, cgo_flag)
BUILD_TARGETS=(
    "darwin-arm64:darwin:arm64:CGO_ENABLED=1"
    "darwin-amd64:darwin:amd64:CGO_ENABLED=1"
    "linux-amd64:linux:amd64:CGO_ENABLED=0"
    "linux-arm64:linux:arm64:CGO_ENABLED=0"
    "windows-amd64.exe:windows:amd64:CGO_ENABLED=0"
)

if [ "${SKIP_GO_BUILD:-}" = "1" ]; then
    echo "  → [SKIP] SKIP_GO_BUILD=1 — using pre-built binaries in $BUILD_BIN_DIR/"
    ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " ($5 ")"}' || true
elif [ -f "$PROJECT_ROOT/internal/go.mod" ] && command -v go &>/dev/null; then
    # Clean stale binaries — prevents silent use of old versions when build fails
    rm -f "$BUILD_BIN_DIR"/secguardian-index-*
    echo "  → Compiling secguardian-index binaries (dual-mode: CGO=tree-sitter, !CGO=regex)..."
    BUILD_FAILED=0; BUILD_OK=0
    BUILD_TMP=$(mktemp -d)/secguardian-build
    mkdir -p "$BUILD_TMP"
    for entry in "${BUILD_TARGETS[@]}"; do
        IFS=: read -r target_suffix os arch cgo_flag <<< "$entry"
        desc="${target_suffix%.exe}"
        tag="${cgo_flag#*=}"
        mode="$([ "$tag" = "1" ] && echo "tree-sitter" || echo "regex")"
        tags=""
        if [ "$tag" = "1" ]; then tags="-tags cgo"; fi
        (cd "$PROJECT_ROOT/internal" && \
            env ${cgo_flag} GOOS=$os GOARCH=$arch go build $tags -o "$BUILD_TMP/secguardian-index-${target_suffix}" . && \
            echo "    [OK] ${desc} (${mode})" || \
            { rc=$?; echo "    [FAIL] ${desc} (${mode}) — see errors above"; exit $rc; }) &
    done
    # Wait for all parallel builds, track individual exit codes
    for job in $(jobs -p); do
        if wait "$job" 2>/dev/null; then
            BUILD_OK=$((BUILD_OK + 1))
        else
            BUILD_FAILED=$((BUILD_FAILED + 1))
        fi
    done
    # Atomic publish: delete old binaries first, then move new ones in
    rm -f "$BUILD_BIN_DIR"/secguardian-index-*
    for entry in "${BUILD_TARGETS[@]}"; do
        target_suffix="${entry%%:*}"
        src="$BUILD_TMP/secguardian-index-${target_suffix}"
        [ -f "$src" ] && mv "$src" "$BUILD_BIN_DIR/secguardian-index-${target_suffix}"
    done
    rm -rf "$(dirname "$BUILD_TMP")"
    if [ "$BUILD_FAILED" -gt 0 ]; then
        echo "    [FAIL] ${BUILD_FAILED}/${#BUILD_TARGETS[@]} platform(s) failed — see errors above"
        exit 1
    fi
    echo "  → All ${BUILD_OK} platforms compiled. Binaries in: $BUILD_BIN_DIR/"
    ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " (" $5 ")"}' || true
    echo "  → Note: tree-sitter (CGO) on macOS (native), pure-Go regex fallback on cross-compiled (linux/windows)."
else
    echo "    [SKIP] Go not available — indexer binaries not built"
fi

# Note: No standalone "secguardian" binary in V1.
# The indexer (secguardian-index) is the only binary needed.
# A future standalone CLI with integrated LLM calls will use the "secguardian" name.

for ext_dir in "$EXTENSIONS_DIR"/*/; do
    ext=$(basename "$ext_dir")
    ext_json="$ext_dir/extension.json"

    if [ ! -f "$ext_json" ]; then
        echo "  [SKIP] $ext — no extension.json"
        continue
    fi

    echo "  -> $ext"
    dist_dir="$DIST/$ext"
    rm -rf "$dist_dir"
    mkdir -p "$dist_dir/commands" "$dist_dir/skills" \
             "$dist_dir/knowledge/protocols" \
             "$dist_dir/knowledge/standards" \
             "$dist_dir/scripts/bin"

    # Copy extension manifest
    cp "$ext_json" "$dist_dir/extension.json"

    # Generate .claude-plugin/plugin.json for Claude Code compatibility
    mkdir -p "$dist_dir/.claude-plugin"
    jq -n \
        --arg name "$ext" \
        --arg version "$(jq -r '.version' "$ext_json")" \
        --arg desc "$(jq -r '.description' "$ext_json")" \
        '{name: $name, version: $version, description: $desc, author: {name: "SecGuardian"}}' \
        > "$dist_dir/.claude-plugin/plugin.json"
    echo "    plugin: $ext"

    # Determine command name(s) — supports both "command" (string) and "commands" (array)
    cmds=$(jq -r 'if .commands then .commands[] else .command end' "$ext_json")
    cmd_count=0
    # Create platform subdirectories for commands
    for plat_dir in claude opencode; do
        mkdir -p "$dist_dir/commands/$plat_dir"
    done
    for cmd in $cmds; do
        cmd_found=0
        for plat_dir in claude opencode; do
            plat_src="$PROJECT_ROOT/commands/${plat_dir}/${cmd}.md"
            if [ -f "$plat_src" ]; then
                cp "$plat_src" "$dist_dir/commands/$plat_dir/"
                cmd_found=$((cmd_found + 1))
            fi
        done
        if [ "$cmd_found" -gt 0 ]; then
            echo "    command: /$cmd (claude + opencode)"
            cmd_count=$((cmd_count + 1))
        else
            echo "    [WARN] command file not found: ${cmd}.md (checked claude/ and opencode/)"
        fi
    done
    # Use first command as primary key for skill/knowledge resolution
    cmd=$(echo "$cmds" | head -1)

    # Copy skill directories (each contains rules.md + references/)
    skill_count=0
    for skill_name in $(jq -r '.skills // [] | .[]' "$ext_json"); do
        skill_dir="$PROJECT_ROOT/skills/${cmd}/${skill_name}"
        flat_skill="$PROJECT_ROOT/skills/${cmd}/SKILL.md"
        if [ -d "$skill_dir" ]; then
            cp -r "$skill_dir" "$dist_dir/skills/"
            skill_count=$((skill_count + 1))
        elif [ -f "$flat_skill" ]; then
           mkdir -p "$dist_dir/skills/${skill_name}"
           cp "$flat_skill" "$dist_dir/skills/${skill_name}/"
            # 复制全部子目录（references/、rules/ 等）
            for _sdir in "$PROJECT_ROOT/skills/${cmd}"/*/; do
                [ -d "$_sdir" ] && cp -r "$_sdir" "$dist_dir/skills/${skill_name}/"
            done
            echo "    [FLAT] ${cmd}/${skill_name}/SKILL.md (flat → dir)"
            skill_count=$((skill_count + 1))
        else
            echo "    [WARN] skill not found: ${cmd} (checked dir and flat SKILL.md)"
        fi
    done
    echo "    skills: $skill_count"

    # Copy threat-catalog (v2.0: replaces concepts/)
    if [ -f "$PROJECT_ROOT/knowledge/threat-catalog.md" ]; then
        cp "$PROJECT_ROOT/knowledge/threat-catalog.md" "$dist_dir/knowledge/"
    fi
    # Copy SECURITY.md for corporate AV whitelisting
    if [ -f "$PROJECT_ROOT/SECURITY.md" ]; then
        cp "$PROJECT_ROOT/SECURITY.md" "$dist_dir/knowledge/"
    fi
    # Copy standards if declared
    std_count=0
    if jq -e '.knowledge.standards' "$ext_json" > /dev/null 2>&1; then
        for std in $(jq -r '.knowledge.standards[]' "$ext_json"); do
            sf="$PROJECT_ROOT/knowledge/standards/${std}.md"
            if [ -f "$sf" ]; then
                mkdir -p "$dist_dir/knowledge/standards"
                cp "$sf" "$dist_dir/knowledge/standards/"
                std_count=$((std_count + 1))
            fi
        done
    fi
    echo "    standards: $std_count"

    # detectors: retired — all content in rules/*/rule.md
    detector_count=0

# Copy protocols declared in extension.json (optional field)
    protocol_count=0
    if jq -e '.knowledge.protocols' "$ext_json" > /dev/null 2>&1; then
        for protocol in $(jq -r '.knowledge.protocols[]' "$ext_json"); do
            pf="$PROJECT_ROOT/knowledge/protocols/${protocol}.md"
            if [ -f "$pf" ]; then
                cp "$pf" "$dist_dir/knowledge/protocols/"
                protocol_count=$((protocol_count + 1))
            fi
        done
    fi
    echo "    protocols: $protocol_count"

    # Copy cross-platform wrapper scripts into the package
    if [ -f "$PROJECT_ROOT/scripts/secguardian-index" ]; then
        cp "$PROJECT_ROOT/scripts/secguardian-index" "$dist_dir/scripts/secguardian-index"
        chmod +x "$dist_dir/scripts/secguardian-index"
        echo "    wrapper: secguardian-index (shell)"
    else
        echo "    [WARN] scripts/secguardian-index wrapper not found"
    fi
    if [ -f "$PROJECT_ROOT/scripts/secguardian-index.ps1" ]; then
        cp "$PROJECT_ROOT/scripts/secguardian-index.ps1" "$dist_dir/scripts/secguardian-index.ps1"
        echo "    wrapper: secguardian-index.ps1 (powershell)"
    fi

    # Copy shared utility scripts
    cp "$PROJECT_ROOT/scripts/init-scan.sh" "$dist_dir/scripts/init-scan.sh"
    chmod +x "$dist_dir/scripts/init-scan.sh"
    cp "$PROJECT_ROOT/scripts/record-finding.py" "$dist_dir/scripts/record-finding.py"
    cp "$PROJECT_ROOT/scripts/validate-index.py" "$dist_dir/scripts/validate-index.py"
    cp "$PROJECT_ROOT/scripts/render-report.py" "$dist_dir/scripts/render-report.py"
    # strip-answer-cards.py deleted (EPIC-009) — no longer needed

    # Copy cross-platform precompiled binaries
    bin_count=0
    for bin_file in "$BUILD_BIN_DIR"/secguardian-index-*; do
        if [ -f "$bin_file" ]; then
            cp "$bin_file" "$dist_dir/scripts/bin/"
            chmod +x "$dist_dir/scripts/bin/$(basename "$bin_file")" 2>/dev/null || true
    # OpenCode plugin registration script
            bin_count=$((bin_count + 1))
        fi
    done

    # OpenCode plugin registration script
    if [ -f "$PROJECT_ROOT/scripts/opencode-plugin.js" ]; then
        cp "$PROJECT_ROOT/scripts/opencode-plugin.js" "$dist_dir/scripts/"
    fi

    echo "    binaries: $bin_count platform(s) in scripts/bin/"

    echo "    packaged: $dist_dir"
done

# ── Post-build: Cross-platform command verification ──
echo ""
echo "==> Verifying cross-platform command files..."
if [ -f "$PROJECT_ROOT/scripts/verify-commands.sh" ]; then
    bash "$PROJECT_ROOT/scripts/verify-commands.sh"
else
    echo "  [WARN] scripts/verify-commands.sh not found — skipping verification"
fi

echo "==> Done. Output in $DIST/"
