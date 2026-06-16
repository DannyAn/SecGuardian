# SecGuardian SDD — Spec-Driven Development

> SecGuardian 采用 **Feature Package + Local Context** 的 SDD 方法论，遵循七原则：
>
> 🧠 **Brainstorm** 决定方向 → 📋 **Spec** 定义需求 → 📝 **ADR** 记录决策 → 📐 **Plan** 拆解实现 → 🔨 **Task** 驱动编码 → 📊 **Progress** 保持上下文 → 🔄 **Change** 管理演进
>
> 核心理念：按需求（Feature）组织文档，而非按文档类型（specs/plans/tasks）平铺。

## 为什么用 Feature Package

传统"文档类型视角"（specs/、plans/、tasks/ 分目录）在小项目（<10 需求）时简便，但项目大了会出现：

```
SPEC-001 ... SPEC-020
PLAN-001 ... PLAN-020
TASK-001 ... TASK-120
```

查找"认证功能到底有哪些文档"需要跨 3 个目录搜索。

**Feature Package 模式**下，每个 Feature 自带全套文档：

```
FEATURE-001-jwt-auth/
├── spec.md        # 需求规格
├── plan.md        # 实施计划
├── progress.md    # 进度追踪
├── tasks/         # 任务拆分
└── changes/       # 变更记录
```

当 AI Agent 开发 JWT 功能时，只需加载 `FEATURE-001-jwt-auth/` 目录，即可获得全部上下文。

## 层级结构

```
Epic → Feature → Task

EPIC-001-IAM/
├── epic.md                    # Epic 级概述
├── FEATURE-001-login/         # Feature = 完整闭环
├── FEATURE-002-jwt/
└── FEATURE-003-rbac/
```

| 层级 | 含义 | 持续时间 |
|------|------|---------|
| **Epic** | 跨多个 Feature 的大型目标 | 数周~数月 |
| **Feature** | 可独立交付的用户价值单元 | 数天~数周 |
| **Task** | 单一可执行的工作项 | 数小时~数天 |

## SecGuardian Epics 全景

```
docs/sdd/
├── README.md                   # 本文件 — 方法论总纲
├── brainstorm-log.md           # 🧠 Brainstorm 决定方向 — 所有架构讨论的原始记录
└── epics/
    ├── EPIC-001-core-scanning-engine/    # 核心扫描引擎
    │   ├── FEATURE-001-output-protocol   # 输出协议演进 (v2→v5)
    │   └── FEATURE-002-detector-quality  # 检测器质量增强
    │
    └── EPIC-002-platform-engineering/    # 平台工程
        ├── FEATURE-001-manifest-driven-tokens  # Manifest 驱动令牌
        └── FEATURE-002-mcp-server              # MCP Server
```

## 文档约定

### spec.md
- **WHAT**: 问题陈述、设计目标、需求规格
- 含架构决策记录（ADR）
- 是 Feature 的"真理源"

### plan.md
- **HOW**: 实施步骤、任务拆分、文件改动清单
- 含 checkbox 任务列表，供 AI Agent 逐项执行
- 标注 Tech Stack 和 Architecture

### progress.md
- **WHERE**: 当前状态追踪
- 记录 completed / in_progress / blocked 任务
- 附完成日期和关键里程碑

### tasks/
- 复杂任务的独立详细说明
- 每个文件一个 Task

### changes/
- 需求变更记录
- 含变更原因、影响范围、回滚方案

## 与其他目录的关系

| 目录 | 定位 |
|------|------|
| `docs/sdd/` | **开发方法论核心** — 需求→设计→计划→进度 |
| `docs/reference/` | 参考资料（白皮书、PPT、作品集、CI 指南） |
| `docs/dogfood/` | 自扫描记录 |
| `docs/templates/` | 文档模板 |
| `docs/governance/` | 企业安全治理标准（独立体系） |
| `docs/` 顶层 | 商业文档（竞品分析、商业化路线图） |

## 参考

本方法论借鉴：
- Claude Code Superpowers 工作流（Feature Package + Local Context 模型）
- Jira / Linear / GitHub Projects 的 Epic→Feature→Task 层级
- Spec-Driven Development (SDD) 理念
