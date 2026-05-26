# CodePlan v2 — Executable Implementation Plan

> Status: **Ready for execution**
> Reference: `CodePlanV2.md` (analysis & rationale)
> Coordinates with: `docs/work-plan.md` (business milestones)

---

## Why This Refactor Matters (The Customer Perspective)

Before writing a single line of code, let's be clear about what the customer sees after this refactor:

**Before:**
```
User: /secguard ./src memory.*
→ AI reads entire repo from scratch × 12 detectors
→ Each detector re-reads the same files independently  
→ Output: findings with no confidence labels
→ Cost: ~50K tokens per scan (uncontrollable)
→ FP rate: unknown but likely 50%+ (no deterministic validation)
```

**After:**
```
User: /secguard ./src memory.*
→ Indexer runs once (tree-sitter parses all C/C++ files → symbol index + call graph)
→ Memory-group detectors share a single AnalysisContext
→ AI receives structured context (not raw files) → more accurate reasoning
→ Deterministic validators verify AI claims before output
→ Output: findings with confidence scores (high/medium/low)
→ Cost: ~15K tokens per scan (predictable)
→ FP rate: target <30% for high-confidence findings
```

**The competitive advantage this creates:**

| | Before | After | World-class threshold |
|---|--------|-------|----------------------|
| FP rate (high-confidence) | Unknown | <30% | CodeQL: 15-25% |
| Token cost per scan | O(N×M) | O(M + N) | Semgrep: free (open-source) |
| Scan time (100-file repo) | 10+ min | <3 min | SonarQube: 2-5 min |
| PR-level scan | Not supported | <30 sec | CodeQL: 30-60 sec |
| Findings confidence | None | high/medium/low | Snyk: has triage labels |
| True differentiation | AI reasoning depth (only we have this) | AI depth + engineering rigor | N/A — no competitor has both |

**What NOT to change (our moat):**
- ❌ Do NOT replace AI reasoning with pattern matching (defeats our purpose)
- ❌ Do NOT collapse secaudit/secaudit/secreview into one flat scanner (our architecture is our differentiator)
- ❌ Do NOT reduce detector depth to "lightweight evaluators" (our 4-step detection logic is what customers pay for)

---

## Phase 1: Semantic Foundation (P0)

**Goal**: Give AI structured code understanding so it reasons about code, not reads raw files.

**Commercial value**: This single phase cuts FP rate by ~30% and token cost by ~40%. It's the difference between "toy project" and "production tool."

### Implementation Checklist

- [ ] **1.1 Project bootstrap** — Create `internal/` Go module structure
  - Files: `internal/go.mod`, `internal/main.go` (CLI entry)
  - Test: `go build ./...` passes
  - **Why**: Go is the right language for this — tree-sitter Go bindings are mature, builds to a single binary, no runtime dependencies

- [ ] **1.2 Tree-sitter C parser integration**
  - Files: `internal/parsers/c_parser.go`
  - Dependencies: `github.com/tree-sitter/go-tree-sitter`, `github.com/tree-sitter/tree-sitter-c`
  - Capabilities: Parse C file → extract function definitions, variable declarations, struct types
  - Test: Parse `examples/cpp-vuln-demo/src/parser.c` → output 3 functions (main, parse_input, process_buffer)
  - **Why C first**: Our most critical detectors (buffer-overflow, use-after-free, double-free) target C/C++

- [ ] **1.3 Tree-sitter C++ parser integration**
  - Files: `internal/parsers/cpp_parser.go`
  - Dependencies: `github.com/tree-sitter/tree-sitter-cpp`
  - Extends C parser with: class definitions, template functions, destructor recognition
  - Test: Parse `examples/cpp-vuln-demo/src/allocator.c` → detect `malloc` and `free` calls

- [ ] **1.4 Symbol extractor**
  - Files: `internal/indexer/symbol_extractor.go`
  - Input: Parsed AST tree
  - Output: `SymbolIndex{functions: [], variables: [], types: [], macros: []}`
  - Each entry: `{name, file, start_line, end_line, signature, return_type}`
  - Test: Extract symbols from all 3 C demo files → verify `parse_input` found at parser.c:15

- [ ] **1.5 Call graph builder (lightweight)**
  - Files: `internal/indexer/call_graph.go`
  - Approach: 1-level call graph only (who calls whom, no inter-procedural data flow)
  - Output: `CallGraph{edges: [{caller, callee, file, line}]}`
  - Test: `allocator.c:main → allocator.c:allocate_buffer` detected
  - **Why lightweight**: We're NOT building CodeQL's data flow engine. AI should do the reasoning; tree-sitter should do the structure.

- [ ] **1.6 Alloc/free matcher**
  - Files: `internal/indexer/alloc_free.go`
  - Pattern: For every `malloc/calloc/realloc/new`, find all `free/delete` in the same function
  - Output: `AllocFreeMap{pairs: [{alloc, frees[]}]}`
  - Test: `allocator.c: malloc at line 12 → free at line 25` detected

- [ ] **1.7 Lock usage graph**
  - Files: `internal/indexer/lock_graph.go`
  - Pattern: `pthread_mutex_lock/unlock`, `std::mutex::lock/unlock`
  - Output: `LockGraph{usages: [{mutex, lock_line, unlock_line}]}`
  - Test: Parse C file with mutex → detect lock/unlock pairs

- [ ] **1.8 AnalysisContext assembler**
  - Files: `internal/context/analysis_context.go`
  - Orchestrates: parser → symbol_extractor → call_graph → alloc_free → lock_graph
  - Output: `AnalysisContext` struct (the "scan once" artifact)
  - CLI: `secguardian-index --path ./src --output .codeagent/index.json`
  - Test: Run on `examples/cpp-vuln-demo/src/` → produces valid `index.json`

- [ ] **1.9 Prompt injection bridge**
  - Files: `scripts/secguardian.sh` (update)
  - New behavior: Before running any detector, check if `index.json` exists → if yes, inject structured context into prompt instead of raw files
  - Prompt format: 
    ```
    ## Code Context (pre-indexed)
    - Functions in scope: [parse_input (line 15-42), process_buffer (line 44-68)]
    - Allocations: malloc at parser.c:18, freed at parser.c:38
    - Call graph: main → parse_input → strcpy
    ```
  - Test: Run `/secguard scan --path examples/cpp-vuln-demo/src` → AI receives structured context, not raw files

- [ ] **1.10 Python parser (quick win for web security)**
  - Files: `internal/parsers/py_parser.go`
  - Dependencies: `github.com/tree-sitter/tree-sitter-python`
  - Capabilities: Function defs, imports, decorators, string formatting patterns
  - Test: Parse `examples/python-vuln-demo/src/webapp.py` → extract route handlers

- [ ] **1.11 Go parser**
  - Files: `internal/parsers/go_parser.go`
  - Dependencies: `github.com/tree-sitter/tree-sitter-go`
  - Test: Parse `examples/go-vuln-demo/src/execlike.go` → extract functions

- [ ] **1.12 Java parser**
  - Files: `internal/parsers/java_parser.go`
  - Dependencies: `github.com/tree-sitter/tree-sitter-java`
  - Test: Parse `examples/java-vuln-demo/src/AuthController.java` → extract class + methods

**Acceptance criteria for Phase 1 completion:**
1. `secguardian-index --path ./src` produces valid `index.json`
2. AI prompt for buffer-overflow detector includes pre-computed buffer sizes (not raw file)
3. AI prompt for use-after-free detector includes pre-computed alloc/free pairs
4. `tools/check.sh` still passes
5. Existing `scripts/build.sh cc` workflow not broken

**Estimated effort**: 5-7 days for core (C/C++), +2 days for Python/Go/Java

---

## Phase 2: Token Budget & Prompt Architecture (P0)

**Goal**: Make every API token count. Cut cost by 50% without losing reasoning quality.

**Commercial value**: At $2K/year Pro pricing, per-scan token cost must be <$0.50 to maintain 80%+ margin. Current cost is ~$2-3/scan (unprofitable).

### Implementation Checklist

- [ ] **2.1 System prompt template**
  - File: `knowledge/prompt-templates/system.md`
  - Content: Immutable rules only (scan-output protocol, SARIF rules, reflection checklist)
  - Token target: <500 tokens (currently ~2000 tokens)
  - **Why immutable**: Can be cached by LLM providers (prefix caching = 90% cost reduction)

- [ ] **2.2 Skill prompt templates**
  - Files: `knowledge/prompt-templates/skill-secguard.md`, `knowledge/prompt-templates/skill-secaudit.md`, `knowledge/prompt-templates/skill-secreview.md`
  - Content: Command-specific instructions only (no protocol repetition, no generic rules)
  - Token target: <300 tokens per skill

- [ ] **2.3 Context prompt builder**
  - Files: `internal/prompt/context_builder.go`
  - Input: `AnalysisContext` + target `file:line`
  - Output: Context slice containing only:
    - Target function (±10 lines context)
    - 1-hop callers and callees
    - Relevant symbol definitions (types, macros)
  - Token target: <1000 tokens per skill execution

- [ ] **2.4 Token budget calculator**
  - Files: `internal/budget/calculator.go`
  - Function: Estimate tokens before execution → warn if exceeds budget → suggest scope reduction
  - Budget defaults: secguard = 8000 tokens/scan, secaudit = 15000 tokens/audit

- [ ] **2.5 Update CLI to use layered prompts**
  - Files: `scripts/secguardian.sh` (update)
  - New flow: System → Skill → Context (three files) instead of one monolithic `.system_prompt.md`
  - Test: verify scan output identical in format to pre-refactor

**Acceptance criteria:**
1. Single detector execution uses <3000 total tokens (system + skill + context)
2. Scan output quality unchanged from pre-refactor
3. `tools/check.sh` passes

**Estimated effort**: 3-4 days

---

## Phase 3: Confidence & Reflection Pipeline (P1)

**Goal**: Every finding carries a confidence label. Users can filter to high-confidence only.

**Commercial value**: This is the most visible customer-facing improvement. A CTO who sees "12 high-confidence findings" will pay. A CTO who sees "87 findings, no idea which are real" won't.

### Implementation Checklist

- [ ] **3.1 Path validator**
  - Files: `internal/reflection/path_validator.go`
  - Check: For each finding at `file:line`, does the referenced code path actually exist?
  - Test: AI claims "use-after-free at parser.c:42" → validator confirms line 42 exists and contains a pointer dereference after free

- [ ] **3.2 Symbol validator**
  - Files: `internal/reflection/symbol_validator.go`
  - Check: For each finding referencing `symbol X`, does X exist in the symbol index?
  - Test: AI claims "strcpy overflow" → validator confirms `strcpy` is called at that line

- [ ] **3.3 Deduplication engine**
  - Files: `internal/reflection/dedupe.go`
  - Logic: Same `file:line` + same CWE → merge into one finding with combined evidence
  - Test: Two detectors flag the same `malloc` line → output one finding with both detector references

- [ ] **3.4 Confidence scorer**
  - Files: `internal/reflection/confidence.go`
  - Algorithm: Evidence-based weighted scoring
    ```
    score = 0
    +30 if path_validator passes
    +30 if symbol_validator passes
    +20 if exploit chain is complete (source → sink)
    +20 if remediation is actionable
    ---
    >=80 → high
    >=50 → medium
    <50  → low
    ```
  - Test: Verified path + verified symbol + complete chain = high confidence

- [ ] **3.5 Severity mapper**
  - Files: `internal/reflection/severity.go`
  - Logic: CWE base severity + context modifier
    - If CWE is critical BUT code is in `test/` directory → downgrade to medium
    - If CWE is high AND code is in production handler → confirm high

- [ ] **3.6 Update finding schema**
  - Files: `knowledge/protocols/scan-output.md` (update)
  - Add field: `confidence: {level, score, evidence: [path_verified, symbol_verified, chain_complete]}`
  - Add field: `reflection: {validators_passed: [path, symbol], deduplicated_from: []}`

- [ ] **3.7 Update SARIF output**
  - Files: `knowledge/protocols/sarif-output.md` (update)
  - Map confidence to SARIF `properties.confidence`
  - Add `partialFingerprints` for GitHub result tracking

**Acceptance criteria:**
1. Every finding has `confidence` field populated
2. High-confidence findings have ≥80% precision on examples/
3. Users can filter findings by `confidence:high`

**Estimated effort**: 4-5 days

---

## Phase 4: Execution Scheduler (P2)

**Goal**: Grouped detectors share context. 12 memory detectors → 1 shared index read.

**Commercial value**: Scan time reduction makes PR-level CI/CD scanning viable. "30-second PR scan" is a sales feature.

### Implementation Checklist

- [ ] **4.1 Analysis group definitions**
  - Files: `skills/secguard-cpp/references/detector-index.md` (update)
  - Add `analysis_group` field to each detector entry
  - Groups: memory, bounds, concurrency, system, crypto

- [ ] **4.2 Skill scheduler**
  - Files: `internal/scheduler/scheduler.go`
  - Logic: Group detectors by `analysis_group` → execute group sequentially, detectors within group in parallel (if stateless) or sequentially (if stateful)
  - Test: Schedule all 12 memory detectors → verify they share one AnalysisContext

- [ ] **4.3 Group context builder**
  - Files: `internal/scheduler/group_context.go`
  - Logic: For memory group → pre-load all alloc/free maps. For bounds group → pre-load all buffer sizes.
  - Test: Memory group execution time < sum of individual detector times

- [ ] **4.4 Update CLI**
  - Files: `scripts/secguardian.sh` (update)
  - `scan` command now respects `analysis_group` ordering

**Acceptance criteria:**
1. Grouped detectors execute in shared context
2. Token consumption further reduced 20%+ vs Phase 2 baseline
3. CLI syntax unchanged (`/secguard ./src memory.*` still works)

**Estimated effort**: 3-4 days

---

## Phase 5: Incremental Scan (P2)

**Goal**: PR-level scans that only analyze changed code.

**Commercial value**: GitHub Action "scan on push" becomes practical. Without this, CI/CD integration is just documentation.

### Implementation Checklist

- [ ] **5.1 Git diff parser**
  - Files: `internal/indexer/diff_parser.go`
  - Input: `git diff HEAD~1` output
  - Output: Changed files + line ranges + change type (add/modify/delete)

- [ ] **5.2 Incremental reindexer**
  - Files: `internal/indexer/incremental.go`
  - Logic: For changed functions only → re-extract symbols, rebuild call graph edges, recalculate alloc/free pairs
  - Unchanged functions → reuse existing index

- [ ] **5.3 Scope limiter**
  - Files: `internal/indexer/scope_limiter.go`
  - Logic: For incremental scan → constrain each detector to: changed_lines + callers (1 level up) + callees (1 level down)

- [ ] **5.4 CLI update for incremental mode**
  - Files: `scripts/secguardian.sh` (update)
  - `scan --path ./src --mode git-diff --ref HEAD~1` → triggers incremental flow
  - Test: `git diff HEAD~1` on a 2-file change → scan time <30 seconds

**Acceptance criteria:**
1. Incremental scan only analyzes changed functions
2. Results identical to full scan for changed code
3. Existing unchanged findings preserved from previous scan

**Estimated effort**: 3-4 days

---

## Phase 6: Knowledge Base Evolution (P2, ongoing)

**Goal**: Close CWE Top 25 and OWASP Top 10 coverage gaps.

**Commercial value**: Customer comparison sheets show "80% coverage" vs "44% coverage." This closes sales.

### Implementation Checklist

- [ ] **6.1 Web security detectors**
  - New files: `knowledge/detectors/{xss,csrf,ssrf,open-redirect,ssti,xxe,idor,auth-bypass,jwt-misuse}.md`
  - Priority order (by market demand): SQLi (done) → XSS → SSRF → Deserialization → CSRF → Auth bypass
  - Each detector: 4-step detection logic, language-specific API patterns, FP exclusion table

- [ ] **6.2 New security concepts**
  - New files: `knowledge/concepts/{csrf,open-redirect,jwt-security}.md`
  - Each concept: detection strategy, patterns, remediation guidance

- [ ] **6.3 Annotated examples**
  - New files: Add corresponding vulnerability code to `examples/` for each new detector
  - Test: Run secguard on new examples → detect all annotated vulnerabilities

- [ ] **6.4 Update benchmarks**
  - Update `scripts/benchmark.sh` to include new detectors
  - Recalculate CWE Top 25 coverage (target: 80%)

**Acceptance criteria:**
1. CWE Top 25 coverage ≥ 80% (from current 44%)
2. OWASP Top 10 coverage ≥ 80% (from current 15%)
3. New detectors maintain same quality standard (FP exclusion table, pattern summary)

**Estimated effort**: 5-7 days (mostly knowledge authoring, not code)

---

## Execution Order & Dependencies

```
Week 1-2:  Phase 1 (Semantic Foundation)          ← START HERE
Week 2-3:  Phase 2 (Token Budget)                 ← Depends on Phase 1
Week 3-4:  Phase 3 (Confidence & Reflection)      ← Depends on Phase 1
Week 4-5:  Phase 4 (Execution Scheduler)          ← Depends on Phase 3
Week 5-6:  Phase 5 (Incremental Scan)             ← Depends on Phase 4
Ongoing:   Phase 6 (Knowledge Evolution)          ← Independent of 1-5
```

## What We Will NOT Do

| Competitor's approach | Our decision | Why |
|----------------------|-------------|-----|
| skill → lightweight rule evaluator | ✗ Reject | Our AI reasoning depth IS the product |
| Deterministic-only reflection | △ Partial adopt | Use for path/symbol validation; keep AI for exploitability reasoning |
| Native C/C++ only | ✗ Reject | Our Java/Python/Go coverage opens the Web security market |
| Collapse into flat scanner | ✗ Reject | Our 3-tier architecture (secguard/secaudit/secreview) is our strongest differentiator |
| Rewrite all skills as engine plugins | ✗ Reject | Knowledge base in Markdown is our moat — it's what makes us AI-native, not just another SAST tool |

## Success Metrics (Track These)

| Metric | Current | Phase 1 Target | Phase 3 Target | Final Target |
|--------|---------|---------------|---------------|-------------|
| FP rate (high-confidence) | Unknown | N/A | <30% | <25% |
| Token cost/scan | ~50K | ~30K | ~20K | <15K |
| Scan time (100 files) | 10+ min | 5 min | 3 min | <2 min |
| PR-level scan time | N/A | N/A | N/A | <30 sec |
| CWE Top 25 coverage | 44% | 44% | 44% | 80% |
| OWASP Top 10 coverage | 15% | 15% | 15% | 80% |
| Findings with confidence | 0% | 0% | 100% | 100% |

---

## Coordination with docs/work-plan.md

This CodePlan takes priority over the original `docs/work-plan.md` Phase 2 tasks. Updated priority:

```
1. CodePlan Phase 1: Semantic Foundation     ← NEW P0 (was: work-plan P0-1)
2. CodePlan Phase 2: Token Budget            ← NEW P0
3. CodePlan Phase 3: Confidence & Reflection ← NEW P1
4. work-plan P0-1: AI audit on examples/    ← deferred (needs Phase 1 for meaningful data)
5. work-plan P0-2: Real OSS project audits   ← deferred
6. work-plan P0-3: CWE coverage gaps         ← now CodePlan Phase 6
```
