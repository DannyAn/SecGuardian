# TASK-006: E2E 验证更新

## Goal

在 e2e-verify.sh 中新增 Section 12 验证项。

## Done

- [ ] Section 12.1 验证 human/executive-summary.md 存在且有发现分布表
- [ ] Section 12.2 验证 ai/remediation-pack.json 存在且每条含 related_findings
- [ ] Section 12.3 验证 report.html 存在且为有效 HTML
- [ ] Section 12.4 验证 report.md 不含管理层内容（精简确认）

## Files

- scripts/e2e-verify.sh

## Verification

```bash
bash scripts/e2e-verify.sh | grep "Section 12"
```
