# SecGuard V2 Refactor Plan

目标：

将当前 Prompt-Orchestrated Security Scanner
重构为：

Shared Semantic Context + Lightweight Skill Execution Architecture

核心目标：

1. 减少重复代码理解
2. 减少 token 消耗
3. 减少多轮 reasoning
4. 提升大仓扫描速度
5. 保持当前 Findings 质量
6. 保持 Reflection 严格性
7. 保持现有 Persistence Protocol

--------------------------------------------------
PHASE 1 — Semantic Index Layer
--------------------------------------------------

新增：

internal/semantic/

实现：

1. repository indexer
2. symbol extractor
3. function catalog
4. allocator/free mapping
5. ownership hints
6. lock usage graph
7. CFG metadata
8. lightweight call graph

目标：

对 repo 仅扫描一次。

输出：

AnalysisContext

结构：

interface AnalysisContext {
    scan_id: string

    files: FileIndex[]

    functions: FunctionIndex[]

    symbols: SymbolIndex[]

    callgraph: CallGraph

    allocators: AllocatorMap

    ownership: OwnershipHints

    locks: LockGraph

    findings_cache: FindingsCache
}

要求：

- Dispatcher 生命周期内仅构建一次
- 所有 skills 共享
- skill 禁止重新遍历 repo
- skill 禁止重新构建 symbol graph

--------------------------------------------------
PHASE 2 — Skill Runtime Redesign
--------------------------------------------------

重构：

当前：

skill = reasoning agent

改为：

skill = lightweight rule evaluator

skill 输入：

SkillExecutionInput {
    analysis_context
    target_scope
    optional_focus
}

禁止：

- skill 自行读取整个 repo
- skill 自行做目录遍历
- skill 自行做架构理解

允许：

- 读取必要函数片段
- 读取必要局部 CFG
- 读取必要调用链

--------------------------------------------------
PHASE 3 — Skill Group Refactor
--------------------------------------------------

当前 skill 分类：
按漏洞类型分类

重构为：
按分析前提分类

新的 skill groups：

1. lifetime_analysis
    - double_free
    - invalid_free
    - use_after_free
    - memory_leak
    - ownership_transfer
    - resource_lifecycle
    - double_release
    - refcount_misuse

2. bounds_analysis
    - buffer_overflow
    - out_of_bounds
    - integer_overflow

3. initialization_analysis
    - uninitialized
    - null_dereference
    - must_check
    - error_propagation

4. concurrency_analysis
    - missing_lock
    - lock_order
    - lock_misuse

5. semantic_contract_analysis
    - state_transition
    - api_semantic_misuse
    - capability_contract
    - nullability_contract

原因：

同组共享 reasoning context。

减少：
- context switching
- prompt inflation
- repeated semantic reconstruction

--------------------------------------------------
PHASE 4 — Prompt Compression
--------------------------------------------------

当前问题：

每个 skill:
- 重复注入完整 protocol
- 重复注入 reflection
- 重复注入 persistence
- 重复注入 audit policy

重构：

System Prompt:
仅保留 immutable rules

Skill Prompt:
仅保留 rule-specific logic

Context Prompt:
仅包含当前 analysis slice

要求：

禁止 skill 获取完整 repo context。

skill 仅获取：

- relevant functions
- relevant paths
- relevant ownership chain
- relevant CFG slice

--------------------------------------------------
PHASE 5 — Deterministic Reflection
--------------------------------------------------

当前：

5轮自然语言 reflection

重构：

deterministic validators + minimal AI reflection

新增：

internal/reflection/

实现：

1. path validator
2. source/sink validator
3. ownership validator
4. lock validator
5. dedupe engine

AI 仅负责：

- semantic ambiguity
- exploitability reasoning
- difficult ownership ambiguity

禁止：

AI 重复执行：
- path existence verification
- symbol existence verification
- duplicate detection

--------------------------------------------------
PHASE 6 — Finding Pipeline Optimization
--------------------------------------------------

当前：

skill 直接输出最终 finding

重构：

skill 输出：

CandidateFinding

结构：

{
  rule_id
  source
  sink
  path
  confidence
  evidence_refs
}

Dispatcher：

负责：

- severity mapping
- reflection
- dedupe
- persistence

目标：

减少 worker 输出 token。

--------------------------------------------------
PHASE 7 — Token Budget Optimization
--------------------------------------------------

新增：

prompt budgeting system

规则：

1. skill 禁止读取整个文件
2. skill 禁止读取无关调用链
3. 单次 prompt token 控制
4. dispatcher 执行 context slicing

新增：

ContextSliceBuilder

仅提取：

- vulnerable path
- neighboring functions
- required type definitions

--------------------------------------------------
PHASE 8 — Native Parsing Integration
--------------------------------------------------

新增：

tree-sitter-c
tree-sitter-cpp

目标：

将：

- symbol extraction
- function extraction
- CFG metadata
- include graph

从 LLM 推理中移除。

LLM 不再负责：

- 解析函数边界
- 推断变量定义位置
- 推断 include 关系

--------------------------------------------------
PHASE 9 — Execution Scheduler
--------------------------------------------------

新增：

SkillScheduler

调度策略：

1. shared-context-first
2. same-analysis-group batching
3. token-budget-aware scheduling
4. incremental context reuse

禁止：

- 多个 group 同时重复读取代码
- 同一文件被重复全文注入多个 skill

--------------------------------------------------
PHASE 10 — Incremental Scan
--------------------------------------------------

新增：

incremental mode

支持：

/secguard git diff HEAD~1

要求：

仅重建受影响：
- functions
- callgraph edges
- ownership slices

禁止全量 rebuild。

--------------------------------------------------
SUCCESS METRICS
--------------------------------------------------

目标：

1. token 消耗下降 60%+
2. skill 平均执行时间下降 50%+
3. 大仓扫描时间下降 70%+
4. Findings 准确率不下降
5. M/B 比例稳定
6. false positive 不上升

--------------------------------------------------
CRITICAL DESIGN RULES
--------------------------------------------------

1. 保留当前 Findings/Persistence 协议
2. 保留当前 Reflection Philosophy
3. 保留当前 Dispatcher-Worker 架构
4. skill 不再是独立 reasoning universe
5. Dispatcher 是唯一 context owner
6. repo 只允许 index 一次
7. LLM 仅处理高价值 reasoning