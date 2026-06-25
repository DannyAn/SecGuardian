# Output Protocol v7.0 — 实施计划

> **Feature**: FEATURE-004-output-protocol-v7
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: 📋 规划中

## Goal

基于 findings/<ns>/<detector>/（v5.0 不变）新增消费者导向输出，不增加 AI Agent 负担、不破坏向后兼容。

## Architecture

```
AI Agent（不变，只输出 findings/ 目录树）
    ↓
Renderer（render-report.py）
    ├── 现有: generate_report_md / generate_sarif / generate_summary / ...
    ├── 新增: render_executive_summary()   → human/executive-summary.md
    ├── 新增: render_remediation_pack()    → ai/remediation-pack.json
    ├── 修改: generate_report_md()         → report.md 精简（去掉3节）
    └── 新增: render_html_report()         → report.html
```

## File Structure

| 文件 | 改动 | 改动量 |
|------|------|--------|
| knowledge/protocols/scan-output.md | 升级 v7.0：目录结构+用户旅程+executive-summary 规范 | ~80 行 |
| knowledge/protocols/findings-schema.json | 新增 related_finding 定义 | ~40 行 |
| scripts/render-report.py | 新增 3 个函数 + 修改 1 个函数 | ~250 行 |
| scripts/e2e-verify.sh | Section 12 新增输出验证 | ~20 行 |
| commands/*.md | Step 4a 修复指导改为动态生成 | ~10 行 |
| commands/*.md | Step 4d 新增输出路径说明 | ~5 行 |

## Tasks（按执行顺序）

| # | 任务 | 文件 | 前置依赖 |
|---|------|------|---------|
| 001 | 协议文档 + 用户旅程 | scan-output.md + findings-schema.json | 无 |
| 002 | Renderer — render_executive_summary() | render-report.py | 001 |
| 003 | Renderer — render_remediation_pack() | render-report.py | 002（同文件顺序） |
| 004 | Renderer — generate_report_md() 精简 | render-report.py | 003（同文件顺序） |
| 005 | Renderer — render_html_report() | render-report.py | 004（同文件顺序） |
| 006 | E2E 验证更新 | e2e-verify.sh | 005 |
| 007 | 命令文档更新 | commands/*.md | 006 |

## Verification

每个 Task 完成后独立验证。全部完成后执行：

```bash
bash scripts/self-check.sh && bash scripts/e2e-verify.sh

# 专项验证
SCAN_DIR=$(readlink -f .codeagent/secguard-secguardian/scans/latest)
echo "=== executive-summary ==="
[ -f "$SCAN_DIR/human/executive-summary.md" ] && echo "exists"
grep -c "发现分布" "$SCAN_DIR/human/executive-summary.md" || echo "no cross-table"
echo "=== remediation-pack ==="
[ -f "$SCAN_DIR/ai/remediation-pack.json" ] && echo "exists"
python3 -c "
import json
with open('$SCAN_DIR/ai/remediation-pack.json') as f:
    d = json.load(f)
for r in d.get('remediations', []):
    print(f\"{r['finding_id']}: {len(r.get('related_findings',[]))} related\")
"
echo "=== report.html ==="
[ -f "$SCAN_DIR/report.html" ] && grep -c "severity-critical" "$SCAN_DIR/report.html" || echo "missing"
echo "=== report.md simplified ==="
! grep -q "合规仪表盘\|验证漏斗" "$SCAN_DIR/report.md" && echo "cleaned"
```
