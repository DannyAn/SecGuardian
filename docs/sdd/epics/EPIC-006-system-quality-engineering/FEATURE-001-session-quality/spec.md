# FEATURE-001: 会话质量与稳定性增强

> **Epic**: EPIC-006-system-quality-engineering
> **状态**: Spec 完成

## 问题陈述

2026-07-06 对 `examples/go-vuln-demo` 在 OpenCode 上执行 `/secguard` → `/secreview` → `/secaudit` 三个命令后，
实测日志分析（8915 行，56 轮，79 工具调用）暴露 9 项系统性缺陷：

| 类别 | 缺陷 | 严重度 | 实测影响 |
|------|------|--------|---------|
| Token 效率 | todowrite 序列化冗余 | P0 | 每会话 ~50KB 无效 token |
| Token 效率 | record-finding 转义开销 | P0 | 每 finding 多 ~2KB 转义 |
| Token 效率 | $RECORDER 硬编码 | P2 | 路径变动全断 |
| 正确性 | argparse 静默接受未知参数 | P1 | --attack-scannerio typo 费 3 轮 |
| 正确性 | --from-stdin 设计缺陷 | P0 | 首次使用必踩坑 |
| 稳定性 | 索引器无 timeout | P0 | 大项目可能永久挂死 |
| 可靠性 | Step 3.5 可被 Agent 跳过 | P1 | 安全性视 Agent 心情 |
| 可用性 | 全路径操作频繁确权弹窗 | P0 | 中断自动化流程 |
| 可维护性 | 错误未区分可重试/不可重试 | P2 | 故障响应不精确 |

## 设计目标

1. **Token 效率**: 每会话无效 token ≤5KB（当前 ~50KB），降低 90%
2. **正确性护栏**: 参数拼写错误、脚本调用失败在 1 轮内检测并报告
3. **超时保护**: 任何外部命令调用在 30s 后自动超时，不得永久阻塞
4. **验证不可绕过**: 安全性验证步骤集成到协议层，无法被 Agent 跳过
5. **无确权弹窗**: 扫描流程中不因路径问题触发 permission prompt

## 需求规格

### REQ-001: record-finding.py --from-stdin 接受完整 JSON
`--from-stdin` 模式不应再要求任何 CLI 参数。stdin 输入的 JSON 应包含所有必需字段。

### REQ-002: argparse 拒绝未知参数
`record-finding.py --attack-scannerio "x"` → 立即报错退出，不静默忽略。

### REQ-003: 索引器 timeout 包装
`scripts/secguardian-index` 调用自动施加 30s 超时。超时时 fallback 告知用户。

### REQ-004: 命令模板 Step 3.5 不可跳过
验证步骤嵌入协议层前置条件，Agent 无法自主跳过。

### REQ-005: 相对路径优先策略
项目内文件操作使用相对于 `$USER_PROJECT` 的路径。`cd "$USER_PROJECT"` 后再执行。

### REQ-006: 自动化验证
每个 record-finding 调用后 grep `RECORDED` 确认写入成功，否则立即重试或报错。

### REQ-007: todowrite 替换
命令模板和 SKILL.md 中指示 Agent 使用原生 task 系统替代 todowrite。

## 不做什么

- 不引入新的数据格式或 schema 版本
- 不修改 findings-schema.json 的结构
- 不降低现有的安全评分逻辑
