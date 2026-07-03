# Manifest-Driven Tokens — 进度追踪

> **Feature**: FEATURE-001-manifest-driven-tokens
> **最后更新**: 2026-06-07

## 状态: ✅ 已完成

## 完成清单

- [x] `scripts/sync-manifest.sh` 核心同步脚本
- [x] Token 标记格式 `NNN<!-- @secguardian:token_name -->`
- [x] manifest.json → token 自动传播
- [x] `--check` CI 模式（非零退出码）
- [x] 12 个文件 Token 化
- [x] `scripts/render-report.py` DETECTOR_RULE_INDEX 动态加载
- [x] `package.sh` 集成 sync-manifest.sh
- [x] `self-check.sh` §7.6 集成 `--check` 模式
- [x] 验证：修改 manifest.json count → 所有文件自动更新

## 关键里程碑

| 日期 | 事项 |
|------|------|
| 2026-06-07 | 设计与实现完成 |
| 2026-06-07 | 集成到构建 + CI 流程 |

## 影响范围

Token 化文件：12 个（threat-catalog.md, extension.json x3, commands x3, language-index.md x5, CLAUDE.md/AGENTS.md/GEMINI.md, interview-ppt.md, competitive-analysis.md）
