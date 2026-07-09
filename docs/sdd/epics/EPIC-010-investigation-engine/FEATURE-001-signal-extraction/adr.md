# FEATURE-001 — Architecture Decision Records

---

## ADR-001: Signal Type 取代 Category — 操作描述而非漏洞预判

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

Signal 的 `type` 字段只描述操作类型（`memory_allocation`、`memory_copy`、`string_copy`、`user_input`、`lock_operation`），不描述漏洞类型（不再有 `buffer_overflow`、`null_dereference` 等 category）。

### Reason

1. **Guide §4 强制要求**：Dispatcher 禁止判断漏洞类型，Signal 不等于 Conclusion。`category: "memory"` 同时覆盖 malloc（分配）和 memcpy（拷贝），对 Investigator 没有信息量。

2. **跨 Skill 推理的前提**：一个 Signal 可以被多个 Hypothesis 使用。`malloc` 可以是 null_dereference，也可以是 double_free 或 memory_leak 的调查起点。如果 category 锁死为 `memory` 或 `null_dereference`，其他 Hypothesis 会认为"这个 signal 不是我管的"。

3. **Signal 数量分类更实用**：操作类型直接对应真实问题——`memory_copy` 有 312 个信号，`user_input` 有 23 个。这个分布告诉 Investigator 哪里工作量大，而不是告诉"你该查 buffer overflow"。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 保留 category 但改为语义层次（写操作/读操作/控制流操作） | 对 Investigator 无实质帮助——写操作太宽泛，仍然需要 Investigator 自己去发现"写的什么" |
| 不加 type，直接原始 callee 名 | Investigator 需要分类来理解工作负载。312 个 memory_copy 和 23 个 user_input 帮助其规划调查顺序 |
| category 改为预设假设列表（如 `malloc` → [null_deref, double_free, leak]） | 把 Hypothesis Generator 的工作提前到 Dispatcher 做了，违反职责分离 |

### Consequences

- Signal schema 不再包含 `category` 和 `safe_variant` 字段
- `type` 必须是枚举值之一（memory_allocation/memory_copy/string_copy/user_input/lock_operation/exec_operation/memory_deallocation/resource_acquire）
- Investigator 不再按 category 选择分析路径——自己从 type + callee 决定调查方向

---

## ADR-002: Dispatcher 是 Prompt 重构，不涉及 Go 代码

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

Dispatcher 重构只修改 commands/ 下的 Markdown 文件（secguard.md/secaudit.md/secreview.md），不涉及 internal/ 下的 Go 代码。

### Reason

1. **成本收益比**：Go 索引器已经提供了所有需要的原始数据（call_sites, symbols, call_graph, alloc_free, lock_graph），只需要修改 LLM 对这些数据的消费方式。改 Go 代码的成本高、收益低。

2. **EPIC-009 的产出复用**：预筛器（prescreener.go）的 `prescreen_verdict` 字段已经在 Go 层添加。Dispatcher 在 Prompt 层读取这个字段并传给 Hypothesis Generator，不需要额外的 Go 代码。

3. **Prompt 是执行引擎**：当前架构中，LLM Prompt 就是执行引擎。Dispatcher 重构本质上是对 LLM 的"行为约束"——告诉它不要做什么，而不是重新实现什么逻辑。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 在 Go 索引器中新增 Signal 分类逻辑 | 分类逻辑很简单（knownLibFuncs 映射到 type），Go 端已有分类框架。Signal 上下文人需要读源码文本，这是 Prompt 层的自然能力。 |
| 新的 Signal Extraction 二进制 | 过度设计。index.json 已有全部原始数据，Dispatcher 负责消费它。 |

### Consequences

- 改动范围限于 `commands/` 下的 9 个 Markdown 文件（3 命令 × 3 平台）
- 需要确保三平台的 `command/*.md` 行为一致
- 后续 Investigation Pipeline（Hypothesis Generator / Investigator / Judge）也是 Prompt 重构

---

## ADR-003: 上下文内联 — Signal 自带源码片段

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

每个 Signal 的 `context` 字段包含 ±3 行源码上下文，以及关联函数名和行号。Investigator 不需要额外读源码文件。

### Reason

1. **一次 I/O 完成**：Dispatcher 在读取 index.json 后、生成 Signal 列表前，已经持有了所有信号的行号。可以一次性从源码中读取上下文，而不是在每个 Investigator 调查时单独读。

2. **减少调查阻力**：如果 Investigator 每次需要读源码都要发一个 shell command（~1-3s I/O 延迟），对调查的积极性是负面激励。上下文人内联后，Investigator 可以快速判断"这行是否需要深究"。

3. **上下文足够做初次判断**：±3 行 + 函数名通常可以看到"这个调用有没有 NULL 检查"、"参数是不是来自用户输入"。如果需要更深层的追踪（跨函数），Investigator 可以自主请求更多源码（Guide §7 允许）。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 不包含上下文，Investigator 自己读文件 | 每个 Signal 多 1-3 次 I/O，150 个 Signal 多 150-450 次 I/O |
| 包含整函数全文 | JSON 体积膨胀不可控（函数可能数百行） |

### Consequences

- index.json 消费后、Signal 输出前，需要一个源码读取步骤
- 上下文长度限制为 ±3 行（约 300 bytes/signal），150 个 Signal 约 45KB
- 如果函数跨越了 Signal 的 ±3 行范围，Investigator 自主请求更多源码

---

## ADR-004: 三命令统一 Signal 格式

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

secguard/secaudit/secreview 使用完全相同的 Signal 结构和输出格式。差异只体现在后续 Investigation Pipeline 的配置上。

### Reason

1. **AC-07（三命令共享信号层）**：这是 EPIC-009 已经确立的架构约束。三命令共用同一索引器输出（S1-S7 信号矩阵），差异只在各命令如何消费这些信号。

2. **降低维护成本**：如果每个命令有各自的 Signal 格式，修改 Signal schema 时需要同步 3 份文档。统一后只需修改 1 处。

3. **Sigma Pipeline 可复用**：Hypothesis Generator、Investigator、Judge 的 Prompt 模板可以在三命令间复用，只是配置参数不同（如 secaudit 的 Hypothesis 深度更高、secreview 聚焦 PR 变更）。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| secaudit 使用独立 Signal 格式（更细粒度） | 信号层是共享的，差异应该在 Pipeline 层（FEATURE-003）。Signal 统一减少了系统复杂度 |
| secreview 使用简化 Signal（只包含变更行） | 简化 Signal 丢失了跨函数上下文。secreview 仍然需要完整调用链。PR 变更范围的筛选在 Pipeline 层完成 |

### Consequences

- 三命令的 Phase 1-3（前置检查→索引→信号提取）在 Prompt 层面合并为可复用的描述
- Phase 4-6 的变化通过配置参数控制
- Signal schema 作为协议文档，在 `knowledge/protocols/` 中维护单一版本
