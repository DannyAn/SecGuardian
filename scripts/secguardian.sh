#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  SecGuardian CLI — AI-Native Security Guardian              ║
# ║  Independent CLI for secaudit / secguard / secreview       ║
# ╚══════════════════════════════════════════════════════════════╝
#
# 用法:
#   bash scripts/secguardian.sh audit --skill taint-analysis --path ./src
#   bash scripts/secguardian.sh audit --skill cryptography --path ./src --sarif
#   bash scripts/secguardian.sh scan --path ./src --filters memory.*,system.*
#   bash scripts/secguardian.sh review --path ./src --lang python
#   bash scripts/secguardian.sh list skills
#   bash scripts/secguardian.sh list detectors
#
# 这是独立 CLI 入口 — 不依赖 Claude Code、OpenCode 或 Gemini CLI。
# 它加载 skill + knowledge 文件，组装完整的分析上下文，
# 指导 AI 执行安全审计并将结果写入标准输出目录。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── 帮助信息 ──────────────────────────────────
show_help() {
    cat << 'EOF'
SecGuardian CLI — AI-Native Security Guardian

命令:
  audit    AI 深度安全审计 (secaudit — 旗舰)
  scan     AI 引导的代码漏洞发现 (secguard)
  review   安全编码规范审查 (secreview)
  list     列出可用的 skills 或 detectors
  help     显示帮助

审计用法:
  bash scripts/secguardian.sh audit --skill <name> --path <dir> [--sarif] [--output <file>]
  bash scripts/secguardian.sh audit --skill taint-analysis --path ./src
  bash scripts/secguardian.sh audit --skill cryptography --path ./src --sarif
  bash scripts/secguardian.sh audit --skill all --path ./src

扫描用法:
  bash scripts/secguardian.sh scan --path <dir> [--filters <ns>] [--sarif]
  bash scripts/secguardian.sh scan --path ./src --filters memory.*
  bash scripts/secguardian.sh scan --path ./src --filters memory.*,system.* --sarif

审查用法:
  bash scripts/secguardian.sh review --path <dir> [--lang <lang>] [--sarif]
  bash scripts/secguardian.sh review --path ./src --lang python

列出:
  bash scripts/secguardian.sh list skills
  bash scripts/secguardian.sh list detectors
EOF
}

# ── 参数解析 ──────────────────────────────────
CMD="${1:-help}"; shift 2>/dev/null || true

SKILL=""
PATH_ARG="."
FILTERS="*"
LANG=""
OUTPUT_SARIF=false
OUTPUT_FILE=""
OUTPUT_DIR=""  # User-overridable base output dir (default: .codeagent)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill) SKILL="$2"; shift 2 ;;
        --path) PATH_ARG="$2"; shift 2 ;;
        --filters) FILTERS="$2"; shift 2 ;;
        --lang) LANG="$2"; shift 2 ;;
        --sarif) OUTPUT_SARIF=true; shift ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Base output directory (default: .codeagent — unified for all AI agents)
CODEAGENT_BASE="${OUTPUT_DIR:-${PROJECT_ROOT}/.codeagent}"

# ── 工具函数 ──────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── List 命令 ──────────────────────────────────
list_skills() {
    echo ""
    echo -e "${BOLD}SecGuardian — 可用 Skills${NC}"
    echo ""

    echo -e "${BOLD}★ 旗舰产品 — AI 深度安全审计 (secaudit)${NC}"
    echo ""

    echo "  Analysis (分析方法 — 5):"
    for skill_dir in "$PROJECT_ROOT/skills/secaudit-"*/; do
        local name=$(basename "$skill_dir")
        local cat=$(head -5 "$skill_dir/SKILL.md" 2>/dev/null | grep "category:" | head -1 | sed 's/category: //')
        local desc=$(head -5 "$skill_dir/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/description: //')
        if [ "$cat" = "analysis" ]; then
            printf "    ${CYAN}%-35s${NC} %s\n" "${name#secaudit-}" "$desc"
        fi
    done

    echo ""
    echo "  Domain (安全领域 — 12):"
    for skill_dir in "$PROJECT_ROOT/skills/secaudit-"*/; do
        local name=$(basename "$skill_dir")
        local cat=$(head -5 "$skill_dir/SKILL.md" 2>/dev/null | grep "category:" | head -1 | sed 's/category: //')
        local desc=$(head -5 "$skill_dir/SKILL.md" 2>/dev/null | grep "description:" | head -1 | sed 's/description: //')
        if [ "$cat" = "domain" ]; then
            printf "    ${CYAN}%-35s${NC} %s\n" "${name#secaudit-}" "$desc"
        fi
    done

    echo ""
    echo -e "${BOLD}代码漏洞发现 (secguard) + 安全规范审查 (secreview)${NC}"
    echo ""
    echo "  Language-specific: cpp, java, python, go (每个语言 2 skills)"
    echo ""

    echo -e "用法: ${CYAN}bash scripts/secguardian.sh audit --skill <name> --path ./src${NC}"
    echo -e "      ${CYAN}bash scripts/secguardian.sh scan --path ./src --filters memory.*${NC}"
    echo -e "      ${CYAN}bash scripts/secguardian.sh review --path ./src --lang python${NC}"
    echo ""
}

list_detectors() {
    echo ""
    echo -e "${BOLD}SecGuardian — 26 个检测器${NC}"
    echo ""
    for ns in memory concurrency system crypto; do
        echo -e "${BOLD}  $ns${NC}"
        cat "$PROJECT_ROOT/skills/secguard-cpp/references/detector-index.md" 2>/dev/null | \
            grep "| $ns\." | sed 's/|/ /g' | awk '{printf "    %-35s %s %s\n", $2, $4, $5}' || true
        echo ""
    done
}

# ── Audit 命令 ─────────────────────────────────
run_audit() {
    local skill="$1"
    local path="$2"
    local scan_id="sec-$(date -u +%Y%m%dT%H%M%S)-$(python3 -c "import random;print(''.join(random.choices('abcdef0123456789',k=4)))" 2>/dev/null || echo "0000")"

    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  SecGuardian — AI 深度安全审计                     ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Skill:   ${CYAN}$skill${NC}"
    echo -e "  Path:    ${CYAN}$path${NC}"
    echo -e "  Scan ID: ${CYAN}$scan_id${NC}"
    echo ""

    # 检查 skill 存在
    local skill_dir="$PROJECT_ROOT/skills/secaudit-${skill}"
    if [ ! -d "$skill_dir" ]; then
        echo -e "  ✗ Skill 不存在: secaudit-$skill"
        echo "  可用 skills:"
        ls "$PROJECT_ROOT/skills/" | grep "secaudit-" | sed 's/secaudit-/  - /'
        exit 1
    fi

    # 创建输出目录
    local output_dir="$CODEAGENT_BASE/secaudit-secguardian/scans/$scan_id"
    mkdir -p "$output_dir/findings"

    # ── 组装 System Prompt ────────────────────
    local prompt_file="$output_dir/.system_prompt.md"
    {
        echo "# Security Audit Context"
        echo ""
        echo "## Task"
        echo "You are a senior security auditor. Perform a thorough audit using the methodology below."
        echo "Target: $path"
        echo "Audit Skill: $skill"
        echo "Output directory: $output_dir"
        echo ""
        echo "---"
        echo ""

        # 加载 protocol
        if [ -f "$PROJECT_ROOT/knowledge/protocols/scan-output.md" ]; then
            cat "$PROJECT_ROOT/knowledge/protocols/scan-output.md"
        fi
        echo ""
        echo "---"
        echo ""

        # 加载 skill SKILL.md
        echo "## Audit Methodology: $skill"
        echo ""
        cat "$skill_dir/SKILL.md"
        echo ""
        echo "---"
        echo ""

        # 加载 report template
        if [ -f "$PROJECT_ROOT/knowledge/report-template.md" ]; then
            echo "## Report Template"
            echo "After completing the audit, generate a report following this template:"
            echo ""
            cat "$PROJECT_ROOT/knowledge/report-template.md"
        fi
    } > "$prompt_file"

    # ── 输出指引 ──────────────────────────────
    local skill_desc=$(head -5 "$skill_dir/SKILL.md" | grep "description:" | head -1 | sed 's/description: //')

    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │  AI 审计指令已组装完成                               │"
    echo "  │                                                     │"
    echo "  │  1. 审计上下文: $prompt_file"
    echo "  │  2. Skill: $skill — $skill_desc"
    echo "  │  3. 目标: $path"
    echo "  │                                                     │"
    echo "  │  请在 AI 对话中执行以下指令:                          │"
    echo "  │                                                     │"
    printf "  │  ${CYAN}请阅读以下系统提示并执行安全审计:${NC}              │\n"
    printf "  │  ${CYAN}cat %s${NC}  │\n" "$prompt_file"
    echo "  │                                                     │"
    echo "  │  然后扫描 $path 并输出结果到:                        │"
    echo "  │  $output_dir/manifest.json                          │"
    echo "  │  $output_dir/findings/                              │"
    echo "  │                                                     │"
    if $OUTPUT_SARIF; then
        echo "  │  同时生成 SARIF: $output_dir/results.sarif            │"
    fi
    echo "  └─────────────────────────────────────────────────────┘"

    # 生成 manifest 骨架
    cat > "$output_dir/manifest.json" << MANIFEST
{
  "protocol": "1.1",
  "scan": {
    "id": "$scan_id",
    "command": "secaudit",
    "extension": "secaudit-secguardian",
    "skill": "$skill",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "pending"
  },
  "scope": {
    "path": "$path",
    "mode": "full"
  },
  "summary": {
    "findings": { "critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0, "total": 0 }
  },
  "findings": []
}
MANIFEST

    echo ""
    echo -e "  ${GREEN}✓${NC} 审计上下文已就绪"
    echo -e "  ${GREEN}✓${NC} 输出目录: $output_dir/"
    echo ""
}

# ── Scan 命令 ──────────────────────────────────
run_scan() {
    local path="$1"
    local filters="$2"
    local scan_id="sc-$(date -u +%Y%m%dT%H%M%S)-$(python3 -c "import random;print(''.join(random.choices('abcdef0123456789',k=4)))" 2>/dev/null || echo "0000")"

    echo ""
    echo -e "${BOLD}═══ SecGuardian — AI 引导代码安全扫描 ═══${NC}"
    echo ""
    echo -e "  Path:    ${CYAN}$path${NC}"
    echo -e "  Filters: ${CYAN}$filters${NC}"
    echo -e "  Scan ID: ${CYAN}$scan_id${NC}"
    echo ""

    local output_dir="$CODEAGENT_BASE/secguard-secguardian/scans/$scan_id"
    mkdir -p "$output_dir/findings"

    # 运行索引器（搜索多个可能的 binary 路径）
    local index_json="$output_dir/index.json"

    # Priority: 1) internal/  2) scripts/  3) PATH  4) GOPATH/bin
    # Deployed extensions may ship a prebuilt binary alongside skills/
    local index_bin=""
    local search_paths=(
        "$PROJECT_ROOT/internal/secguardian-index"
        "$PROJECT_ROOT/scripts/secguardian-index"
        "$(command -v secguardian-index 2>/dev/null || true)"
        "$HOME/go/bin/secguardian-index"
    )

    for candidate in "${search_paths[@]}"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ] && [ -f "$candidate" ]; then
            index_bin="$candidate"
            break
        fi
    done

    if [ -n "$index_bin" ]; then
        echo -e "  ${CYAN}→${NC} Running code indexer ($index_bin)..."
        if $index_bin --path "$path" --output "$index_json" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Code index generated: $index_json"
        else
            echo -e "  ${YELLOW}⚠${NC} Indexer failed, continuing without pre-computed context"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} secguardian-index binary not found — scan will work but without pre-computed code context"
        echo -e "  ${YELLOW}   Build it: cd internal && go build -o secguardian-index .${NC}"
    fi

    # 组装分层 prompts (System + Skill + Context)
    local system_file="$output_dir/system_prompt.md"
    local skill_file="$output_dir/skill_prompt.md"
    local context_file="$output_dir/context_prompt.md"
    local prompt_file="$output_dir/.system_prompt.md"

    # Layer 1: System (immutable rules — cached by LLM provider)
    if [ -f "$PROJECT_ROOT/knowledge/prompt-templates/system.md" ]; then
        cp "$PROJECT_ROOT/knowledge/prompt-templates/system.md" "$system_file"
    else
        echo "# SecGuardian System Prompt (fallback)" > "$system_file"
        cat "$PROJECT_ROOT/knowledge/protocols/scan-output.md" >> "$system_file"
    fi

    # Layer 2: Skill-specific instructions
    {
        echo "# Security Scan: $PATH_ARG"
        echo "Target: $PATH_ARG | Filters: $FILTERS | Mode: full"
        echo ""
        if [ -f "$PROJECT_ROOT/knowledge/prompt-templates/skill-secguard.md" ]; then
            cat "$PROJECT_ROOT/knowledge/prompt-templates/skill-secguard.md"
        else
            echo "Execute all matched detectors in severity order."
            echo "Output results to findings/ and manifest.json."
        fi
        echo ""
        echo "Reference: skills/secguard-cpp/references/detector-index.md"
        cat "$PROJECT_ROOT/skills/secguard-cpp/references/detector-index.md"
    } > "$skill_file"

    # Layer 3: Context (per-execution, changes every scan)
    {
        echo "## Scan Scope"
        echo "- Path: $PATH_ARG"
        echo "- Filters: $FILTERS"
        echo "- Mode: full"
        echo ""

        if [ -f "$index_json" ]; then
            echo "## Code Index (pre-computed by tree-sitter)"
            echo '```json'
            head -c 5000 "$index_json" 2>/dev/null || true
            echo '```'
            echo ""
            echo "### Usage"
            echo "- Use symbol index for function/variable boundaries"
            echo "- Use call graph for caller/callee relationships"
            echo "- Use alloc/free map for memory management patterns"
            echo ""
        fi
    } > "$context_file"

    # Assemble final monolithic prompt (for backward compatibility)
    cat "$system_file" "$skill_file" "$context_file" > "$prompt_file"

    # Generate CI gating status (initial skeleton, filled by AI after scan)
    local status_file="$output_dir/status.json"
    local base_dir="$CODEAGENT_BASE/secguard-secguardian/scans"
    cat > "$status_file" << STATUSJSON
{
  "scan_id": "$scan_id",
  "passed": false,
  "score": 100,
  "max_score": 100,
  "findings": {"critical": 0, "high": 0, "medium": 0, "low": 0, "info": 0, "total": 0},
  "confidence": {"high": 0, "medium": 0, "low": 0},
  "threshold": {"critical_max": 0, "high_max": 5, "breached": false, "breached_at": ""},
  "exit_code": 0,
  "note": "Skeleton — overwrite with actual findings after AI scan"
}
STATUSJSON

    # Create latest symlink for daily-build/CI consumption
    ln -sfn "$(basename "$output_dir")" "$base_dir/latest" 2>/dev/null || true

    echo -e "  ${GREEN}✓${NC} 扫描上下文已就绪: $output_dir/"
    echo -e "  ${GREEN}✓${NC} 三层 prompts: system($(wc -c < "$system_file")) + skill($(wc -c < "$skill_file")) + context($(wc -c < "$context_file")) bytes"
    echo -e "  ${GREEN}✓${NC} CI status: $status_file + $base_dir/latest → $(basename "$output_dir")"
    echo ""
}

# ── Review 命令 ────────────────────────────────
run_review() {
    local path="$1"
    local lang="${2:-auto}"
    local scan_id="rv-$(date -u +%Y%m%dT%H%M%S)-$(python3 -c "import random;print(''.join(random.choices('abcdef0123456789',k=4)))" 2>/dev/null || echo "0000")"

    echo ""
    echo -e "${BOLD}═══ SecGuardian — 安全编码规范审查 ═══${NC}"
    echo ""
    echo -e "  Path:     ${CYAN}$path${NC}"
    echo -e "  Language: ${CYAN}$lang${NC}"
    echo -e "  Scan ID:  ${CYAN}$scan_id${NC}"
    echo ""

    local output_dir="$CODEAGENT_BASE/secreview-secguardian/scans/$scan_id"
    mkdir -p "$output_dir/findings"

    echo -e "  ${GREEN}✓${NC} 审查上下文已就绪: $output_dir/"
    echo ""
}

# ── 主路由 ─────────────────────────────────────
case "$CMD" in
    audit)
        if [ -z "$SKILL" ]; then
            echo "错误: --skill 参数必填"
            echo "用法: bash scripts/secguardian.sh audit --skill taint-analysis --path ./src"
            echo "列出可用 skills: bash scripts/secguardian.sh list skills"
            exit 1
        fi
        run_audit "$SKILL" "$PATH_ARG"
        ;;
    scan)
        run_scan "$PATH_ARG" "$FILTERS"
        ;;
    review)
        run_review "$PATH_ARG" "$LANG"
        ;;
    list)
        case "${1:-skills}" in
            skills) list_skills ;;
            detectors) list_detectors ;;
            *) list_skills ;;
        esac
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "未知命令: $CMD"
        show_help
        exit 1
        ;;
esac

if [ "$CMD" != "list" ] && [ "$CMD" != "help" ]; then
    echo -e "  ${GREEN}SecGuardian CLI — 所有文件已准备就绪。${NC}"
    echo -e "  在 AI 对话中以 ${CYAN}系统提示${NC} 方式加载上述 prompt 文件即可执行审计。"
    echo ""
fi
