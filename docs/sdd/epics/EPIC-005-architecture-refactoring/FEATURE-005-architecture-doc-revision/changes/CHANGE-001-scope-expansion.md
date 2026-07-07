# CHANGE-001: Scope Expansion — Anchor/Evidence Constraint Injection

> **Feature**: FEATURE-005 Architecture Document Revision
> **Date**: 2026-07-05
> **Trigger**: OpenCode 扫描实测发现架构文档修正后，commands/skills 未落地约束
> **Severity**: Critical — 设计-行为鸿沟

## Reason

FEATURE-005 TASK-001~007 修正了 6 份架构文档，确立了"信号-LLM 协作"模型。
但 OpenCode 实测扫描（go-vuln-demo, 28 findings）暴露了三个问题：

1. **锚定约束未执行** — LLM 发现漏洞后未交叉验证 finding 的 file+line 是否对应 index 符号
2. **证据约束是模板填充** — 112 个验证错误，LLM 被迫用 Python 脚本批量补字段
3. **预筛被安全阀抵消** — "即使无匹配也执行"导致所有文件仍被全量读取

这些不是新 Feature，而是 FEATURE-005 的自然延续——架构文档改了，
prompt 指令也必须同步修改，否则设计只是纸面文章。

## Impact

| 维度 | Before (TASK-001~007) | After (TASK-001~010) |
|------|----------------------|---------------------|
| 架构文档 | 6 份修正 | 不变 |
| commands/skills | 未修改 | 注入锚定+证据+预筛收紧指令 |
| record-finding.py | 未修改 | --snippet/--code-context/--rationale 改为必填 |
| 行为变化 | 无 | LLM 在录制 finding 前必须校验锚定+证据 |

## 新增 TASK

| # | Task | 改动 |
|---|------|------|
| 8 | TASK-008: commands/secguard.md 注入锚定+预筛收紧 | Step 2.5b + Step 4 |
| 9 | TASK-009: skills 注入锚定约束 | 5 个 secguard skill 文件 |
| 10 | TASK-010: record-finding.py 必填参数 | --snippet/--code-context/--rationale required |

## Migration

- 不需要数据迁移
- deploy.sh all 后重启 AI Agent 即生效
