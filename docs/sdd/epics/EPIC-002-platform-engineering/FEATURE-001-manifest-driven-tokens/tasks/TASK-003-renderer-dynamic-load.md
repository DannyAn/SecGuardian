# TASK-003: render-report.py DETECTOR_RULE_INDEX 动态加载

> **Feature**: FEATURE-001-manifest-driven-tokens
> **状态**: ✅ Done
> **完成日期**: 2026-06-07
> **原则**: Task 驱动编码

## Goal

移除 `scripts/render-report.py` 中硬编码的 68 行 `DETECTOR_RULE_INDEX`，改为从 `manifest.json` 或 `knowledge/detectors/` 目录动态构建映射表。

## Done

- [x] 实现 `load_detector_index()` 函数
  - [x] 遍历 `knowledge/detectors/` 目录
  - [x] 解析每个 detector 文件的 yaml frontmatter（cwe + namespace）
  - [x] 构建 `{detector_name: {index, cwe, namespace}}` 映射
- [x] 替换所有 `DETECTOR_RULE_INDEX[...]` 引用为函数调用
- [x] SARIF 输出 CWE 字段与硬编码版本一致

## Verification

```bash
# 对比新旧版本 SARIF 输出
python3 scripts/render-report.py --findings old-scan/findings.json --output /tmp/new/
diff <(jq '.runs[0].results[].ruleId' /tmp/old/results.sarif | sort) \
     <(jq '.runs[0].results[].ruleId' /tmp/new/results.sarif | sort)
# Expected: no diff

# 新增 detector 后自动识别
# 1. 创建新 detector 文件（含 cwe frontmatter）
# 2. 扫描 → SARIF 中 ruleId + taxa 自动填充
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `scripts/render-report.py` | -70 行（删除 DETECTOR_RULE_INDEX）+ 25 行（load_detector_index 函数） |
