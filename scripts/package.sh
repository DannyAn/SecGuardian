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
#   ├── knowledge/concepts/
#   ├── knowledge/languages/
#   ├── knowledge/detectors/
#   └── knowledge/protocols/

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — Extension 打包脚本

读取 extensions/<name>/extension.json，组装完整的扩展包。

用法:
  bash scripts/package.sh           # 构建全部 extension（生成到 dist/）
  bash scripts/package.sh -h        # 显示此帮助

构建流程:
  1. 读取 extension.json 中的 skills/concepts/languages/detectors/protocols 清单
  2. 从 skills/ 目录复制 SKILL.md + references/
  3. 从 knowledge/ 目录复制对应的安全知识文件
  4. 从 commands/ 目录复制 slash command 定义
  5. 生成 .claude-plugin/plugin.json
  6. 输出到 dist/<extension-name>/

示例:
  bash scripts/package.sh           # 构建
  bash scripts/package.sh && bash scripts/deploy.sh all  # 构建 + 部署
EOF
    exit 0
fi

EXTENSIONS_DIR="$PROJECT_ROOT/extensions"
DIST="$PROJECT_ROOT/dist"

echo "==> Packaging SecGuardian extensions..."

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
             "$dist_dir/knowledge/concepts" "$dist_dir/knowledge/languages" \
             "$dist_dir/knowledge/detectors" "$dist_dir/knowledge/protocols"

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
        skill_dir="$PROJECT_ROOT/skills/${cmd}-${skill_name}"
        if [ -d "$skill_dir" ]; then
            cp -r "$skill_dir" "$dist_dir/skills/"
            skill_count=$((skill_count + 1))
        else
            echo "    [WARN] skill dir not found: ${cmd}-${skill_name}"
        fi
    done
    echo "    skills: $skill_count"

    # Copy knowledge files declared in extension.json
    concept_count=0
    for concept in $(jq -r '.knowledge.concepts[]' "$ext_json"); do
        cf="$PROJECT_ROOT/knowledge/concepts/${concept}.md"
        if [ -f "$cf" ]; then
            cp "$cf" "$dist_dir/knowledge/concepts/"
            concept_count=$((concept_count + 1))
        fi
    done
    echo "    concepts: $concept_count"

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
            df="$PROJECT_ROOT/knowledge/detectors/${detector}.md"
            if [ -f "$df" ]; then
                cp "$df" "$dist_dir/knowledge/detectors/"
                detector_count=$((detector_count + 1))
            fi
        done
    fi
    echo "    detectors: $detector_count"

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

    echo "    packaged: $dist_dir"
done

echo "==> Done. Output in $DIST/"
