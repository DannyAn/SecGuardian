#!/bin/bash
# SecGuardian — 自动生成 Gemini CLI TOML 命令文件
#
# 用法: bash scripts/gen-toml.sh
#
# 读取 commands/<name>.md 的首个 # 标题作为 description，
# 将整个 .md 正文作为 prompt body，生成 commands/gemini/<name>.toml。
#
# 生成规则:
#   - description: .md 文件第一行的 # 标题 (去掉 # /)
#   - prompt: 将 .md 的全部 Markdown 嵌入 TOML multiline string
#   - {{args}} 占位符: 自动插入在 prompt 开头

set -euo pipefail

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — Gemini TOML 命令生成器

读取 commands/<name>.md，自动生成 commands/gemini/<name>.toml。

用法:
  bash scripts/gen-toml.sh       # 生成全部 TOML
  bash scripts/gen-toml.sh -h    # 显示此帮助

生成规则:
  - description: .md 文件第一行的 # 标题
  - prompt: 将 .md 全文 + {{args}} 占位符嵌入 TOML multiline string

何时使用:
  修改 commands/<name>.md 后运行此脚本，确保 Gemini CLI 的 TOML 文件与
  Markdown 命令保持同步。

示例:
  bash scripts/gen-toml.sh       # 生成
  bash scripts/deploy.sh cac     # 部署到 Gemini CLI（会自动调用此脚本）
EOF
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD_SRC="$PROJECT_ROOT/commands"
TOML_OUT="$PROJECT_ROOT/commands/gemini"

mkdir -p "$TOML_OUT"

echo "==> 生成 Gemini TOML 命令文件..."

gen_count=0
for md_file in "$CMD_SRC"/*.md; do
    name=$(basename "$md_file" .md)
    toml_file="$TOML_OUT/${name}.toml"

    # 提取第一行 # 标题作为 description
    desc=$(head -1 "$md_file" | sed 's/^# //; s/^\/.* - //')

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
        # 跳过第一行标题行，嵌入剩余内容
        tail -n +2 "$md_file"
        echo "\"\"\""
    } > "$toml_file"

    echo "  + commands/gemini/${name}.toml"
    gen_count=$((gen_count + 1))
done

echo "  生成 $gen_count 个 TOML 文件 → $TOML_OUT/"
echo "  提示: 如果修改了 commands/*.md，重新运行本脚本即可同步 TOML。"
