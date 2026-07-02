# Templates

> 审计报告的模板系统。定义"审计报告长什么样子"。

## 目录规范

```
templates/<name>/
├── executive-summary.md.tpl    ← 执行摘要模板
├── finding.md.tpl              ← 单个发现模板
├── audit-report.md.tpl         ← 完整审计报告模板
└── config.yaml                 ← 模板配置
```

## 内置模板

| 模板 | 说明 | 状态 |
|------|------|------|
| `default` | Markdown 审计报告 | ✅ MVP |
| `executive` | 管理层摘要 | ⬜ 待实现 |
| `pdf` | PDF 报告 | ⬜ 待实现 |

## 模板变量

```
{{ findings_count }}        — 发现总数
{{ critical_count }}        — Critical 数
{{ high_count }}            — High 数
{{ medium_count }}          — Medium 数
{{ scan_id }}               — 扫描 ID
{{ command_type }}          — 命令类型（secguard/secaudit/secreview）
{{ findings }}              — 所有发现的列表
{{ duration_ms }}           — 执行耗时
```
