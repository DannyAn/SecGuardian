# SecGuardian SDD — Spec-Driven Development

> 核心原则只有一句：
>
> **🧠 Brainstorm 决定方向 → 📋 Spec 定义需求 → 📝 ADR 记录决策 → 📐 Plan 拆解实现 → 🔨 Task 驱动编码 → 📊 Progress 保持上下文 → 🔄 Change 管理演进**
>
> 每一环对应一个具体文件。不缺不滥，各司其职。

---

## 一、为什么不是文档类型视角

传统做法按文档类型分目录——`specs/`、`plans/`、`tasks/`。小项目（<10 需求）时简便，项目大了必然出现：

```
SPEC-001 ... SPEC-020
PLAN-001 ... PLAN-020
TASK-001 ... TASK-120
```

查找"认证功能到底有哪些文档"需要跨 3 个目录搜索。需求越多，维护成本指数增长。

**Feature Package 模式下**，每个 Feature 自成一个完整闭环：

```
FEATURE-001-jwt-auth/
├── spec.md        # 需求规格
├── adr.md         # 架构决策
├── plan.md        # 实施计划
├── progress.md    # 进度追踪
├── tasks/         # 任务拆分
└── changes/       # 变更记录
```

当 AI Agent 开发 JWT 功能时，只需加载这一个目录，即可获得全部上下文。不需要扫描整个 `docs/`。

---

## 二、七原则详解

### 🧠 Brainstorm — 决定方向

| 属性 | 说明 |
|------|------|
| **载体** | `docs/sdd/brainstorm-log.md` |
| **时机** | 产生想法 → 方案讨论 → 确定方向 |
| **作者** | 人 + AI 对话 |
| **读者** | 未来的自己和团队成员（"当时为什么选这个方案？"） |

Brainstorm 是七原则的起点。它不追求格式规范，追求的是**完整记录思考过程**：背景是什么、考虑过哪些方案、否决了哪些、为什么选这个、影响范围多大。

一个好的 Brainstorm 条目包含：
- **背景** — 为什么要做这个决定
- **讨论要点** — 考虑过哪些方案，各自的优劣
- **最终方案** — 选了哪个，为什么
- **影响范围** — 哪些文件/模块会受影响

> Brainstorm 不是正式文档。正式决策在 ADR 中记录。Brainstorm 的价值在于保留那些被否决的方案和否决原因——这些东西 ADR 里通常只写一行 "Rejected"。

---

### 📋 Spec — 定义需求

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/spec.md` |
| **时机** | Brainstorm 确定方向后 |
| **作者** | 人（定义 What），AI 辅助补充 |
| **读者** | 实施者（人 + AI Agent） |

Spec 回答 **WHAT**——要做什么、为什么做、做到什么程度。

一个好的 Spec 包含：
- **问题陈述** — 当前痛点，用数据说话
- **设计目标** — 可度量的成功标准
- **需求规格** — REQ-001, REQ-002... 每条可验证
- **设计方案** — 核心思路、关键数据结构、流程变更
- **风险与约束** — 已知限制、不做什么

Spec 是 Feature 的"真理源"。后续所有文档——ADR、Plan、Task、Change——都以 Spec 为基准。

> 原则：Spec 写完要让一个没参与 Brainstorm 的人能看懂"要做什么"和"为什么"。

---

### 📝 ADR — 记录决策

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/adr.md` |
| **时机** | Spec 完成后、Plan 开始前 |
| **作者** | 人（决策者） |
| **读者** | 未来接手的人（"这个设计为什么长这样？"） |

ADR（Architecture Decision Record）记录 SPEC 中隐含的架构决策。一个 Feature 可以有多个 ADR——每个关键技术选择一条。

ADR 格式：
```markdown
## ADR-001: 决策标题

**日期**: YYYY-MM-DD
**状态**: ✅ Accepted / ❌ Superseded

### Decision
（一句话说清选了什么）

### Reason
（为什么选这个，至少两条理由）

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| ... | ... |

### Consequences
（这个决策带来了什么影响——好的和不好的都要写）
```

> 原则：ADR 的价值在 "Rejected Alternatives"——知道什么路不走，比知道走哪条路更有长期价值。

---

### 📐 Plan — 拆解实现

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/plan.md` |
| **时机** | ADR 完成后 |
| **作者** | 人 + AI Agent |
| **读者** | AI Agent（执行者） |

Plan 回答 **HOW**——怎么实现、分几步、改哪些文件。

一个好的 Plan 包含：
- **Goal** — 一句话目标
- **Architecture** — 技术选型 + 组件关系
- **File Structure** — 改哪些文件，每个文件的改动量
- **Tasks** — 按执行顺序排列的 checkbox 列表，每个 Task 对应一次可验证的代码变更
- **Verification** — 每个 Task 完成后的验证命令

> 原则：Plan 是写给 AI Agent 的执行指令。Task 粒度要细到"一个 Task 一次 commit"，验证命令要可复制粘贴。

---

### 🔨 Task — 驱动编码

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/tasks/TASK-NNN-description.md` |
| **时机** | Plan 中每个 checkbox 对应一个 Task |
| **作者** | 人拆分，AI Agent 执行 |
| **读者** | AI Agent（编码时加载） |

Task 是 Plan 的细化。复杂的 Task 可以拆出独立文件，记录详细的实施步骤、代码示例、验证方法。

一个好的 Task 包含：
- **Goal** — 这个 Task 完成后产出了什么
- **Done** — checkbox 完成清单
- **Files Changed** — 改动文件 + 改动量
- **Verification** — 可执行的验证命令

> 原则：每个 Task 完成后应该可以独立 commit。如果两个 Task 必须一起 commit，它们应该是同一个 Task。

---

### 📊 Progress — 保持上下文

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/progress.md` |
| **时机** | 持续更新（每个 Task 完成后） |
| **作者** | 人 + AI Agent |
| **读者** | 人（"这个 Feature 做到哪了？"） |

Progress 是 Feature 的实时状态面板。它不重复 Plan 的内容，只追踪**进度**。

一个好的 Progress 包含：
- **状态** — `✅ 已完成` / `🔄 进行中` / `⬜ 未开始`
- **完成清单** — 从 Plan 中复制的 Task 列表，标记完成状态
- **关键里程碑** — 日期 + 事项
- **阻塞项** — 当前被什么阻塞

> 原则：Progress 是给中断后回来的人看的。离开一周后，打开 progress.md 应该能在 30 秒内知道"做到哪了、下一步做什么"。

---

### 🔄 Change — 管理演进

| 属性 | 说明 |
|------|------|
| **载体** | `FEATURE-XXX/changes/CHANGE-NNN-description.md` |
| **时机** | Spec 发生实质性变更时 |
| **作者** | 人 |
| **读者** | 所有关注这个 Feature 的人 |

Change 记录需求的演进。不是每个小改动都需要 Change 记录——只有当需求**实质性变化**（新增/删除 REQ、架构方案推倒重来）时才记录。

一个好的 Change 包含：
- **Reason** — 为什么变（外部反馈？技术发现？）
- **Impact** — 变更前后对比表
- **新增/修改/废弃的需求** — 引用 SPEC 中的 REQ 编号
- **Migration** — 如何从旧方案迁移到新方案

> 原则：Change 回答的是"这个 Feature 为什么和最初设计的不一样"。如果一个 Feature 没有任何 Change 记录，要么是设计完美，要么是需求根本没被 challenge 过。

---

## 三、Feature 生命周期

一个 Feature 从 idea 到交付，按顺序走过七环：

```
🧠 Brainstorm        人+AI 讨论，产出 brainstorm-log 条目
        │
        ▼
📋 Spec              人写需求，AI 辅助补充细节
        │
        ▼
📝 ADR               人写架构决策，每条一个 ADR
        │
        ▼
📐 Plan              人+AI 拆解成 Task 列表
        │
        ▼
┌───────────────────────────────────┐
│  🔨 Task → 编码 → 验证 → commit    │  循环（AI Agent 逐 Task 执行）
│  📊 Progress → 更新进度            │
│  🔄 Change → 有变更时追加           │
└───────────────────────────────────┘
        │
        ▼
✅ Feature 完成 → Progress 标记 Done
```

关键规则：
- **七环顺序不可跳过**。不能没有 Spec 就写 Plan，不能没有 ADR 就开始编码。
- **Brainstorm 是唯一可以省略文件载体的一环**——小决策直接在对话中完成，大决策才记入 brainstorm-log。
- **Change 随时可能触发**——当 Spec 发生实质性变化时，在继续编码前先写 Change。

---

## 四、给 AI Agent 的指引

### 当你被要求开发某个 Feature 时

1. **先读 Spec** — 理解 WHAT
2. **再读 ADR** — 理解关键决策
3. **然后读 Plan** — 理解 HOW，找到你的 Task
4. **Task 执行时** — 加载对应 `TASK-NNN.md`
5. **完成后** — 更新 `progress.md`

### 局部上下文原则

只需加载你需要的文件。不要扫描整个 `docs/sdd/`。

```
开发 FEATURE-001 的 TASK-003：
  ✅ 加载: FEATURE-001/tasks/TASK-003.md
  ✅ 加载: FEATURE-001/spec.md（理解上下文）
  ❌ 不加载: FEATURE-002/ 的所有文件
  ❌ 不加载: brainstorm-log.md
```

### Commit 粒度

一个 Task 一次 commit。Commit message 格式：
```
feat(feature-name): TASK-NNN — task description
```

---

## 五、层级结构

```
Epic → Feature → Task

EPIC-001-IAM/
├── epic.md                    # Epic 概述（目标、包含哪些 Feature、里程碑）
├── FEATURE-001-login/         # Feature = 独立闭环
├── FEATURE-002-jwt/
└── FEATURE-003-rbac/
```

| 层级 | 含义 | 持续时间 | 文件载体 |
|------|------|---------|---------|
| **Epic** | 跨多个 Feature 的大型目标 | 数周~数月 | `epic.md` |
| **Feature** | 可独立交付的用户价值单元 | 数天~数周 | `spec.md` + `adr.md` + `plan.md` + `progress.md` + `tasks/` + `changes/` |
| **Task** | 单一可执行的工作项 | 数小时~数天 | `tasks/TASK-NNN.md` |

---

## 六、SecGuardian Epics 全景

```
docs/sdd/
├── README.md                   # 本文件 — 方法论总纲
├── brainstorm-log.md           # 🧠 Brainstorm 决定方向
└── epics/
    ├── EPIC-001-core-scanning-engine/
    │   ├── epic.md
    │   ├── FEATURE-001-output-protocol/     # 输出协议 v2→v5 演进
    │   └── FEATURE-002-detector-quality/    # 67 检测器质量增强
    │
    └── EPIC-002-platform-engineering/
        ├── epic.md
        ├── FEATURE-001-manifest-driven-tokens/  # 散弹式修改终结者
        └── FEATURE-002-mcp-server/              # MCP 消费层
```

---

## 七、反模式

| 反模式 | 为什么不好 |
|--------|-----------|
| **跳过 Spec 直接写 Plan** | Plan 没有 What 锚定，必然偏离需求 |
| **ADR 只写 Decision 不写 Rejected** | 3 个月后没人知道为什么不用方案 B |
| **Plan 里的 Task 粒度太大** | "实现认证系统"不是一个 Task，是一次 Epic |
| **Progress 写成 Plan 的副本** | Progress 只追踪状态，不重复 Plan 内容 |
| **每个小改动都写 Change** | Change 过多会淹没真正重要的变更 |
| **AI Agent 扫描整个 sdd/** | 浪费 token，违反 Local Context 原则 |
| **Task 之间互相依赖但没有标注** | 后面的 Task 执行者不知道要等前面的完成 |

---

## 八、与其他目录的关系

| 目录 | 定位 | 是否属于 SDD |
|------|------|-------------|
| `docs/sdd/` | **SDD 方法论核心** — 七原则的完整载体 | ✅ |
| `docs/reference/` | 参考资料 — 白皮书、PPT、作品集、CI 指南 | ❌ |
| `docs/dogfood/` | 自扫描记录 — 运维 artifact | ❌ |
| `docs/templates/` | 文档模板 | ❌ |
| `docs/governance/` | 企业安全治理标准 — 独立体系 | ❌ |
| `docs/` 顶层 | 商业文档 — 竞品分析、商业化路线图 | ❌ |

---

## 九、参考来源

本方法论借鉴：
- **Claude Code Superpowers** 工作流 — Feature Package + Local Context 模型，长周期 AI Coding 项目的最佳实践
- **Jira / Linear / GitHub Projects** — Epic → Feature → Task 的三级拆分
- **MADR** (Markdown Architectural Decision Records) — ADR 的 Markdown 格式规范
- **ZEROFalse** (北大, 2025) — 证据门控推理对 Evidence Collection Guide 的启发
