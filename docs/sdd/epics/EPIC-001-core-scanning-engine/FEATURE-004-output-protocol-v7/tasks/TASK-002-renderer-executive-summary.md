# TASK-002: Renderer — executive-summary.md 生成

## Goal

新增 render_executive_summary()，从 summary.json + findings 列表生成一页统一入口。

## Done

- [ ] render_executive_summary() 函数实现
- [ ] 写入 human/executive-summary.md
- [ ] 包含：评分 + 等级、严重度分布
- [ ] 包含：发现分布交叉表（检测器 × 涉及文件数 × 发现数，Top-5）
- [ ] 包含：风险集中度（文件 × 发现数 × 占比，Top-5）
- [ ] 包含：Top 3 Critical 风险 + 导航引导
- [ ] main() 调用

## Design

```python
def render_executive_summary(findings_data, output_dir):
    from collections import Counter
    findings = findings_data.get("findings", [])
    score = findings_data.get("security_score", 0)
    grade = findings_data.get("score_grade", "F")
    sev = findings_data.get("findings_by_severity", {})

    # 发现分布（检测器 x 文件）
    detector_files = {}
    detector_count = Counter()
    for f in findings:
        det = f.get("detector", "unknown")
        detector_files.setdefault(det, set()).add(f.get("file", ""))
        detector_count[det] += 1
    
    # 风险集中度（文件 x 发现数）
    file_count = Counter(f.get("file", "") for f in findings)
    total = len(findings)
    
    # Top-3 Critical
    sorted_f = sorted(findings, key=lambda x: {"Critical":0,"High":1}.get(x.get("severity",""),9))
    top3 = sorted_f[:3]
```

## Files

- scripts/render-report.py

## Verification

```bash
SCAN_DIR=".codeagent/secguard-secguardian/scans/sc-20260625"
python3 scripts/render-report.py --findings "$SCAN_DIR/findings.json" --index "$SCAN_DIR/index.json" --output "$SCAN_DIR/"
[ -f "$SCAN_DIR/human/executive-summary.md" ] && echo "exists"
grep -c "发现分布" "$SCAN_DIR/human/executive-summary.md"
```
