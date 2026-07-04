# TASK-005: record-finding.py — AI 数据非格式化辅助工具

> **Feature**: FEATURE-001-output-protocol
> **状态**: ✅ Done
> **完成日期**: 2026-07-04
> **原则**: AI 做语义分析，Python 做格式校验 — 遵循 ADR 设计分工

## Goal

创建 `scripts/record-finding.py`，让 AI 能通过命令行参数记录 finding，
不需要手动写 JSON、算 SHA、建目录。消除 AI 走捷径写 `/tmp/gen_findings.py` 的动机。

## Done

- [x] `scripts/record-finding.py` — 参数化记录单个 finding
  - [x] 接受 --scan-dir / --detector / --severity / --cwe / --file / --line 等参数
  - [x] 自动计算 SHA-256 finding ID
  - [x] 自动创建 `findings/<ns>/<detector>/` 目录
  - [x] 输出符合 findings-schema.json 的 JSON 文件
- [x] `commands/secguard.md` Step 4 — 更新为调用 record-finding.py
- [x] 验证：5 种语言测试通过
