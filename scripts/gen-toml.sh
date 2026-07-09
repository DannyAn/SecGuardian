#!/bin/bash
# SecGuardian — 自动生成 Gemini CLI TOML 命令文件
#
# 用法: bash scripts/gen-toml.sh
#
# 读取 commands/<name>.md，生成 commands/gemini/<name>.toml。
#
# .md 文件格式要求（带 YAML frontmatter）:
#   ---
#   description:"命令简述"
#   ---
#   # /command - 标题
#   ...正文...
#
# 生成规则:
#   - description: 从 YAML frontmatter 的 description 字段提取
#   - prompt: 跳过 frontmatter，将正文嵌入 TOML multiline string
#   - {{args}} 占位符: 自动插入在 prompt 开头

set -euo pipefail

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — Gemini TOML 命令生成器

读取 commands/claude/<name>.md，自动生成 commands/gemini/<name>.toml。

用法:
  bash scripts/gen-toml.sh       # 生成全部 TOML
  bash scripts/gen-toml.sh -h    # 显示此帮助

.md 文件格式要求（带 YAML frontmatter）:
  ---
  description:"命令简述"
  ---
  # /command - 标题
  ...正文...

生成规则:
  - description: 从 YAML frontmatter 的 description 字段提取
  - prompt: 跳过 frontmatter，将正文 + {{args}} 嵌入 TOML multiline string

何时使用:
  修改 commands/claude/<name>.md 后运行此脚本，确保 Gemini CLI 的 TOML 文件与
  Markdown 命令保持同步。

示例:
  bash scripts/gen-toml.sh       # 生成
  bash scripts/deploy.sh cac     # 部署到 Gemini CLI（会自动调用此脚本）
EOF
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD_SRC="$PROJECT_ROOT/commands/claude"
TOML_OUT="$PROJECT_ROOT/commands/gemini"

mkdir -p "$TOML_OUT"

echo "==> 生成 Gemini TOML 命令文件..."

gen_count=0
for md_file in "$CMD_SRC"/*.md; do
    name=$(basename "$md_file" .md)
    toml_file="$TOML_OUT/${name}.toml"

    # 提取 description: 从 YAML frontmatter 的 description 字段
    # 格式: description: "文本" 或 description:"文本"
    desc=$(sed -n '/^---$/,/^---$/p' "$md_file" | grep "^description:" | head -1 | sed 's/^description:[[:space:]]*"//; s/"$//')
    if [ -z "$desc" ]; then
        # Fallback: 从第一个 # 标题提取
        desc=$(head -1 "$md_file" | sed 's/^# //; s/^\/.* - //')
        echo "  [WARN] ${name}.md: 未找到 YAML description 字段，从标题回退: $desc"
    fi

    # 找到第二个 ---（frontmatter 结束行号），跳过整个 frontmatter
    # 如果文件以 --- 开头，则跳过 frontmatter；否则跳过第一行标题
    first_line=$(head -1 "$md_file")
    if [ "$first_line" = "---" ]; then
        # 有 YAML frontmatter: 找到结束的 --- 行号
        body_start=$(awk '/^---$/ { count++; if (count==2) { print NR+1; exit } }' "$md_file")
        if [ -z "$body_start" ]; then
            body_start=2
        fi
    else
        # 无 frontmatter (旧格式): 跳过第一行标题
        body_start=2
    fi

    # 生成 TOML
    {
        echo "description = \"$desc\""
        echo ""
        echo "prompt = \"\"\""
        echo "你是 SecGuardian 安全守卫的 AI 安全分析专家。"
        echo ""
        echo "用户输入: {{args}}"
        echo ""
        echo "---"
        echo ""
        # 从 frontmatter 之后开始嵌入正文
        tail -n "+${body_start}" "$md_file"
        echo "\"\"\""
    } > "$toml_file"

    echo "  + commands/gemini/${name}.toml (desc: $desc)"
    gen_count=$((gen_count + 1))
done

echo "  生成 $gen_count 个 TOML 文件 → $TOML_OUT/"
echo "  提示: 如果修改了 commands/claude/*.md，重新运行本脚本即可同步 TOML。"
