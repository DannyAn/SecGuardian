# TASK-002: Phase 2 — 协议文件升级

> **Feature**: FEATURE-001-output-protocol
> **状态**: ✅ Done
> **完成日期**: 2026-06-05
> **原则**: Task 驱动编码

## Goal

升级 2 个协议文件，定义四段式结构和 SARIF 增强规范。

## Done

- [x] `knowledge/protocols/scan-output.md` → v3.0
  - [x] 定义 report.md 四段式模板（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
  - [x] 定义质量门禁检查清单
  - [x] 定义 message.text 单行格式
- [x] `knowledge/protocols/sarif-output.md` → v1.1
  - [x] 新增 `message.markdown` 字段规范（完整四段式富文本）
  - [x] 新增 `relatedLocations[]` 数据流 Source→Sink 规范
  - [x] 新增 `taxa[]` CWE 分类映射规范
  - [x] 增强 `properties`（CVSS/impact/effort/verification）
  - [x] 定义 SARIF result 完整 JSON 结构示例
- [x] 更新 10 个 skill 文件的输出阶段引用

## Verification

```bash
# 协议文件版本验证
grep "v3.0" knowledge/protocols/scan-output.md
grep "v1.1" knowledge/protocols/sarif-output.md

# 回归扫描验证
bash scripts/dev-deploy.sh
# → 扫描 examples/python-vuln-demo → 验证每个 finding 四段式完整
```

## Files Changed

| 文件 | 版本变更 |
|------|---------|
| `knowledge/protocols/scan-output.md` | v2.0 → v3.0 |
| `knowledge/protocols/sarif-output.md` | v1.0 → v1.1 |
| `skills/secguard/*/SKILL.md` (5 files) | 追加输出完整性要求章节 |
| `skills/secreview/*/SKILL.md` (5 files) | 追加输出完整性要求章节 |
