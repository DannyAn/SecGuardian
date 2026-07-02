# Architecture — 模块职责与数据流

> SecAudit 的架构由四个独立模块构成，各模块职责完全分离。

## 四模块职责

```
┌──────────────────────────────────────────────────────────────┐
│                      commands/                               │
│              用户入口（Entry Point）                           │
│   CLI 定义 · 参数解析 · 用户交互 · 路由到对应 Workflow        │
│   永远不知道安全规则是什么                                     │
└────────────────────────┬─────────────────────────────────────┘
                         │ Dispatch
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                       skills/                                │
│                AI Workflow（AI 如何思考）                      │
│   Prompt · Workflow · AI 调度 · Context Gathering · 推理流程  │
│   消费 Knowledge，不拥有 Knowledge                             │
└────────────────────────┬─────────────────────────────────────┘
                         │ Load Context & Rules
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                      knowledge/                               │
│             Security Knowledge Repository                     │
│   规则 · 标准 · 协议 · 威胁目录 · 语言画像                    │
│   唯一知识源（Single Source of Truth）                         │
└────────────────────────┬─────────────────────────────────────┘
                         │ Define Framework
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                   docs/audit-framework/                            │
│            Audit Execution Framework                          │
│   架构 · 工作流 · 证据模型 · 报告模式                         │
│   不拥有任何安全知识                                           │
└──────────────────────────────────────────────────────────────┘
```

## 数据流

一次完整的 `secaudit` 执行过程：

```
User 输入 /secaudit ./src python
        │
        ▼
commands/secaudit.md 解析参数
        │
        ▼
skills/secaudit/workflow-secaudit/SKILL.md 启动工作流
        │
        ├── 加载 knowledge/audit-rules/*.md（规则定义）
        │
        ├── 收集项目上下文（index.json + 源码结构）
        │
        ├── 按规则收集证据
        │
        └── AI 推理 → 生成 findings → 输出报告
```

## 关键约束

| 约束 | 说明 |
|------|------|
| 规则唯一性 | 所有安全规则只存在于 `knowledge/`，不可在别处复制 |
| 框架无规则 | `docs/audit-framework/` 不包含任何 `.md` 规则文件 |
| Skill 无知识 | `skills/secaudit/*/SKILL.md` 引用 knowledge，不内嵌规则 |
| Command 无逻辑 | `commands/secaudit.md` 只做入口路由，不确定规则内容 |

## 未来演进方向

- `knowledge/` 可扩展：OWASP ASVS、PCI DSS、CIS Benchmark、NIST SSDF 独立子目录
- 新增企业规范只需增加 `knowledge/` 内容，不修改框架
- 框架可抽象为独立 Runtime（脱离 AI Agent 执行），本次不做
