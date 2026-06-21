# TASK-004: Command 指令更新 — 目录树输出模式

> **Feature**: FEATURE-001-output-protocol (Phase 2 — v5.0)
> **状态**: ✅ Done
> **完成日期**: 2026-06-07
> **原则**: Task 驱动编码

## Goal

更新 3 个 command 文件，将 Step 4 从"单体 findings.json 输出"改为"逐 detector 分文件输出"。

## Done

- [x] `commands/secguard.md` Step 4 改造
  - [x] Step 4a: 按 detector 分组，逐文件 Write（每个 finding 2-4KB）
  - [x] Step 4b: 输出轻量 `findings.json`（纯索引，~8KB，不含四段式数据）
  - [x] Step 4c: 自检完整性（findings.json 条目数 = findings/ 目录下文件数）
  - [x] Step 4d: 调用渲染器（`--findings-dir` 模式）
- [x] `commands/secaudit.md` 同步更新
- [x] `commands/secreview.md` 同步更新

## Verification

```bash
# 端到端扫描验证
/secguard ./examples/python-vuln-demo
# → findings/ 目录树正常生成
# → findings.json 轻量索引正常生成
# → report.md / results.sarif 正常渲染
# → findings.json 条目数 = findings/ 下 .json 文件数
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `commands/secguard.md` | Step 4 改为逐文件输出模式 |
| `commands/secaudit.md` | 同步更新 |
| `commands/secreview.md` | 同步更新 |
