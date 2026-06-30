# Audit Framework

> SecAudit 的架构基座。将安全审计从"18 个 AI Skill"升级为"可插拔 Rule Pack + 标准映射 + 报告管线"。

## 设计理念

```
                    Rule Pack
                        |
                        v
     ┌──────────────────────────────────┐
     |          Engine                  |
     |  (AI Agent 或独立 Runtime)       |
     └──────────────────────────────────┘
                        |
          ┌─────────────┼─────────────┐
          v             v             v
    templates/     reporters/     findings/
    (报告模板)     (输出格式)     (审计结果)
```

## Rule Pack = Rules + Workflow

一个 Rule Pack 由两部分组成：

1. **Rules** — 审计规则文件（定义检查什么）
2. **Workflow** — 执行引擎定义（定义按什么顺序执行、怎么做后处理）

默认 `secguardian` pack 复用 `skills/secaudit/workflow-secaudit/SKILL.md` 作为其 17 phase 流水线引擎。未来的自定义 rule pack 可以在 pack 内自带 `workflow.md`。

## 目录结构

```
audit-framework/
├── README.md              ← 本文
├── rulepacks/             ← 可插拔规则包
│   ├── README.md          ← 如何编写 Rule Pack
│   └── secguardian/       ← 内置默认 Rule Pack
│       ├── pack.json      ← 清单 + 标准映射
│       └── rules/         ← 17 个审计规则文件
├── engine/                ← 执行引擎规范
│   └── README.md
├── templates/             ← 报告模板规范
│   └── README.md
└── reporters/             ← 输出格式扩展点
    └── README.md
```

## 使用方法

```bash
# 使用默认内置 Rule Pack
/secaudit taint-analysis ./src python

# 指定 Rule Pack 运行
/secaudit --rulepack secguardian ./src python

# 未来：使用企业安全基线
/secaudit --rulepack company-redline-v3 ./src java
```
