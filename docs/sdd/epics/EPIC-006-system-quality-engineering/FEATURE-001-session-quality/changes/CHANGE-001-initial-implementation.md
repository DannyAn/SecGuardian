# CHANGE-001: 会话质量与稳定性增强 — 首次实施

> **Feature**: FEATURE-001-session-quality
> **日期**: 2026-07-06

## 变更描述

基于 OpenCode 实测日志（8915 行，56 轮，79 tool calls）分析，对 record-finding.py 和 3 个命令模板进行系统性增强。

## 修改清单

| 文件 | 变更 |
|------|------|
| `scripts/record-finding.py` | `--from-stdin` 接受完整独立 JSON；`parse_known_args` + 未知参数拒绝；标准化必填字段检查 |
| `commands/secguard.md` | timeout 30s 索引器保护；非跳过验证标记；todowrite→tasks 指引；\$\$RECORDER 固化；cd + 相对路径指引 |
| `commands/secaudit.md` | 同上 |
| `commands/secreview.md` | 同上 |
| `scripts/self-check.sh` | 新增 4 项（12f-12i）：非跳过标记、硬编码RECORDER、todowrite、timeout 30 |

## 向后兼容性验证

record-finding.py 三种使用模式均已确认正常：

| 模式 | 旧行为 | 新行为 | 兼容 |
|------|--------|--------|------|
| CLI-only `--detector x --severity y ...` | 正常 | 正常（同上） | ✅ |
| `--from-stdin` + CLI 参数 | 正常 | 正常（同上） | ✅ |
| `--from-stdin` 独立 JSON（无 CLI 参数） | ❌ argparse 报 "required" | ✅ 从 JSON 读取全部字段 | 🆕 |

**新增拒绝路径**：`--attack-scannerio`（typo）→ `exit 4`（之前 argparse 错误信息被 Agent 忽略，费时 3 轮才发现）。
