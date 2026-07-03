# TASK-001: Phase 1 — 命令层质量门禁

> **Feature**: FEATURE-001-output-protocol
> **状态**: ✅ Done
> **完成日期**: 2026-06-05
> **原则**: Task 驱动编码 — 每个 Task 对应一次可验证的代码变更

## Goal

在 3 个 command 文件中嵌入四段式质量检查清单，确保 AI Agent 每次输出都经过强制自检。

## Done

- [x] `commands/secguard.md` Step 4 追加质量检查清单（report.md + SARIF 双门禁）
- [x] `commands/secaudit.md` Step 4 追加质量检查清单
- [x] `commands/secreview.md` Step 4 追加质量检查清单
- [x] 未通过处理：任一 ❌ → 补充 → 重新检查，最多 3 次

## Verification

```bash
grep -c "质量门禁" commands/secguard.md    # Expected: >= 2
grep -c "质量门禁" commands/secaudit.md    # Expected: >= 2
grep -c "质量门禁" commands/secreview.md   # Expected: >= 2
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `commands/secguard.md` | Step 4 追加 report.md + SARIF 质量门禁 |
| `commands/secaudit.md` | Step 4 追加质量门禁 |
| `commands/secreview.md` | Step 4 追加质量门禁 |
