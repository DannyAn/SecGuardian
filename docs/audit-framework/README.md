# Audit Framework — Audit Execution Framework

> SecAudit 的执行框架定义。描述 **如何完成一次安全验收**，而不拥有任何安全知识。
>
> 所有安全规则和检测知识统一存放在 `knowledge/` 中，框架只负责编排。

## 定位

```
knowledge/  (Security Knowledge Repository — 唯一知识源)
    ▲
    │  Load Rules & Standards
docs/audit-framework/  (Audit Execution Framework — 如何审计)
    ▲
    │  Execute Workflow
skills/  (AI Workflow — AI 如何思考)
    ▲
    │  Dispatch
commands/  (Entry Point — 用户入口)
```

Audit Framework 不拥有任何安全规则、标准、引用。
它只定义四件事：

1. **架构**（Architecture）— 模块职责与数据流
2. **工作流**（Workflow）— 审计从开始到报告的全过程
3. **证据模型**（Evidence Model）— 证据收集与评估规范
4. **报告模式**（Report Schema）— 输出结构与 CI 门禁

## 目录结构

```
docs/audit-framework/
├── README.md               ← 本文
├── architecture.md          ← 架构概览与组件关系
├── workflow.md              ← 审计工作流（从收集上下文到发布决策）
├── evidence.md              ← 证据收集模型与质量要求
├── report-schema.md         ← 报告模式与 CI 门禁规范
├── engine/README.md         ← 执行引擎规范
├── templates/README.md      ← 报告模板设计
└── reporters/README.md      ← 输出格式扩展点
```

## 设计原则

| 原则 | 含义 |
|------|------|
| **Framework 不拥有 Rule** | 审计框架只描述"如何审计"，不保存"审计什么" |
| **Knowledge 是唯一知识源** | 所有安全规则只存在于 `knowledge/`，任何地方不复制 |
| **Workflow 不维护知识** | 工作流消费规则，但规则由 Knowledge 目录管理 |
| **Commands 不关心规则** | CLI 命令只做参数解析和入口调度，不过问安全规则 |

## 知识消费关系

```
docs/audit-framework 定义审计流程
        │
        ▼ 读取 framework 定义
skills/secaudit/SKILL.md 加载工作流
        │
        ▼ 按工作流加载规则
knowledge/audit-rules/*.md  提供规则内容
        │
        ▼ AI 推理
AI Agent 执行检测
        │
        ▼ 输出
findings → report / sarif / summary
```

## 与知识目录的关系

| 方向 | 内容 |
|------|------|
| `docs/audit-framework/` → `knowledge/` | 消费规则（读，不写） |
| `knowledge/` → `docs/audit-framework/` | 不受框架影响，可被三个命令共同复用 |
| 重复 | 禁止——规则只存在于 `knowledge/`，`docs/audit-framework/` 中无规则副本 |

## 变更历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.2 | 2026-07-02 | 架构职责收敛：移除 rulepacks/，规则回归 knowledge/ 唯一源 |
| v0.1 | 2026-06-30 | FEATURE-008 MVP：创建 audit-framework/ 初始骨架 |
