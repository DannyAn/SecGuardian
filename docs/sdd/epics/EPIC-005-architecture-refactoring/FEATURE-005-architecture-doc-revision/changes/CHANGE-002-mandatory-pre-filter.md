# CHANGE-002: Mandatory Pre-Filter + Anchor Cross-Validation

> **Feature**: FEATURE-005 | **Date**: 2026-07-05
> **Trigger**: C++ scan verification — 36/0 validation pass but source full-reads and missing anchor cross-validation remain

## Reason

C++ 扫描验证了 CHANGE-001 的证据约束有效（36 findings, 0 errors），但暴露了两个剩余问题：

1. **源文件全量读取**：预筛仍是建议性的，LLM 为确保"无遗漏"读取全部源文件
2. **锚定交叉验证缺失**：`record-finding.py` 接受 file+line 但不校验是否在 index.json 中存在

## Changes

| # | Task | File | Change |
|---|------|------|--------|
| 12 | TASK-012 | commands/secguard.md Step 2.5b | 预筛从 advisory 改为 mandatory first-pass filter |
| 13 | TASK-013 | scripts/record-finding.py | 增加 --index-json 锚定校验 |
| 14 | TASK-014 | skills (5 files) + commands | 强制 index 驱动读取，禁止全文件读取 |
| 15 | TASK-015 | Verification | deploy + self-check |
