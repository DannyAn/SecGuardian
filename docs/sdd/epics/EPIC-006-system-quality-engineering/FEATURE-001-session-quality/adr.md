# ADR-001: 会话质量增强 — 关键架构决策

> **Feature**: FEATURE-001-session-quality
> **日期**: 2026-07-06

## ADR-001.1: record-finding.py `--from-stdin` 接受独立 JSON

**状态**: 采纳

**决策**: `--from-stdin` 不再要求任何 CLI 参数。stdin 的 JSON 必须包含所有必需字段。
`--from-stdin` 内部重构：将 JSON 解析放在 CLI 参数解析之前，如果 stdin 提供了完整 finding，
则 CLI 参数完全可略。

**否决方案**: 提供"简化模式 CLI + stdin 互补"——加剧认知负担，Agent 仍会踩坑。

## ADR-001.2: argparse 配置 `parse_known_args() → AD: reject unknown`

**状态**: 采纳

**决策**: Python argparse 配置 `parse_known_args()` 自定义 error handler，在检测到未知参数时
立即 `sys.exit(1)` 并列出所有未知参数名。

**否决方案**: per-argument 白名单校验——维护成本高，且 Agent 参数名在 prompt 中动态生成。

## ADR-001.3: 索引器 timeout 用 shell `timeout` 命令

**状态**: 采纳

**决策**: 在命令模板中将 `$SECGUARDIAN_HOME/scripts/bin/secguardian-index` 调用包装为
`timeout 30s $SECGUARDIAN_HOME/scripts/bin/secguardian-index`。
超时时给用户明确的提示信息（非静默失败）。

**否决方案**: 在 Go 二进制内实现 timeout——修改编译产物，影响 cross-compile 简化。

## ADR-001.4: 相对路径策略

**状态**: 采纳

**决策**: 所有命令模板的第一条 bash 指令必须是 `cd "$USER_PROJECT"`。
此后，.scan_state 路径使用相对路径 `.codeagent/secguardian/.scan_state.secguard`，
finding 文件路径使用相对路径。只有 `$SECGUARDIAN_HOME` 引用使用全路径（不可避免）。

**理由**: 全路径在 permission system 中触发逐项确权。从用户项目目录内操作大幅减少弹窗。

## ADR-001.5: 验证不可跳过标记

**状态**: 采纳

**决策**: 在命令模板的验证步骤前插入标记行 `<!-- @secguardian:non-skippable step=validate -->`。
该标记在 `scripts/self-check.sh` 增加的正则检查中验证未遭移除。

**否决方案**: 在 go-indexer 层强制验证——引入不必要的编译依赖。
