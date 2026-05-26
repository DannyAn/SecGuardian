# SecGuardian CodePlan v2 — Toward World-Class AI Security Tooling

> 基于竞争对手重构计划分析 + SecGuardian 当前架构的差距评估
> 目标：定义下一步进化方向，不执行重构

---

## 一、竞争对手重构计划解读

### 1.1 对方在解决什么问题

这份重构计划的核心痛点是 **Token 消耗失控**：

```
当前问题（对方）：
  - 每个 skill 独立遍历整个 repo → N skills × M files 的 token 爆炸
  - 每个 skill 重复推理相同的代码结构（"这个函数做什么？"×17 次）
  - 5 轮自然语言 reflection → 大量 token 消耗在验证上
  - LLM 被用于机械性任务（符号提取、路径验证、去重）

重构方向（对方）：
  - Phase 1: Semantic Index Layer（repo scan once → shared AnalysisContext）
  - Phase 2: Skill → lightweight rule evaluator（不自己遍历 repo）
  - Phase 3: Skill groups by analysis premise（共享 reasoning context）
  - Phase 4: Prompt compression（System/Skill/Context 三层分离）
  - Phase 5: Deterministic reflection（机械化验证取代 AI reflection）
  - Phase 6: CandidateFinding → Dispatcher 统一处理
  - Phase 7: Token budget system
  - Phase 8: tree-sitter 原生解析（替代 LLM 做符号提取）
  - Phase 9: Execution scheduler（同一个 group 批量执行，避免重复读代码）
  - Phase 10: Incremental scan（git diff 只重建受影响部分）
```

### 1.2 设计的合理性评估

| 设计决策 | 评价 | 对我们的启示 |
|---------|------|------------|
| Semantic Index Layer | ★★★★★ 核心架构决策 | 我们完全缺失——每个 detector skill 都在独立读代码 |
| Skill → lightweight evaluator | ★★★★ 方向对 | 但我们的 skill 不仅是 evaluator，更是 reasoning agent——这是我们的差异点，不能完全放弃 |
| Skill groups by premise | ★★★★ 合理 | 我们的 detector 按 namespace（memory/system/crypto）组织，但与分析前提不匹配 |
| Deterministic reflection | ★★★ 部分合理 | 机械化验证对路径/符号有效，但对 exploitability reasoning 必须保留 AI |
| Native parsing (tree-sitter) | ★★★★★ 必须做 | 这是降低误报的根本手段——AI 不应做编译器做的事 |
| Token budget system | ★★★★ 商业化必须 | 按 API token 计费必须控制成本 |
| External API stability (v2.1) | ★★★★★ 工程纪律 | 我们已经有 namespace 过滤器和 CLI 接口，需要锁定为 stable API |

### 1.3 对方的致命缺陷

这份重构计划有一个根本性问题：**它把所有的 reasoning depth 压缩成了 "lightweight rule evaluator"**。从 SecGuardian 的角度看，这是错的：

- 我们卖的就是 **AI 的深度推理能力**（taint analysis 的 5-phase 协议）
- 如果把 skill 变成轻量规则求值器，我们就退化成了另一个 Semgrep
- **对方没有"旗舰产品"概念**——只有一个 disaggregated scanner

**我们的路线应该是**：借鉴其工程化部分（Phase 1/5/7/8/9/10），但保留我们独有的 AI reasoning depth。

---

## 二、SecGuardian vs 竞争对手：架构差异对照表

| 维度 | 竞争对手 | SecGuardian 当前 | 差距 |
|------|---------|-----------------|------|
| **代码理解层** | Semantic Index + tree-sitter 一次性构建 | 无——每次 AI 调用都重新读代码 | 对方胜。我们有巨大的 token 浪费 |
| **Skill 执行模型** | Lightweight evaluator + shared context | Heavy reasoning agent + 独立上下文 | 对方效率高，但缺乏深度。我们深度好，但效率差 |
| **Reflection** | Deterministic validators + minimal AI | 无结构化 reflection | 对方有。我们没有任何 reflection 机制 |
| **Token 管理** | Budget system + context slicing | 无——全量 prompt 注入 | 对方胜。我们完全不做 token 控制 |
| **Native 解析** | tree-sitter C/C++ | 无——依赖 LLM 理解代码结构 | 对方胜。这是降低误报的根本手段 |
| **增量扫描** | 仅重建受影响函数 | 命令定义了 git diff 接口但无实际增量实现 | 对方胜。我们接口在，实现不在 |
| **Public API stability** | 锁定 namespace + CLI 接口不变 | namespace 模型已经在用 | 持平 |
| **技能分类体系** | 按分析前提分组 (lifetime/bounds/init/...) | 按漏洞类型分组 (memory/system/crypto) + 按语言分组 (cpp/java/py/go) | 各有优劣。对方分组更利于引擎复用；我们分组更利于用户理解 |
| **三层产品架构** | ✗ 无 | ★★★★★ 有 (secguard/secaudit/secreview) | 我们完胜。这是我们的核心差异化 |
| **结构化知识库** | ✗ 无（或未体现） | ★★★★★ 30 detectors + 25 skills + 10 concepts | 我们完胜。对方可能没有同等级的知识工程 |

---

## 三、SecGuardian 当前架构的核心弱点

看完对方计划后，我识别出我们 **必须解决** 的 5 个结构性弱点：

### 弱点 1：没有代码索引层（P0）

**现状**：每次 `/secguard scan ./src`，AI 要从零开始读文件、理解函数边界、追踪调用关系。同一个 repo 扫描 3 次，AI 做 3 遍相同的代码理解。

**影响**：Token 消耗是线性的 O(N×M)（N=skills, M=files），大仓库根本扫不动。

**业界标准**：CodeQL 构建 snapshot 数据库，Semgrep 有 AST 缓存，SonarQube 有项目级索引。

### 弱点 2：误报率高因为 LLM 在做编译器的事（P0）

**现状**：AI 通过读代码文本来判断 "这个 malloc 有没有对应的 free"，它没有调用图、没有支配树、没有 liveness 分析。

**业界标准**：即使是 Semgrep（纯模式匹配）也有 AST 级别的精确匹配。CodeQL 有完整的 CFG + 数据流。

### 弱点 3：没有 Token 预算控制（P1）

**现状**：每次 skill 调用，我们注入完整的 protocol + detector knowledge + skill prompt。一个 taint-analysis 审计可能消耗 20K+ tokens 仅在 prompt 中。

**影响**：如果按 API token 计费，这是一个无法盈利的成本结构。

### 弱点 4：没有结构化的结果验证（P1）

**现状**：AI 输出 findings → 直接写入 manifest.json。没有任何确定性验证步骤。

**业界标准**：Semgrep Assistant 做 AI triage，CodeQL 有 data flow path validation。

### 弱点 5：增量扫描只有接口没有实现（P2）

**现状**：`commands/secguard.md` 定义了 `git diff HEAD~1` 语法，但 CLI 里没有实际增量分析逻辑。

---

## 四、CodePlan v2 — 分阶段进化路线

> 原则：
> 1. 不破坏现有三层产品架构
> 2. 不丢失 AI reasoning depth（我们的核心差异化）
> 3. 在工程基础设施层面追赶业界最佳实践
> 4. 每个阶段独立可交付、独立有价值

---

### Phase 1 — Semantic Foundation（降低误报的基础）

**目标**：让 AI 不再做编译器的事

```
新增模块:
├── internal/parsers/
│   ├── tree-sitter-c        → C 语言 AST + 符号提取
│   ├── tree-sitter-cpp      → C++ AST + 符号提取
│   ├── tree-sitter-python   → Python AST
│   ├── tree-sitter-java     → Java AST
│   └── tree-sitter-go       → Go AST
│
├── internal/indexer/
│   ├── symbol_extractor     → 函数/变量/类型/宏定义索引
│   ├── call_graph_builder   → 轻量调用图（不做全程序数据流）
│   ├── alloc_free_matcher   → malloc/free 配对
│   └── lock_usage_graph    → mutex 获取/释放关系
│
└── internal/context/
    └── AnalysisContext      → 共享上下文（repo scan once）
        ├── symbols: SymbolIndex
        ├── call_graph: CallGraph
        ├── allocators: AllocFreeMap
        └── locks: LockGraph
```

**关键决策**：
- ✅ 借鉴对方的 Semantic Index Layer 设计
- ✅ tree-sitter 替代 LLM 做机械性代码解析
- ❌ **不做** 完整 CFG/数据流引擎——那会让我们变成又一个笨重的 SAST 工具
- ❌ **不做** 对方的 "lightweight rule evaluator"——保留 AI reasoning depth

**交付物**：
1. `internal/` 目录 + Go 代码（因为 tree-sitter Go bindings 最成熟）
2. 对 C/C++ 仓库的一次性索引（symbols + call graph + alloc/free map）
3. 索引结果注入到 prompt context 中（而非让 AI 自己读代码）

**成功指标**：
- AI 不再需要自己判断 "这个函数在哪里定义"
- buffer-overflow detector 的 FP 率下降 30%+（有了 sizeof 信息和调用关系）
- 每个 skill 的 context tokens 下降 40%+（不用注入完整文件）

---

### Phase 2 — Token Budget & Prompt Architecture（降本）

**目标**：让产品在 API token 计费下可盈利

```
重构:
当前 prompt 结构（每个 skill 全量注入）:
  System Prompt:
    ├── protocol (scan-output.md)        ← 引用不变规则
    ├── reflection rules                 ← 新增
    └── persistence rules                ← 引用不变规则
  Skill Prompt:
    ├── SKILL.md (full)                  ← 拆分为 rule logic + examples
    └── knowledge/detectors/*.md         ← 仅注入 relevant detectors
  Context Prompt:
    └── full file content                ← 替换为 AnalysisContext slices

改为三层分离:
  System Prompt (immutable, cached):
    ├── scan-output protocol (static reference)
    ├── SARIF output rules (static reference)
    └── reflection checklist (static, deterministic)
  
  Skill Prompt (per-skill, minimal):
    ├── rule-specific detection logic (stripped of generic content)
    └── relevant detector patterns (filtered by scope)
  
  Context Prompt (per-execution, sliced):
    ├── AnalysisContext.symbols (near target line)
    ├── AnalysisContext.call_graph (1-hop neighbors)
    └── target file snippet (target line ± N lines only)
```

**关键决策**：
- ✅ 借鉴对方的 "System Prompt 仅保留 immutable rules"
- ✅ 引入 ContextSliceBuilder 概念
- ❌ **不做** 对方的 "skill 禁止读取完整文件"——AI 有时需要更宽上下文做推理

**交付物**：
1. Prompt 模板化：`knowledge/prompt-templates/system.md` + `skill.md` + `context.md`
2. ContextSliceBuilder：基于 target file:line 提取最小必要上下文
3. Token budget calculator：估算每个 skill 执行前需要的 token 数

**成功指标**：
- 单次 secguard scan 的 prompt tokens 下降 50%+
- 仍然保持 AI reasoning quality（不因裁减上下文损失深度）

---

### Phase 3 — Confidence & Reflection Pipeline（提升准确率）

**目标**：给每个 finding 打上可量化的置信度，降低人工 triage 成本

```
新增模块:
└── internal/reflection/
    ├── path_validator       → 验证 finding 中的代码路径是否存在
    ├── symbol_validator     → 验证 finding 中引用的符号是否真实
    ├── dedupe_engine        → 同一漏洞被多个 detector 报告时合并
    ├── confidence_scorer    → 基于证据链质量自动评分（high/medium/low）
    └── severity_mapper      → 基于 CWE + context 自动映射严重度
```

**工作流**：
```
1. AI skill 产出 CandidateFinding
   {rule_id, source, sink, path, evidence_refs}

2. reflection pipeline 确定性验证:
   path_validator → 代码路径存在? ✓/✗
   symbol_validator → 引用符号存在? ✓/✗
   dedupe_engine → 与已有 findings 重复? merge/skip

3. confidence_scorer 评分:
   - 路径可验证 + 符号可验证 → high
   - 仅模式匹配，路径不完整 → medium  
   - AI 推理结论，无可验证证据 → low

4. severity_mapper 生成最终 severity

5. 写入 manifest.json + findings/
```

**关键决策**：
- ✅ 借鉴对方的确定性 reflection 思路
- ✅ 保留 AI 做 exploitability reasoning（这是机械化做不到的）
- ❌ 拒绝完全机械化——语义歧义必须由 AI 判断

**交付物**：
1. `internal/reflection/` Go 模块
2. `confidence_scorer` 算法（基于证据链权重的评分规则）
3. 更新 `knowledge/protocols/scan-output.md` 加入 confidence 字段的生成规则

**成功指标**：
- high confidence findings 的精确率达到 80%+
- medium/low confidence findings 可以被用户过滤掉（降低感知 FP 率）

---

### Phase 4 — Execution Scheduler（提速）

**目标**：同一分析组内的 detector 共享上下文，避免重复推理

```
新增模块:
└── internal/scheduler/
    ├── SkillScheduler      → 按分析组调度
    ├── GroupContext         → 同组共享的推理上下文
    └── TokenBudgetManager   → 按组分配 token budget
```

**分析组定义**（在 detector-index 中声明）：
```
memory group:
  - null-dereference
  - double-free
  - use-after-free
  - memory-leak
  - mismatched-free
  → 共享: allocator map + ownership hints

bounds group:
  - buffer-overflow
  - heap-buffer-overflow
  - off-by-one
  - integer-overflow
  → 共享: buffer size info + loop bounds

concurrency group:
  - race-condition
  - deadlock
  - data-race
  → 共享: lock graph + thread context
```

**关键决策**：
- ✅ 借鉴对方的 skill group 概念
- ✅ 保持 namespace 作为用户接口不变
- ❌ 不做对方的 "skill = lightweight evaluator"——组内仍保留 AI reasoning

**交付物**：
1. `detector-index.md` 增加 `analysis_group` 字段
2. `SkillScheduler` 实现：同组 detectors 批量执行
3. `GroupContext` 实现：同组共享 call graph slices

**成功指标**：
- 同组 detectors 执行时间下降 40%+（共享上下文）
- Token 消耗进一步下降 20%+

---

### Phase 5 — Incremental Scan Engine（增量扫描）

**目标**：PR 级别扫描只分析变更代码，不重建全量索引

```
增强:
internal/indexer/
  └── incremental_updater
      ├── git diff parser       → 解析变更行范围
      ├── affected_symbols      → 识别受影响的符号
      ├── incremental_reindex   → 仅重建变更函数的索引
      └── scope_limiter         → 限制 skill 仅分析变更代码
```

**工作流**：
```
/secguard ./src git diff HEAD~1

1. git diff HEAD~1 → changed files + line ranges
2. incremental_reindex → only rebuild changed functions
3. scope_limiter → constrain each skill to: changed_lines + callers + callees
4. existing index for unchanged code → reuse
```

**交付物**：
1. `internal/indexer/incremental_updater` 
2. `commands/secguard.md` 中的 git diff 接口不再只是文档——有实际实现

**成功指标**：
- 增量扫描时间 = O(changed_lines) 而非 O(repo_size)
- PR 级别扫描 <30 秒（vs 现在可能 10+ 分钟）

---

### Phase 6 — Knowledge Base Evolution（知识库进化）

**目标**：从 30 个 detectors → 50+ 个，同时保持质量

```
扩展:
knowledge/detectors/  (新增 Web 安全检测器)
  ├── xss-detector.md         → CWE-79
  ├── csrf-detector.md        → CWE-352
  ├── ssrf-detector.md        → CWE-918
  ├── open-redirect.md        → CWE-601
  ├── ssti-detector.md        → CWE-1336
  ├── xxe-detector.md         → CWE-611
  ├── idor-detector.md        → CWE-639
  ├── auth-bypass.md          → CWE-287
  ├── jwt-misuse.md           → CWE-347
  └── ...

knowledge/concepts/  (新增)
  ├── csrf.md
  ├── open-redirect.md
  └── jwt-security.md
```

**交付物**：
1. 10+ 个新 detector（重点覆盖 OWASP Top 10 缺失项）
2. 3+ 个新 security concept
3. `examples/` 新增对应的标注漏洞代码

**成功指标**：
- CWE Top 25 覆盖率从 44% → 80%
- OWASP Top 10 覆盖率从 15% → 80%

---

## 五、我们不做的（与竞争对手的差别化决策）

| 对方的做法 | 我们为什么不照搬 |
|-----------|----------------|
| Skill → lightweight rule evaluator | 这是我们核心差异——AI reasoning depth 是我们的卖点。机械化的是**代码理解**，不应机械化**安全推理** |
| 5 轮自然语言 reflection → deterministic | 借鉴确定性验证做路径/符号校验，但 **exploitability reasoning 必须保留 AI** |
| 按分析前提重组 skill group | 用户接口（namespace）不变。内部调度按 group 优化，但对外保持 memory/system/crypto |
| C/C++ only | 我们扩展到 Java/Python/Go——Web 安全是我们的蓝海 |

---

## 六、优先级与时间线

```
Phase 1: Semantic Foundation     ← P0, 本周开始
Phase 2: Token Budget & Prompt   ← P0, 与 Phase 1 并行
Phase 3: Confidence & Reflection ← P1, Phase 1 完成后
Phase 4: Execution Scheduler     ← P2, Phase 3 完成后
Phase 5: Incremental Scan        ← P2, Phase 4 完成后
Phase 6: Knowledge Base Evolution ← P2, 持续迭代
```

### 为什么 Phase 1 是最高优先级

1. **没有索引层，我们连准确率都测不准**——当前 benchmark.sh 统计的是静态模式匹配，不是真实的检测效果
2. **tree-sitter 投入小、回报大**——Go bindings 成熟，一周可完成 C/C++/Go 三个语言的解析
3. **索引层是所有后续优化的前提**——Phase 2-5 都依赖 Phase 1 的 AnalysisContext

---

## 七、关键设计原则（继承自竞争对手的 7 条规则 + 我们的新增）

### 从对方借鉴的：
1. ✅ Dispatcher 是唯一 context owner
2. ✅ repo 只允许 index 一次
3. ✅ LLM 仅处理高价值 reasoning（不做符号提取、路径验证）
4. ✅ 用户 namespace 接口永久稳定
5. ✅ Internal engine taxonomy 不暴露给用户
6. ✅ CLI + findings schema + persistence 向后兼容

### 我们新增的：
7. **三层产品架构不可破坏**（secguard/secaudit/secreview 是最强差异化）
8. **AI reasoning depth 不可降级为 rule evaluator**（这是我们的核心壁垒）
9. **结构化知识库是护城河**（30 detectors + 25 skills 的深度不能被压缩）

---

## 八、下一步行动

从 `docs/work-plan.md` 的 Phase 2 任务中，插入这个 CodePlan 的 Phase 1 作为最高优先级：

```
当前 work-plan 下一项: P0-1: 对 examples/ 运行 AI 审计获取 TP/FP
CodePlan v2 插入:       Phase 1: Semantic Foundation (tree-sitter + AnalysisContext)
优先级调整:             CodePlan Phase 1 > 原 P0-1
```

原因：先建好代码索引基础设施，再做 AI 审计测试，得到的准确率数据才有意义——否则测出来的不是 AI 推理能力，而是 LLM 读代码的随机性。
