# TASK-002: 12 个文件 Token 化

> **Feature**: FEATURE-001-manifest-driven-tokens
> **状态**: ✅ Done
> **完成日期**: 2026-06-07
> **原则**: Task 驱动编码

## Goal

在 12 个文件中将所有硬编码数字替换为 `NNN<!-- @secguardian:token_name -->` 标记。

## Done

### 必须 Token 化（运行时被 AI Agent/用户读取）

- [x] `knowledge/threat-catalog.md` — 8 处 namespace 计数 + 前端 description
- [x] `extensions/secguard-secguardian/extension.json` — description 字段
- [x] `extensions/secaudit-secguardian/extension.json` — description 字段
- [x] `extensions/secreview-secguardian/extension.json` — description 字段
- [x] `commands/secguard.md` — frontmatter description
- [x] `skills/secguard/*/references/language-index.md` (5 files) — "全部 N 个检测器"
- [x] `CLAUDE.md` — detector 数量提及
- [x] `AGENTS.md` — detector 数量提及
- [x] `GEMINI.md` — detector 数量提及

### 建议 Token 化（对外展示材料）

- [x] `docs/reference/interview-ppt.md` — 多处 "67 检测器"
- [x] `docs/competitive-analysis.md` — "67 active detectors"

### 不需要 Token 化

- [x] `scripts/render-report.py` — 改为从 manifest.json 动态加载 DETECTOR_RULE_INDEX（见 TASK-003）

## Verification

```bash
# 替换后立即验证一致性
bash scripts/sync-manifest.sh --check
# Expected: exit 0

# 抽查几个文件的 token
grep "@secguardian:detector_count" knowledge/threat-catalog.md
grep "@secguardian:detector_count" CLAUDE.md
grep "@secguardian:namespace:web" knowledge/threat-catalog.md
```

## Files Changed

| 文件 | Token 数量 |
|------|-----------|
| `knowledge/threat-catalog.md` | 9 |
| `extensions/*/extension.json` (3 files) | 3 |
| `commands/secguard.md` | 1 |
| `skills/*/references/language-index.md` (5 files) | 5 |
| `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | 3 |
| `docs/reference/interview-ppt.md` | 8 |
| `docs/competitive-analysis.md` | 2 |
| **总计** | **31 tokens** |
