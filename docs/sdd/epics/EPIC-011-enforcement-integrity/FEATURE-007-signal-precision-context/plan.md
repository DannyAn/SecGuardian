# Plan — FEATURE-007: Signal Precision & Function-Level Context Assembly

> **隶属**: EPIC-011 / FEATURE-007
> **目标**: 四阶段（精确路由 → 确定性预筛 → 调用图修复 → 函数级上下文）+ 跨语言适配

---

## Architecture

```
源码 → Tree-sitter 索引器（不变）
  ├── V1 BuildCallGraph（user→user）  ← 死代码复活
  ├── V2 BuildCallGraphV2（user→lib） ← 保持不变
  └── Merge → call_graph（完整）

index.json → prefilter.py（新增，Tier 1 only）
  ├── 消费: variable_writes, pointer_validations, cfgs, taint_flows, alloc_free
  ├── 产出: filtered_call_sites + filter_reasons.json
  └── 保守策略: 不确定 → 保留

prefiltered index → partition-signals.py --group-by function
  ├── 模式 1（默认，向后兼容）: per-signal batch
  └── 模式 2（新）: per-function batch，同一函数的所有信号在同一 batch

per-function batch → Task/Agent → Investigation Pipeline → gate → render
```

## File Structure

| 文件 | 改动 | 量 | Phase |
|------|------|----|-------|
| `skills/secguard/cpp/rules/*/rule.md` | signal_source 改为 callee 匹配 | 8 行 | P1 |
| `skills/secguard/{python,java,go,js}/rules/*/rule.md` | 对齐 callee 路由 | ~20 行 | P1 |
| `scripts/prefilter.py` | 新增确定性预筛器 | ~200 行 | P2 |
| `internal/main.go` | V1+V2 合并 | 8 行 | P3 |
| `internal/indexer/indexer.go` | 导出 GroupByFunction + MergeCallGraphs | ~40 行 | P3/P4 |
| `internal/parser/types.go` | 新增 FunctionCallContext 类型 | ~30 行 | P4 |
| `internal/context/context.go` | AnalysisContext 新增字段 | 5 行 | P4 |
| `scripts/partition-signals.py` | --group-by function 模式 | ~50 行 | P4 |
| `commands/{claude,opencode,gemini}/secguard.md` | 适配函数级上下文 prompt | ~20 行 | P4 |
| `scripts/self-check.sh` | 新增 prefilter 自检 + callee 路由校验 | ~15 行 | P1/P2 |
| `scripts/e2e-verify.sh` | 新增 per-function batch 验证 | ~15 行 | P4 |
| `docs/sdd/epics/EPIC-011-enforcement-integrity/epic.md` | 追加 FEATURE-007 | 5 行 | — |

## Tasks（TDD 驱动，每 Task 一次 commit）

### Phase 1: 精确路由（P1）

#### TASK-001: C++ callee 级 signal_source [TDD-V1]

**Goal**: 8 个 C++ memory 规则从 `cat="memory"` 改为 `callee="free|malloc|memcpy"` 等精确匹配

**Files Changed**:
- `skills/secguard/cpp/rules/double_free/rule.md` — `signal_source: call_sites[callee="free|delete"]`
- `skills/secguard/cpp/rules/null_dereference/rule.md` — `signal_source: call_sites[callee="malloc|calloc|realloc"]`
- `skills/secguard/cpp/rules/memory_leak/rule.md` — 同上
- `skills/secguard/cpp/rules/use_after_free/rule.md` — `signal_source: call_sites[callee="free|delete"]`
- `skills/secguard/cpp/rules/integer_overflow/rule.md` — `signal_source: call_sites[callee="malloc|calloc|realloc"]`
- `skills/secguard/cpp/rules/buffer_overflow/rule.md` — `signal_source: call_sites[callee="strcpy|strcat|sprintf|gets|scanf|fgets|memcpy|memmove|strncpy|snprintf|vsprintf"]`
- `skills/secguard/cpp/rules/mismatched_free/rule.md` — `signal_source: call_sites[callee="free|delete|malloc|calloc|realloc"]`
- `skills/secguard/cpp/rules/must_check/rule.md` — `signal_source: call_sites[callee="malloc|realloc|calloc|fopen|fread|fgets|scanf|gets"]`
- `skills/secguard/cpp/rules/api_semantic_misuse/rule.md` — `signal_source: call_sites[callee="realloc|memset|snprintf|strncpy|memcpy|memmove|strcpy_s|memcpy_s|scanf_s"]`

**Verification**:
```bash
# 1. 分区对比
python3 scripts/partition-signals.py --index .codeagent/secguardian/index.json --rules-dir ~/.config/opencode/extensions/secguardian/skills/secguard-cpp/rules --batch-size 20 --json | python3 -c "import json,sys; p=json.load(sys.stdin); print(f'assignments: {p[\"summary\"][\"partition_assignments\"]}')"
# 期望: assignments < 250（原 571）

# 2. 确认关键信号未被遗漏
python3 scripts/partition-signals.py --integration-test --index .codeagent/secguardian/index.json --rules-dir ~/.config/opencode/extensions/secguardian/skills/secguard-cpp/rules
# 期望: OK - real C++ index routes unsafe memcpy to memory.buffer_overflow

# 3. self-check
bash scripts/self-check.sh
# 期望: Passed: 120+, Failed: 0
```

#### TASK-002: 跨语言 callee 路由对齐 [TDD-V5]

**Goal**: Python/Java/Go/JS 的 rule.md frontmatter 对齐 callee 路由

**Verification**: `partition-signals.py --self-test` + 各语言 demo index 验证信号数不增加

---

### Phase 2: 确定性预筛（P2，C++ Tier 1 only）

#### TASK-003: prefilter.py 骨架 + null_dereference 预筛 [TDD-V2]

**Goal**: 新增 `scripts/prefilter.py`，消费 `pointer_validations` 做 null_dereference 预筛

**Files Changed**: `scripts/prefilter.py`（新增）

**算法**:
```python
for decl in index['declarations']:
    if decl['is_pointer']:
        # 找到该变量的 pointer_validations
        validations = [v for v in index['pointer_validations'] 
                       if v['variable'] == decl['name'] and v['function'] == decl.get('function')]
        if validations:
            for v in validations:
                if v['has_null_check'] and v['is_dereferenced']:
                    # 既有 NULL 检查又解引用了 → 安全（检查在解引用之前）
                    # 但 CFG 需要确认检查点支配解引用点
                    pass  # 需要 CFG 支配关系确认
```

**Verification**:
```bash
# self-test
python3 scripts/prefilter.py --self-test
# 期望: 所有 expected null_deref 漏洞信号 100% 通过（recall=1.0）

# 真实 index 验证
python3 scripts/prefilter.py --index examples/cpp-vuln-demo-no-answers/.codeagent/secguardian/index.json --rule null_dereference
# 期望: filtered < total（有实际过滤效果）
```

#### TASK-004: prefilter.py double_free/memory_leak 预筛 [TDD-V2]

**Verification**: 同上模式，人工标注的 expected-results 中 double_free/memory_leak 漏洞信号 100% 通过

#### TASK-005: prefilter.py buffer_overflow 三层写入校验 [TDD-V2]

**Goal**: 扩展 buffer_overflow 预筛，从"仅安全变体"升级为"容量追踪 + 写入校验 + 安全变体验证"

**算法**:
```python
# 第 1 层：构建容量表
capacities = {}
for decl in declarations:
    if decl.array_size > 0:
        capacities[(decl.file, decl.name, decl.function)] = decl.array_size

# 第 2 层：写入校验
for signal in filter_by_callee(call_sites, ['strcpy','strcat','sprintf','memcpy','memmove','gets','scanf']):
    dst = signal.arguments[0]
    capacity = lookup_capacity(capacities, signal.file, dst, signal.caller)
    if capacity > 0:
        write_size = estimate_write_size(signal)  # 从参数推导
        if write_size <= capacity:
            mark_safe(signal, f"写入量 {write_size} ≤ 容量 {capacity}")
        else:
            keep_for_llm(signal, f"可能溢出：写入量 {write_size} > 容量 {capacity}")

# 第 3 层：安全变体验证
for signal in filter_by_callee(call_sites, ['strcpy_s','sprintf_s','memcpy_s','strcat_s']):
    dst = signal.arguments[0]
    size_arg = extract_size_argument(signal)  # _s 函数的第二个参数
    capacity = lookup_capacity(capacities, signal.file, dst, signal.caller)
    if capacity == 0:  # decl not found → pointer/param/unknown
        keep_for_llm(signal, "缓冲区容量未知，无法验证 size 参数")
    elif is_sizeof_expression(size_arg, dst) and matches_capacity(size_arg, capacity):
        mark_safe(signal, f"sizeof({dst})={capacity} 匹配容量")
    elif is_sizeof_expression(size_arg, dst):  # sizeof 匹配但 dst 是指针
        keep_for_llm(signal, f"sizeof(ptr) = 指针大小，不是缓冲区容量 → 疑似误用")  # ★ 关键检测
    else:
        keep_for_llm(signal, "size 参数无法静态验证")
```

**关键检测场景**:
```c
// ✅ 预筛通过（栈数组 + sizeof 匹配）
char buf[64];
strcpy_s(buf, sizeof(buf), src);       // sizeof(buf)=64 == capacity=64

// ❌ 保留给 LLM（sizeof 作用于指针 → 虚假安全）
void handler(char *data) {
    strcpy_s(data, sizeof(data), src);  // sizeof(data)=8, 实际容量未知
}

// ⚠️ 保留给 LLM（size 参数不等于容量）
char buf[64];
strcpy_s(buf, 32, long_string);        // 容量64但只允许32 → 不必要的截断
```

**Verification**:
```bash
python3 scripts/prefilter.py --self-test
# 期望:
# - sizeof(stack_array) 匹配 → filtered
# - sizeof(ptr) on pointer param → NOT filtered, flagged
# - 写入量 ≤ 容量 → filtered
# - 写入量 > 容量 → NOT filtered
# - 容量未知 → NOT filtered（保守）
```

#### TASK-005b: prefilter.py lock_misuse/command_injection 预筛 [TDD-V2]

---

### Phase 3: 调用图修复（P3，所有语言）

#### TASK-006: V1+V2 调用图合并 [TDD-V3]

**Goal**: `main.go` 同时运行 V1 和 V2，合并去重

**Files Changed**:
- `internal/main.go` — 移除 if/else，改为两者都跑 + `MergeCallGraphs`
- `internal/indexer/indexer.go` — 新增 `MergeCallGraphs` 函数

**Verification**:
```bash
go test -tags cgo -run TestCallGraphV1V2Merge ./indexer/
# 期望: PASS — main→parse_task_name 出现在合并后的 call_graph 中

# 真实索引
secguardian-index --path examples/cpp-vuln-demo/src --lang c --output /tmp/test-v1v2.json
python3 -c "import json; cg=json.load(open('/tmp/test-v1v2.json'))['call_graph']['edges']; user_edges=[e for e in cg if e['callee'] not in {'malloc','free','memcpy','strcpy','sprintf','fopen','fclose','system','open','close','strcat','RAND_bytes','DES_set_key_unchecked','pthread_mutex_lock','pthread_mutex_unlock'}]; print(f'user→user edges: {len(user_edges)}')"
# 期望: user→user edges > 0
```

---

### Phase 4: 函数级上下文（P4，所有语言）

#### TASK-007: FunctionCallContext 类型 + 索引器导出 [TDD-V4]

**Goal**: 索引器新增 `GroupByFunction` 导出，返回 `FunctionCallContext` 列表

**Files Changed**:
- `internal/parser/types.go` — 新增 `FunctionCallContext` struct
- `internal/indexer/indexer.go` — 新增 `GroupByFunction` 函数
- `internal/context/context.go` — AnalysisContext 新增 `function_call_contexts` 字段
- `internal/main.go` — 写入 index.json 时包含新字段

**Verification**:
```bash
go test -tags cgo -run TestGroupByFunction ./indexer/
# 期望: release_entry 函数包含 2 个 free() call_sites

# 真实索引验证
secguardian-index --path examples/cpp-vuln-demo-no-answers/src --lang c --output /tmp/test-funcctx.json
python3 -c "
import json; idx=json.load(open('/tmp/test-funcctx.json'))
ctxs = idx.get('function_call_contexts', [])
release = [c for c in ctxs if c['function']=='release_entry']
print(f'release_entry contexts: {len(release)}')
if release:
    print(f'  callees: {release[0][\"callees\"]}')
    print(f'  call_sites count: {len(release[0].get(\"call_sites\",[]))}')
"
# 期望: release_entry callees 包含 free, call_sites 有 2 个
```

#### TASK-008: partition-signals --group-by function [TDD-V4]

**Goal**: `partition-signals.py` 新增 `--group-by function` 模式

**Files Changed**: `scripts/partition-signals.py` — 新增分组逻辑

**算法**: 当 `--group-by function` 时，遍历 `function_call_contexts`，对每个函数检查其 callees 是否匹配各 rule 的 signal_source。匹配则整个函数作为一个 batch。

**Verification**:
```bash
python3 scripts/partition-signals.py \
    --index examples/cpp-vuln-demo-no-answers/.codeagent/secguardian/index.json \
    --rules-dir ~/.config/opencode/extensions/secguardian/skills/secguard-cpp/rules \
    --batch-size 20 --group-by function --json | \
    python3 -c "import json,sys; p=json.load(sys.stdin); print(f'rules: {p[\"summary\"][\"rule_count\"]}, batches: {p[\"summary\"][\"batch_count\"]}')"
# 期望: batches < 20（原 32）
```

#### TASK-009: Investigation Pipeline 适配函数上下文 [TDD-V4]

**Goal**: 命令模板适配函数级 batch prompt，LLM 接收函数全景而非信号列表

**Files Changed**: `commands/{claude,opencode,gemini}/secguard.md` — batch prompt 模板适配

**Verification**: 手工验证 session log 中 Task prompt 包含 "FUNCTION: xxx" 而非 "SIGNALS: [sig-xxx, ...]"

---

### Phase 5: 跨语言适配 + 文档

#### TASK-010: 各语言 rule.md 对齐 [TDD-V5]

**Verification**: self-check.sh 多语言 smoke test + e2e-verify 跨语言不退化

#### TASK-011: prefilter.py + FunctionCallContext 打包

**Files Changed**: `scripts/package.sh`, `scripts/deploy.sh` — 确保新文件进入 dist

---

### Phase 6: 生产安全 + 集成验证

#### TASK-012: MAX_BATCHES 硬上限 + severity 优先调度 [TDD-V6]

**Goal**: partition-signals.py 新增 `--max-batches` 参数，超过上限时按严重度排序截断，剩余标记 `unprocessed`

**算法**:
```python
MAX_BATCHES = args.max_batches or 100

# 1. 先生成所有 batch（按 rule severity 排序：Critical > High > Medium）
all_batches = generate_all_batches(plan, severity_order=['Critical','High','Medium'])

# 2. 截断到上限
if len(all_batches) > MAX_BATCHES:
    plan['truncated'] = True
    plan['truncated_batches'] = len(all_batches) - MAX_BATCHES
    plan['truncation_reason'] = f'batch budget {MAX_BATCHES} exceeded'
    all_batches = all_batches[:MAX_BATCHES]

# 3. 截断的 batch 写入 coverage-gate unprocessed 标记
```

**Verification**:
```bash
# 构造 mock partition plan with 200+ batches
python3 scripts/partition-signals.py --self-test --max-batches 50
# 期望: 输出 "truncated: true, truncated_batches: 150+"
```

#### TASK-013: 全量回归 [TDD-V6]

```bash
bash scripts/self-check.sh    # 期望: 120+ pass, 0 fail
bash scripts/ci-check.sh      # 期望: 全部通过
bash scripts/e2e-verify.sh    # 期望: recall 不低于基线
```

#### TASK-014: OpenCode 实际扫描验证 [TDD-V1~V5 集成]

```bash
# 用户在 OpenCode 中执行:
/secguard examples/cpp-vuln-demo-no-answers/src cpp

# session log 验证清单:
□ partition-plan.json 中 assignments < 250（TDD-V1）
□ Phase 2 中每个 nonempty batch 是独立 Task（TDD-V4）
□ 父 dispatcher 上下文不含完整 partition-plan.json（崩溃链 #3）
□ 无 "complete remaining batches" 合并式 prompt（崩溃链 #2）
□ coverage-gate.py exit 0（崩溃链 #4 修复后无纯噪音 batch 遗漏）
□ 至少 1 个 batch 包含 per-function 上下文（TDD-V4）
```

---

## Verification Matrix

| Task | TDD 验收 | 命令 |
|------|---------|------|
| TASK-001 | V1: callee 路由无漏检 | `partition-signals.py --self-test` + assignments < 250 |
| TASK-003 | V2: 预筛保守性 | `prefilter.py --verify-against-ground-truth` recall=1.0 |
| TASK-006 | V3: 调用图 user→user | `go test -run TestCallGraphV1V2Merge` |
| TASK-007/008 | V4: 函数上下文 | release_entry 函数包含 2 个 free |
| TASK-002/010 | V5: 跨语言无退化 | self-check + e2e 多语言 |
| TASK-012 | V6: 无回归 | self-check + ci-check + e2e-verify 全部通过 |
