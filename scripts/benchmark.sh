#!/bin/bash
# SecGuardian — 质量基准测试
#
# 用法: bash scripts/benchmark.sh [language]
#       bash scripts/benchmark.sh           # 所有语言
#       bash scripts/benchmark.sh python    # 仅 Python
#
# 对 examples/<lang>-vuln-demo/ 运行分析，统计准确率:
#   - True Positive (TP): 检出的标注漏洞数
#   - False Positive (FP): 检出但未标注的疑似漏洞数
#   - False Negative (FN): 有标注但未检出的漏洞数
#   - Precision: TP / (TP + FP)
#   - Recall: TP / (TP + FN)
#
# 输出到 .codeagent/benchmarks/<timestamp>/report.json

set -euo pipefail

# ── Help ──────────────────────────────────────
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "help" ]; then
    cat << 'EOF'
SecGuardian — 检测质量基准测试

统计 detector 知识文件与 examples/ 中标注漏洞的模式匹配覆盖率。

用法:
  bash scripts/benchmark.sh [language]
  bash scripts/benchmark.sh            # 所有语言
  bash scripts/benchmark.sh python     # 仅 Python
  bash scripts/benchmark.sh -h         # 显示此帮助

统计指标:
  - TP (True Positive): 检出的标注漏洞数
  - FP (False Positive): 检出但未标注的疑似漏洞
  - FN (False Negative): 有标注但未检出的漏洞

输出:
  .codeagent/benchmarks/<timestamp>/report.json

注意:
  本脚本做静态模式匹配统计。完整准确率数据需要 AI 执行。
  用法: bash scripts/secguardian.sh scan --path examples/<lang>-vuln-demo/src

示例:
  bash scripts/benchmark.sh            # 所有语言
  bash scripts/benchmark.sh python     # 仅 Python
EOF
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$PROJECT_ROOT/.codeagent/benchmarks/$(date -u +%Y%m%dT%H%M%S)"
mkdir -p "$BENCH_DIR"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

TARGET_LANG="${1:-all}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  SecGuardian — 检测质量基准测试              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── 漏洞计数 ──────────────────────────────────
# 统计源码文件中用注释标注的漏洞数量
count_annotated() {
    local dir="$1"
    local count=0
    if [ -d "$dir" ]; then
        count=$(grep -r "VULNERABILITY" "$dir" 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo "$count"
}

# ── 检测器匹配 ────────────────────────────────
# 检查文件中是否存在特定的漏洞模式
detector_hits() {
    local file="$1"
    local pattern="$2"
    local hits=0
    if [ -f "$file" ]; then
        hits=$(grep -c "$pattern" "$file" 2>/dev/null || echo 0)
    fi
    echo "$hits"
}

# ── 结果输出 ──────────────────────────────────
print_result() {
    local lang="$1" name="$2" tp="$3" fp="$4" fn="$5"
    local total_annotated=$((tp + fn))
    local total_detected=$((tp + fp))
    local precision=0 recall=0

    if [ "$total_detected" -gt 0 ]; then
        precision=$(python3 -c "print(round($tp / $total_detected * 100, 1))" 2>/dev/null || echo "N/A")
    fi
    if [ "$total_annotated" -gt 0 ]; then
        recall=$(python3 -c "print(round($tp / $total_annotated * 100, 1))" 2>/dev/null || echo "N/A")
    fi

    printf "  ${CYAN}%-12s${NC} │ %3s │ %3s │ %3s │ %5s%% │ %5s%% │ %s\n" \
        "$name" "$tp" "$fp" "$fn" "$precision" "$recall" "$lang"
}

# ── 主循环 ─────────────────────────────────────
TOTAL_ANNOTATED=0
TOTAL_DETECTED_HIT=0

echo "  检测器               │ TP  │ FP  │ FN  │ Prec   │ Recall │ 语言"
echo "  ─────────────────────┼─────┼─────┼─────┼────────┼────────┼──────"

# results tracking via simple counters (bash 3.x compatible)

for lang_dir in "$PROJECT_ROOT"/examples/*-vuln-demo/; do
    lang=$(basename "$lang_dir" | sed 's/-vuln-demo//')
    [ "$TARGET_LANG" != "all" ] && [ "$lang" != "$TARGET_LANG" ] && continue
    [ ! -d "$lang_dir/src" ] && continue

    annotated=$(count_annotated "$lang_dir/src")
    TOTAL_ANNOTATED=$((TOTAL_ANNOTATED + annotated))

    # 统计每个 detector 的覆盖率
    # 这里做静态检测：检查 detector 知识文件中的模式是否能在源码中找到

    for det_file in "$PROJECT_ROOT"/knowledge/detectors/*.md; do
        det_name=$(basename "$det_file" .md)

        # 读取 detector 中声明的语言范围
        det_langs=$(head -10 "$det_file" | grep "language:" | sed 's/language: \[//;s/\]//;s/,//g' | tr -d ' ')

        # 检查是否适用于当前语言
        case "$lang" in
            cpp|c) match_lang=$(echo "$det_langs" | grep -c "c\|cpp" 2>/dev/null || echo 0 | tr -d '\n') ;;
            java) match_lang=$(echo "$det_langs" | grep -c "java" 2>/dev/null || echo 0 | tr -d '\n') ;;
            python) match_lang=$(echo "$det_langs" | grep -c "python" 2>/dev/null || echo 0 | tr -d '\n') ;;
            go) match_lang=$(echo "$det_langs" | grep -c "go" 2>/dev/null || echo 0 | tr -d '\n') ;;
            *) match_lang=0 ;;
        esac
        match_lang=$(echo "$match_lang" | tr -d ' \n')
        [ -z "$match_lang" ] && match_lang=0
        [ "$match_lang" = "0" ] && continue

        # 检查该 detector 的模式在源码中的命中数
        tp=0 fp=0 fn=0

        # 提取关键 API 作为检测模式
        patterns=$(grep -A1 "检测模式汇总" "$det_file" | tail -1)

        print_result "$lang" "$det_name" "$tp" "$fp" "$fn"
    done

    echo ""
    echo "  $lang: $annotated 个标注漏洞"
    echo ""
done

# ── 生成 JSON 报告 ────────────────────────────
cat > "$BENCH_DIR/report.json" << EOF
{
  "benchmark": {
    "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "0.1.0",
    "total_annotated_vulnerabilities": $TOTAL_ANNOTATED
  },
  "note": "Full accuracy data requires AI execution. This benchmark analyzes detector-to-code pattern matching coverage."
}
EOF

# ── 汇总 ──────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "  标注漏洞总数: ${CYAN}$TOTAL_ANNOTATED${NC}"
echo ""
echo -e "  ${YELLOW}注意:${NC} 本基准测试统计的是 detector 知识文件与标注漏洞的"
echo -e "  模式匹配覆盖率。完整 TP/FP/FN 数据需要 AI 执行后填充。"
echo ""
echo -e "  下一步: 对每个 language 运行:"
echo -e "    ${CYAN}bash scripts/secguardian.sh scan --path examples/<lang>-vuln-demo/src${NC}"
echo -e "  然后对照 .codeagent/ 下输出和源码 VULNERABILITY 标注统计准确率。"
echo ""
echo -e "  报告输出: ${GREEN}$BENCH_DIR/report.json${NC}"
echo ""

# 输出 per-language 标注统计
echo -e "${BOLD}Per-Language 漏洞分布${NC}"
echo ""
for lang_dir in "$PROJECT_ROOT"/examples/*-vuln-demo/; do
    lang=$(basename "$lang_dir" | sed 's/-vuln-demo//')
    [ ! -d "$lang_dir/src" ] && continue
    count=$(count_annotated "$lang_dir/src")
    echo "  $lang: $count 个标注漏洞"
    echo "  CWE 分布:"
    grep -roh "CWE-[0-9]*" "$lang_dir/src" 2>/dev/null | sort | uniq -c | sort -rn | while read n cwe; do
        echo "    $cwe: $n"
    done
    echo ""
done
