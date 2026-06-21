# TASK-002: P0 — 6 个缺失 FP+Evidence 检测器从零补齐

> **Feature**: FEATURE-002-detector-quality
> **状态**: ✅ Done
> **完成日期**: 2026-06-11
> **原则**: Task 驱动编码

## Goal

为 6 个完全没有误报排除章节和证据收集指引的检测器，从零补齐完整模板。

## Done

- [x] `resource-socket-leak.md` — 48 行 → ~120 行（7 章节 + 7 项 FP 排除 + MUST 2/SHOULD 2/MAY 2）
- [x] `resource-lock-misuse.md` — COMPLETE REWRITE
- [x] `resource-file-double-close.md` — COMPLETE REWRITE
- [x] `resource-file-use-after-close.md` — COMPLETE REWRITE
- [x] `resource-refcount-misuse.md` — COMPLETE REWRITE
- [x] `system-secrets-detection.md` — COMPLETE REWRITE

### 每个检测器补齐内容

- [x] 7 个必需章节全部存在
- [x] yaml frontmatter（precision + confidence + severity + cwe + language + tags）
- [x] 威胁定义（一句话核心原则 + CWE 映射 + 漏洞后果）
- [x] 检测逻辑（按语言/模式分 Step，BAD/GOOD 代码对比）
- [x] 证据收集指引（MUST/SHOULD/MAY 三级，每项含 checkbox + schema 字段）
- [x] 误报排除（三列表格：场景 / 排除依据 / 证据要求）
- [x] 修复指引（1→2→3 分层编号）
- [x] 检测模式汇总（MATCH/EXCLUDE 分离 + Evidence 锚点）

## Verification

```bash
# 结构验证
bash scripts/self-check.sh
# → P0 批次 6 个检测器全部通过
```

## Files Changed

| 文件 | 改动量 |
|------|--------|
| `knowledge/guard-rules/resource-socket-leak.md` | +72 行 |
| `knowledge/guard-rules/resource-lock-misuse.md` | +65 行 |
| `knowledge/guard-rules/resource-file-double-close.md` | +60 行 |
| `knowledge/guard-rules/resource-file-use-after-close.md` | +58 行 |
| `knowledge/guard-rules/resource-refcount-misuse.md` | +55 行 |
| `knowledge/guard-rules/system-secrets-detection.md` | +50 行 |
