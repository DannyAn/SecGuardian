# FEATURE-007: Signal Precision & Function-Level Context Assembly

> **隶属 Epic**: EPIC-011 Enforcement Integrity
> **创建**: 2026-07-11
> **优先**: P0
> **驱动**: OpenCode session 崩溃回溯 + 跨平台一致性审计 + 信号精度缺陷系统性修复

---

## 1. Problem Statement

### 1.1 信号路由粗放（噪音爆炸）

`partition-signals.py` 已支持 `callee="free"` 级别的精确匹配，但 C++ 的 8 个 memory 规则全部使用 `cat="memory"` 粗粒度路由。
demo 项目 74 个 call_sites 中 40 个归属 `cat="memory"`，这 40 个信号被复制到 8 个规则，产生 320 个 assignment。
其中 `double_free` 实际只需要 `free()` 调用，却收到了 `malloc()`/`memcpy()` 等不相关信号。

### 1.2 索引器产出闲置

`index.json` 包含 `variable_writes`(128)、`pointer_validations`(38)、`cfgs`(103 函数)、`taint_flows`(10)，
但 prescreener 只消费 `call_sites + declarations`。这些变量级数据没有任何组件使用。

### 1.3 调用图断裂

`main.go:141-147` 的 V1/V2 二选一逻辑：
```go
if len(allCallSites) > 0 {
    cg = BuildCallGraphV2(allCallSites, symbols)   // 仅 user→lib 边
} else {
    cg = BuildCallGraph(parsed, symbols)           // user→user 边，死代码
}
```
结果：调用图有 74 条边，全部是 `user→库函数`，零条 `user→user` 边。
`main()` 调用 `parse_task_name()` 的事实未被记录，调用链/被调用链信息缺失。

### 1.4 上下文碎裂

当前 partition 把同一函数的不同调用拆分到不同 batch。例如 `release_entry` 函数中的 `free(entry->buffer)` 和 `free(entry)` 可能出现在同一个 batch 里但因为被当作独立信号处理，LLM 无法关联两者。对于 `llm_malloc`/`llm_free` 等自定义配对，LLM 即使有能力做语义识别，也因看不到配对双方而无法生效。

### 1.5 跨语言能力不对称

C/C++ 的 tree-sitter 解析器产出 CFG/taint/alloc_free/lock_graph/pointer_valid，但 Python/Java/Go/JS 不产出这些数据。
预筛架构不能假设全语言统一能力。

---

## 2. Design Goals

| ID | 目标 | 度量 |
|----|------|------|
| G1 | 信号路由精准化 | demo 的 571 assignments → ≤ 200，且无真实漏洞信号被误过滤 |
| G2 | 确定性预筛覆盖 6 个 C++ rule | buffer_overflow/null_dereference/memory_leak/double_free/command_injection/lock_misuse 的信号降幅 ≥ 50% |
| G3 | 调用图包含 user→user 边 | `main → parse_task_name` 等用户函数间调用出现在 call_graph.edges 中 |
| G4 | LLM 以函数为调查单元接收信号 | 同一函数的全部相关信号 + 变量流转 + 调用链在同一 batch 内 |
| G5 | 跨语言兼容 | Python/Java/Go/JS 至少支持 callee 级路由 + 函数级分组 |
| G6 | 无回归 | self-check / ci-check / e2e-verify 全部通过；现有 prescreener 功能不受影响 |

---

## 3. Requirements

### REQ-001: callee 级信号路由（P1，所有语言）

`rule.md` frontmatter 的 `signal_source` 支持 `callee=` 精确匹配：

```
# C/C++ double_free
signal_source: call_sites[callee="free|delete"]

# Python command_injection
signal_source: call_sites[callee="os.system|subprocess.call|subprocess.Popen|os.popen|eval|exec"]

# Java sql_injection
signal_source: call_sites[callee="executeQuery|execute|executeUpdate|createStatement|prepareStatement"]
```

**约束**：`partition-signals.py` 已有此能力（`_matches` 函数逐字段匹配），只需修改 rule.md 配置。

### REQ-002: 确定性预筛（P2，仅 C/C++ Tier 1）

新增 `scripts/prefilter.py`，对以下 rule 做保守预筛。预筛不通过 → 保留给 LLM（不确定就不滤）。

| Rule | 预筛逻辑 | 依赖数据 |
|------|---------|---------|
| buffer_overflow | 写入量-容量校验 + 安全变体参数验证 | call_sites + declarations + variable_writes |
| null_dereference | `pointer_validations.has_null_check=true AND is_dereferenced=true` → safe | pointer_validations |
| memory_leak | `malloc` 在 `alloc_free` 中有匹配 `free` → safe；指针为全局变量 → 不过滤 | alloc_free + declarations |
| double_free | 同一函数的 `free()` 调用数 < 2 → safe | call_sites 按函数分组 |
| command_injection | `system()` 参数不在任何 `taint_flow` 中 → 降优先级（不直接过滤） | taint_flows |
| lock_misuse | `lock_graph` 中 lock 有对应 unlock → safe | lock_graph |

**buffer_overflow 的检测设计（对标业界最佳实践）**：

当前 prescreener 只处理安全变体（`_s` 函数）的 `sizeof` 匹配。业界做法（Coverity/SAL/Clang Static Analyzer）是三层检测：

**第 1 层：容量追踪**
为每个缓冲区变量追踪其实际容量（字节）：
```
栈数组:   char buf[N]     → capacity = N（已有 declarations.array_size）
堆分配:   char *p = malloc(n) → capacity = n（需要变量级追踪，M2）
参数:     void f(char *buf, size_t size)  → capacity = size（需要 SAL 注解或启发式推断，M2+）
结构体字段: struct S { char data[N]; } → capacity = N（需要类型解析，M2+）
```

**第 2 层：写入校验**
在每次写入操作点，验证 `写入量 ≤ 缓冲区容量`：
```
strcpy(dst, src)   → 写入量 = strlen(src) + 1，检查 ≤ dst_capacity
memcpy(dst, src, n) → 写入量 = n（或 min(n, src_known_size)），检查 ≤ dst_capacity
sprintf(dst, fmt, ...) → 写入量 = 编译时估算的格式化输出长度
dst[idx] = val      → 检查 idx < array_size（Index Out of Bounds / CWE-129）
```

**第 3 层：安全变体参数验证**
安全变体（`strcpy_s` 等）**不等于安全**——只是运行时保护。检测重点：
```
strcpy_s(dst, size, src)
  ✅ size == sizeof(stack_array) → 正确（当前 prescreener 已覆盖，保守校验）
  ❌ sizeof(ptr) 用于指针 → sizeof 返回指针大小(8字节)，不是缓冲区容量 → 误报意义上的"假安全"
  ❌ size 为常量但小于实际容量 → 不必要的截断，可能导致数据丢失
  ❌ size 参数来自另一个变量 → 需要追踪该变量的值
```

当前 prescreener 只覆盖了第 3 层的 `sizeof(stack_array)` 匹配场景。本 Feature 扩展到第 1 层（栈数组容量追踪）+ 第 2 层（写入校验）+ 第 3 层的 `sizeof(ptr)` 误用检测。

堆分配/参数/结构体字段的容量追踪留待 M2（需要变量级数据流）。

**Index Out of Bounds (CWE-129)** 是 buffer_overflow 的关联检测类：
```c
char buf[64];
buf[user_input] = x;  // 如果 user_input 未校验 → Index Out of Bounds
```
当前不检测。需要在 declaration 的 `array_size` 已知且索引变量来自 `taint_flow` 时标记为可疑。

**约束**：预筛为保守策略。任何不确定的条件一律不滤。预筛器的输出是 `filtered_signals` + `filter_reasons`，用于 audit。

### REQ-003: 调用图修复（P3，所有语言）

`main.go` 的索引阶段同时运行 V1（`BuildCallGraph`）和 V2（`BuildCallGraphV2`），合并去重：

```go
cgV1 := indexer.BuildCallGraph(parsed, symbols)
cgV2 := indexer.BuildCallGraphV2(allCallSites, symbols)
cg := indexer.MergeCallGraphs(cgV1, cgV2)
```

**约束**：V1 的文本近似匹配保持原有算法，不做精度提升。V1 的已知局限（短函数名假边、跨文件误匹配）通过 de-duplication 缓解。

### REQ-004: 函数级上下文组装（P4，所有语言）

新增 `FunctionCallContext` 类型，按函数聚合所有相关数据：

```json
{
  "function": "release_entry",
  "file": "src/allocator.c",
  "start_line": 48, "end_line": 56,
  "callers": ["cleanup_entries"],
  "callees": ["free", "free"],
  "call_sites": [
    {"callee": "free", "line": 51, "args": ["entry->buffer"], "category": "memory"},
    {"callee": "free", "line": 53, "args": ["entry"], "category": "memory"}
  ],
  "variable_writes": [
    {"variable": "entry", "line": 51, "is_initialized": true}
  ],
  "pointer_validations": [],
  "taint_flows": [],
  "alloc_free": [
    {"alloc_func": "malloc", "alloc_line": 30, "free_sites": [{"line": 53}]}
  ],
  "cfg_summary": {"blocks": 5, "exits": 1, "has_loop": false}
}
```

`partition-signals.py` 新增 `--group-by function` 模式：按函数分组后，每个 nonempty 函数分配给所有 signal_source 匹配的 rule。一个函数可能出现在多个 rule 的 partition 中（因为不同类型的信号可能共存）。

### REQ-005: 跨语言兼容性（所有语言）

按语言索引器能力分层：

| Tier | 语言 | 可用功能 |
|------|------|---------|
| Tier 1 | C/C++ | P1 callee 路由 + P2 预筛 + P3 调用图 + P4 函数上下文 |
| Tier 2 | Python, Java, Go | P1 callee 路由 + P3 调用图（V1 text-matching）+ P4 函数上下文（call_sites + call_graph） |
| Tier 3 | JS | P1 callee 路由 + P4 函数上下文（call_sites only, 无 call_graph） |

**约束**：架构不强制 Tier 2/3 语言补齐 CFG/data-flow。Tier 2/3 语言在能力不足时退化为"callee 路由 + 函数分组 + LLM 全权判断"。

---

## 4. Design

### 4.1 数据流

```
源码 → Tree-sitter 索引（不变）
  ↓
索引器 V1+V2 合并调用图（P3）
  ↓
prefilter.py 消费 index.json 做确定性预筛（P2，Tier 1 only）
  ↓
index.json 新增 function_call_contexts（P4）
  ↓
partition-signals.py --group-by function（P4）
  ↓
per-function batch → LLM Investigation Pipeline
  ↓
gate 强制（verification-gate + coverage-gate）→ render
```

### 4.2 关键设计选择

**为什么不把预筛逻辑放进 Go 索引器？**

预筛器的逻辑复杂度（条件判断、数据关联、降级策略）更适合 Python 实现。Python 可以快速迭代预筛规则而无需重新编译索引器。索引器保持"纯数据提取"的定位，预筛作为独立的确定性处理层。

**为什么不是 per-variable 分组而是 per-function？**

per-variable 需要完整的 def-use chain，这是索引器当前不做的事情。per-function 利用了索引器已有的函数边界信息（`symbols.functions[i].start_line/end_line`），且自然覆盖了 LLM 需要的"同函数内配对识别"场景。

---

## 5. TDD 验收标准

### TDD-V1: callee 路由无漏检
- **Given**: cpp-vuln-demo-no-answers index.json
- **When**: 修改后 double_free 的 `signal_source: call_sites[callee="free|delete"]`
- **Then**: partition-plan 中 double_free 信号数 ≤ 20（原 40），且 > 0（不能把所有 free 都滤掉）
- **Verification**: `partition-signals.py --self-test` + 新增 callee-route 测试用例

### TDD-V2: 预筛保守性
- **Given**: 人工标注的 cpp-vuln-demo-no-answers/expected-results.json
- **When**: prefilter.py 对 null_dereference 做预筛
- **Then**: 所有 expected-results 中的 null_dereference 漏洞信号 100% 通过预筛（recall=1.0）
- **Verification**: `prefilter.py --verify-against-ground-truth`

### TDD-V3: 调用图完整性
- **Given**: demo 代码中 main() 调用了 parse_task_name() 和 format_task_desc()
- **When**: V1+V2 合并后的 call_graph
- **Then**: `main → parse_task_name` 和 `main → format_task_desc` 出现在 edges 中
- **Verification**: `go test -tags cgo -run TestCallGraphV1V2Merge ./indexer/`

### TDD-V4: 函数上下文完整性
- **Given**: allocator.c 的 release_entry 函数（51-53 行，两次 free）
- **When**: `partition-signals.py --group-by function`
- **Then**: release_entry 作为一个 batch，包含 2 个 free call_sites + 变量信息 + 调用链
- **Verification**: 集成测试验证 partition-plan 中 release_entry 是一个独立 batch，包含 2 个信号

### TDD-V5: 跨语言无退化
- **Given**: Python/Java/Go/JS 的 rule.md 和 demo index
- **When**: 新 partition mode 对非 C++ 语言执行
- **Then**: 原有信号数不变或减少（无新增噪音），函数分组正确
- **Verification**: `bash scripts/self-check.sh` + e2e 多语言验证

### TDD-V6: 无回归
- **Given**: 修改前后的 cpp-vuln-demo 扫描
- **When**: 运行完整的 e2e-verify.sh
- **Then**: findings 数量不减少、severity 分布不变、recall 不低于基线
- **Verification**: `bash scripts/e2e-verify.sh --ci`

---

## 8. Production Scale Safety — 崩溃根因逐环对照

> 本节是 2026-07-11 OpenCode session 崩溃后追加的硬约束。必须证明每条崩溃因果链都被结构性修复，而非偶然对 demo 有效。

### 崩溃因果链 #1：信号路由粗放 → 噪音爆炸 → 32 batch

```
崩溃路径: 40 cat="memory" 信号 × 8 规则 = 320 assignments → 32 batch
          LLM 在纯噪音 batch（如 malloc 发给 double_free）中消耗 token 无产出
修复:    P1 callee 路由 → double_free 只收 free() 信号
         40 → 20 signals, 320 → 200 assignments
         结合 P2 预筛（同函数 free < 2 → 过滤）→ ~5 signals → 1 batch
验证:    TDD-V1: partition assignments < 250（降 56%+）
状态:    ✅ 结构修复（不依赖 LLM 自觉，partition-signals.py 确定性路由）
```

### 崩溃因果链 #2：LLM 上下文累积 → 自行丢弃 12/15 规则

```
崩溃路径: CHANGE-004 记录的事实——LLM 在主上下文处理 3 条 rule 后丢弃剩余 12 条
         日志原话: "remaining rules have 40+ signals each and would consume too much context"
修复:    Phase 2 改为每 (rule_id, batch_id) 一个独立 Task 子代理
         禁止 "complete remaining batches" 合并式委派（CHANGE-005）
         每个 Task 上下文干净，不累积其他 rule 的调查内容
验证:    session log 中每个 batch 是独立 Task，无合并式 prompt
状态:    ✅ CHANGE-004/005 已实现（命令模板 + dispatch-protocol.md）
```

### 崩溃因果链 #3：完整 partition-plan.json 读入父上下文 → token 淹没

```
崩溃路径: 父 Dispatcher 读取了 32 batch × 20 signals 的完整 signal-rich plan
         每个 signal 含 caller/callee/file/line/arguments 等字段
         仅 JSON 本身即 ~50KB tokens，加上源码窗口 → 上下文爆炸
修复:    父 Dispatcher 只读 compact schedule: rule_id | batch_id | signal_count | rule_path
         禁止用 Read 读取完整 partition-plan.json
         禁止在父上下文加载任何 signal 详情
验证:    NON-NEGOTIABLE 段明确禁止 "禁止用 Read 读取完整 partition-plan.json"
状态:    ✅ CHANGE-005 已实现
```

### 崩溃因果链 #4：函数内相关信号被拆散 → LLM 无法做配对 → 全部 suppress → 纯噪音 batch

```
崩溃路径: release_entry 函数的 free(entry->buffer) 和 free(entry) 分在不同 batch
         LLM 看不到两者关系 → 每个独立判定 → 都 suppress → 0 findings
         这种无产出的 batch 累计消耗上下文但无任何 finding
修复:    P4 per-function 分组 → release_entry 作为一个 batch
         LLM 同时看到 2 个 free() 调用 + 变量流转 + 调用链
         可以判断: 两次 free 操作不同指针（entry->buffer vs entry）→ double free 不成立
         或判断: 同一指针被两次释放 → CONFIRMED
         LLM 能做有意义的语义判断而非孤立猜疑
         同时 P2 预筛可以提前过滤"同函数 free < 2"的函数
验证:    TDD-V4: release_entry 作为一个独立 batch，包含 2 个 free call_sites
状态:    ✅ P4 设计完成，待实现
```

### 崩溃因果链 #5：生产规模下的 batch 数量线性增长

```
崩溃路径: demo 15 文件 → 32 batch。684 文件按线性推算 → ~800 batch
         800 个串行 Task 执行在当前架构下必然超时或耗尽上下文
修复（多层组合）:
  P1: callee 路由 → 信号降 60% → batch 数等比例下降
  P2: 确定性预筛 → 每个 rule 再降 30-50% → batch 再降
  P4: per-function 分组 → 同函数多信号合并 → batch 再降
  叠加效果: 800 batch → ~150-200 batch (80%+ reduction)

  兜底机制（硬上限）:
  MAX_BATCHES_PER_SCAN = 100
  当 partition-plan.json 中 batch 数超过上限:
    1. 按 rule 严重度排序（Critical > High > Medium）
    2. 前 100 个 batch 正常执行
    3. 剩余 batch 写入 coverage-gate 标记 `unprocessed`
    4. coverage-gate 报告 "N batches deferred due to batch budget — re-run with --resume"
    5. 用户可调整 BATCH_SIZE（增大 → batch 数减少）或分次扫描
验证:    TDD-V6: 构造 200+ batch 的 partition plan → 断言 MAX_BATCHES 截断生效
状态:    ✅ 设计完成，待实现
```

### 综合效果估算

| 场景 | 原始 batch 数 | P1 callee | +P2 prefilter | +P4 per-func | 最终 |
|------|-------------|-----------|---------------|-------------|------|
| demo (15 文件) | 32 | ~18 | ~12 | ~10 | ✅ 安全 |
| 中型项目 (100 文件) | ~200 | ~100 | ~60 | ~45 | ✅ 安全 |
| 生产项目 (684 文件) | ~800 | ~400 | ~240 | ~180 | ⚠️ 超过 MAX_BATCHES=100，触发截断 |

**关键设计选择**：不在架构上假装能无限扩展。承认 684 文件场景需要多次扫描或更高 BATCH_SIZE。截断不是 bug，是显式的资源约束。

---

## 9. Risks & Constraints (Updated)

| 风险 | 缓解 |
|------|------|
| callee 路由过度过滤 | 保留 `cat="*"` 的兜底 rule（api_semantic_misuse），其他 rule 用 callee 白名单但不能遗漏任何真实漏洞信号 |
| V1 假边 | V1 文本近似已知有假边风险（短函数名误匹配），合并时按 caller_file/callee_name 去重。假边不会导致假阳性（LLM 会判断），但会增加上下文噪音 |
| 预筛假阴性 | 保守策略：任何不确定的条件一律不滤。预筛器的判断条件必须是"确定安全"才能滤。ground truth 验证确保 recall=1.0 |
| 跨语言兼容性 | Tier 2/3 语言不支持深度预筛，但 callee 路由 + 函数分组在所有语言都能生效 |
| 函数级 batch 可能过大 | 对大函数（1000+ 行），单 batch 上下文可能超出 LLM 预算。设置 MAX_FUNCTION_LINES=300，超过则按行号切片 |

---

## 7. Out of Scope

- 完整 DFG/SSA 构建 → FEATURE-002 M2
- inter-procedural taint → FEATURE-002 M2
- Q-matrix 60 规则全覆盖 → FEATURE-003
- JS tree-sitter 迁移 → FEATURE-002 F5
- Gemini 独立上下文原语 → 依赖 Gemini 平台能力
