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
#   ├── commands/<cmd>.md
#   ├── skills/<skill-name>/SKILL.md
#   ├── knowledge/languages/
#   ├── knowledge/guard-rules/

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

python3 "$PROJECT_ROOT/scripts/sync-language-index.sh"
echo ">>> Generating Gemini .toml files..."
python3 "$PROJECT_ROOT/scripts/sync-toml.sh"

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
  2. 从 skills/ 目录复制 SKILL.md + references/
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
# Only keep properly suffixed binaries: secguardian-index-{os}-{arch}
find "$BUILD_BIN_DIR" -name 'secguardian-index' ! -name 'secguardian-index-*' -type f -delete 2>/dev/null || true

if [ "${SKIP_GO_BUILD:-}" = "1" ]; then
    echo "  → [SKIP] SKIP_GO_BUILD=1 — using pre-built binaries in $BUILD_BIN_DIR/"
    ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " (" $5 ")"}' || true
elif [ -f "$PROJECT_ROOT/internal/go.mod" ] && command -v go &>/dev/null; then
    echo "  → Compiling secguardian-index binaries (dual-mode: CGO=tree-sitter, !CGO=regex)..."
    # Native build: CGO enabled (tree-sitter)
    (cd "$PROJECT_ROOT/internal" && \
        go build -o "$BUILD_BIN_DIR/secguardian-index-darwin-arm64" . 2>/dev/null && \
        echo "    [OK] darwin-arm64 (tree-sitter)" || echo "    [WARN] darwin-arm64 build failed") &
    # Cross-platform: CGO disabled (pure-Go regex fallback, works everywhere)
    (cd "$PROJECT_ROOT/internal" && \
        CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-darwin-amd64" . 2>/dev/null && \
        echo "    [OK] darwin-amd64 (regex)" || echo "    [WARN] darwin-amd64 build failed") &
    (cd "$PROJECT_ROOT/internal" && \
        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-linux-amd64" . 2>/dev/null && \
        echo "    [OK] linux-amd64 (regex)" || echo "    [WARN] linux-amd64 build failed") &
    (cd "$PROJECT_ROOT/internal" && \
        CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o "$BUILD_BIN_DIR/secguardian-index-linux-arm64" . 2>/dev/null && \
        echo "    [OK] linux-arm64 (regex)" || echo "    [WARN] linux-arm64 build failed") &
    (cd "$PROJECT_ROOT/internal" && \
        CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o "$BUILD_BIN_DIR/secguardian-index-windows-amd64.exe" . 2>/dev/null && \
        echo "    [OK] windows-amd64 (regex)" || echo "    [WARN] windows-amd64 build failed") &
    wait
    echo "  → Compilation done. Binaries in: $BUILD_BIN_DIR/"
    ls -lh "$BUILD_BIN_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "    " $NF " (" $5 ")"}' || true
    echo "  → Note: tree-sitter (CGO) on native platform, pure-Go regex fallback on cross-compiled platforms."
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
             "$dist_dir/knowledge/languages" \
             "$dist_dir/knowledge/guard-rules" \
             "$dist_dir/knowledge/audit-rules" \
             "$dist_dir/knowledge/review-rules" \
             "$dist_dir/knowledge/audit-rules" \
             "$dist_dir/knowledge/review-rules" \
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

    # Determine command name
    cmd=$(jq -r '.command' "$ext_json")
    cmd_src="$PROJECT_ROOT/commands/${cmd}.md"
    if [ -f "$cmd_src" ]; then
        cp "$cmd_src" "$dist_dir/commands/"
        echo "    command: /$cmd"
    else
        echo "    [WARN] command file not found: ${cmd}.md"
    fi

    # Copy skill directories (each contains SKILL.md + optional references/)
    skill_count=0
    for skill_name in $(jq -r '.skills[]' "$ext_json"); do
        skill_dir="$PROJECT_ROOT/skills/${cmd}/${skill_name}"
        if [ -d "$skill_dir" ]; then
            cp -r "$skill_dir" "$dist_dir/skills/"
            skill_count=$((skill_count + 1))
        else
            echo "    [WARN] skill dir not found: ${cmd}-${skill_name}"
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

    lang_count=0
    for lang in $(jq -r '.knowledge.languages[]' "$ext_json"); do
        lf="$PROJECT_ROOT/knowledge/languages/${lang}.md"
        if [ -f "$lf" ]; then
            cp "$lf" "$dist_dir/knowledge/languages/"
            lang_count=$((lang_count + 1))
        fi
    done
    echo "    languages: $lang_count"

    # Copy detectors declared in extension.json (optional field)
    detector_count=0
    if jq -e '.knowledge.detectors' "$ext_json" > /dev/null 2>&1; then
        for detector in $(jq -r '.knowledge.detectors[]' "$ext_json"); do
            df="$PROJECT_ROOT/knowledge/guard-rules/${detector}.md"

            if [ -f "$df" ]; then
                cp "$df" "$dist_dir/knowledge/guard-rules/"

                detector_count=$((detector_count + 1))
            fi
        done
    fi
    echo "    detectors: $detector_count"

    # Copy audit-rules (all files for secaudit-* extensions)
    mkdir -p "$dist_dir/knowledge/audit-rules"
    for ar in "$PROJECT_ROOT/knowledge/audit-rules/"*.md; do
        [ -f "$ar" ] && cp "$ar" "$dist_dir/knowledge/audit-rules/" 2>/dev/null || true
    done

    # Copy review-rules (all files for secreview-* extensions)
    mkdir -p "$dist_dir/knowledge/review-rules"
    for rr in "$PROJECT_ROOT/knowledge/review-rules/"*.md; do
        [ -f "$rr" ] && cp "$rr" "$dist_dir/knowledge/review-rules/" 2>/dev/null || true
    done

    # Copy language-index.md
    if [ -f "$PROJECT_ROOT/knowledge/language-index.md" ]; then
        cp "$PROJECT_ROOT/knowledge/language-index.md" "$dist_dir/knowledge/" 2>/dev/null || true
    fi

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
    cp "$PROJECT_ROOT/scripts/validate-index.py" "$dist_dir/scripts/validate-index.py"
    cp "$PROJECT_ROOT/scripts/validate-findings.py" "$dist_dir/scripts/validate-findings.py"



    # Copy cross-platform precompiled binaries
    bin_count=0
    for bin_file in "$BUILD_BIN_DIR"/secguardian-index-*; do
        if [ -f "$bin_file" ]; then
            cp "$bin_file" "$dist_dir/scripts/bin/"
            chmod +x "$dist_dir/scripts/bin/$(basename "$bin_file")" 2>/dev/null || true
            bin_count=$((bin_count + 1))
        fi
    done
    echo "    binaries: $bin_count platform(s) in scripts/bin/"

    echo "    packaged: $dist_dir"
done

echo "==> Done. Output in $DIST/"
