# SecGuardian Execution Strategy: Signal-LLM Collaboration

> **Document**: Execution strategy definition — how deterministic signals and LLM reasoning collaborate
> **Status**: Current system — no separate Engine binary exists
> **Updated**: 2026-07-05 (EPIC-005 R2 — Signal-LLM collaboration model)

---

## 1. What This Document Defines

SecGuardian's execution strategy consists of two collaborating layers within a single pipeline:

```
┌──────────────────────────────────────────────┐
│         EXECUTION STRATEGY LAYER              │
│                                               │
│  ┌─────────────────┐  ┌──────────────────┐   │
│  │ 确定性信号层      │  │  LLM 推理层       │   │
│  │ (Deterministic   │  │ (LLM Reasoning)  │   │
│  │  Signals)        │  │                  │   │
│  │                  │  │                  │   │
│  │ 来源: 索引器     │  │ 来源: AI Agent   │   │
│  │ 角色: 锚定/预筛  │  │ 角色: 语义分析   │   │
│  │       /去重      │  │       补丁生成   │   │
│  └────────┬─────────┘  └────────┬─────────┘   │
│           └──────────┬───────────┘             │
│                      ▼                         │
│               findings.json                    │
└──────────────────────────────────────────────┘
```

There is **no separate Security Engine binary**. The execution strategy is how
the existing indexer (producing deterministic signals) and AI Agent (performing
LLM reasoning) collaborate within the pipeline.

This document defines: what each layer does, what constraints bind the LLM,
and how the deterministic signal layer evolves over time.

---

## 2. Deterministic Signal Layer

### 2.1 What It Is

The signal layer is the **deterministic, code-derived information** produced by
`secguardian-index`. It exists today. It is not a separate system or component.

### 2.2 Current Signals

| Signal | Source | Quality | Role in Scanning |
|--------|--------|---------|-----------------|
| `symbols.functions` | Tree-sitter / Regex parse | ✅ Reliable | Anchor findings to function definitions |
| `symbols.variables` | Tree-sitter / Regex parse | ✅ Reliable | Anchor findings to variable declarations |
| `symbols.types` | Tree-sitter / Regex parse | ✅ Reliable | Anchor findings to type/struct/class definitions |
| `call_graph.edges` | Text-approximate matching | ⚠️ Same-file only | Scope detector applicability (caller→callee chains) |
| `alloc_free.pairs` | Text scanning | ⚠️ Same-file only | Memory leak candidate generation |
| `lock_graph.mutexes` | Text scanning | ⚠️ Same-file only | Lock misuse candidate generation |

### 2.3 What the Signal Layer Does

| Role | Description | Example |
|------|-------------|---------|
| **Anchor** | Every finding must reference an index symbol or file+line | Finding at `main.c:88` must correspond to a symbol in `symbols.functions` or `symbols.variables` |
| **Pre-filter** | Scope detector applicability based on signal presence | No `malloc`/`free` symbols → skip memory-leak detector |
| **De-duplicate** | Merge findings that hit the same code location | Two detectors flagging the same `strcpy` call → one merged finding |

### 2.4 What the Signal Layer Does NOT Do

- **Does NOT independently detect vulnerabilities** — It identifies *candidates* based on patterns. Semantic analysis (is this actually exploitable?) is the LLM's role.
- **Does NOT make security decisions** — It flags patterns. Only human reviewers (or LLM with full context) can confirm exploitability.
- **Does NOT replace the LLM** — It reduces noise and provides anchors. The LLM remains the primary analysis engine.

---

## 3. LLM Reasoning Layer

### 3.1 What It Is

The LLM reasoning layer is the AI Agent (Claude, Gemini, OpenCode, etc.) processing
detector rules against code context. It is the **primary analysis engine** today.

### 3.2 What the LLM Excels At

| Capability | Why It Matters |
|------------|---------------|
| Semantic understanding | Detecting logic-level vulnerabilities that pattern matching would miss |
| Context reasoning | Understanding cross-function data flow without static analysis |
| Business logic analysis | Identifying auth bypass, race conditions, input validation gaps |
| Patch generation | Producing context-aware fixes, not just flagging issues |
| Explanation | Generating human-readable vulnerability narratives |

These are capabilities that traditional SAST tools cannot provide. They are
SecGuardian's core differentiator.

### 3.3 Hard Constraints

The LLM's reasoning power is not unrestricted. Two constraints ensure
traceability and verifiability:

#### Anchor Constraint

> Every finding's `location` field **MUST** reference a symbol or file+line
> present in `index.json`.

```json
{
  "location": {
    "file": "src/auth.c",
    "line": 142,
    "symbol": "validate_token"  // ← must exist in index.json symbols.functions
  }
}
```

If the LLM identifies a vulnerability at a location that has no corresponding
index symbol, it must either:
- Mark the finding as `confidence: low` and explain why the index didn't capture it
- Re-examine whether the finding is valid (index absence is a strong signal)

#### Evidence Constraint

> Every finding's `evidence` field **MUST** quote the specific code snippet
> that demonstrates the vulnerability.

```json
{
  "evidence": "At auth.c:142, user_input is passed to strcpy without bounds check:\n  strcpy(buffer, user_input);\nNo size validation precedes this call."
}
```

The evidence must be independently verifiable by a human reviewer reading
the quoted code. "Pattern-based inference" without a concrete code quote
is not acceptable.

### 3.4 What the LLM Should NOT Do

- Produce findings with no trace to any index symbol (violates anchor constraint)
- Produce findings with no code evidence (violates evidence constraint)
- Skip detectors arbitrarily without recording the skip reason
- Fabricate index data (e.g., claiming a function call exists when index doesn't show it)

Note: the LLM **can** identify vulnerabilities that traditional SAST would miss
(e.g., logic flaws, race conditions, auth bypass). These simply need to be
anchored to the relevant code location and backed by evidence.

---

## 4. Signal Enhancement Roadmap

The quality of signal-layer anchoring and pre-filtering improves with each
indexer enhancement. This is a progressive path, not a big-bang migration.

### v0.14: Cross-File Call Graph + Type Hierarchy

| Enhancement | Today | Target |
|-------------|-------|--------|
| Cross-file call graph | `strings.Contains` within same file | Global symbol table matching across all files |
| Type hierarchy | Names only, no relationships | Inheritance chains (C++/Java), interface implementations, Go embedding |

**Impact on scanning**: Detectors that need call-chain analysis (e.g., taint
tracking from user input to sensitive sink) get more accurate pre-filtering.
Type-based detectors (e.g., unsafe type casting) get reliable type information.

### v0.15: Data-Flow Pre-Analysis

| Enhancement | Today | Target |
|-------------|-------|--------|
| Source-sink pairing | Not available | Function parameter → sensitive operation mapping |
| Variable reachability | Not available | Which functions can reach which variable assignments |

**Impact on scanning**: Pre-filter can identify "this function's output reaches
a sensitive sink" vs "this function is isolated." LLM gets scoped, relevant
context rather than entire file contents.

> ⚠️ **Research phase**: Data-flow analysis may require an IR layer beyond
> what Tree-sitter AST provides. This milestone is aspirational — it will
> be re-evaluated after v0.14 signals are validated in production.

### v0.16+: CI Fast Gate

When signal quality is sufficient, CI can run a **fast gate** without LLM:
1. Anchor check: do all findings have valid index anchors?
2. Pre-filter match rate: what % of findings were pre-flagged by signals?
3. De-duplication: are there duplicate findings at the same location?

The fast gate does **not** replace the LLM scan. It provides a quick "hygiene
check" before the full pipeline runs.

---

## 5. Knowledge Consumption

### Current: Markdown → LLM

```
knowledge/detectors/*.md  ──→  skill loads as prompt text  ──→  LLM interprets rules
```

Detector rules are loaded as Markdown text into the LLM's context window.
The LLM interprets each rule's definition, detection pattern, and examples.
No structured parsing happens before the LLM.

This approach **works today** and will remain the primary consumption mode.
It is simple, authorable, and leverages the LLM's ability to understand
natural-language rules.

### Future: Signals + Markdown → LLM

```
deterministic signals (index.json)  ──→  pre-filter + anchor candidates
                                             │
knowledge/detectors/*.md  ──→  LLM interprets rules against candidates
                                             │
                                             ▼
                                      findings.json (anchored)
```

The signal layer narrows the scope. The LLM still does the analysis.
No DSL, no structured rule format change, no rule compiler.

---

## 6. Integration Points

### AI Agent → Strategy

```
Agent reads command definition → loads skill (detector selection)
         ↓
Agent receives index.json (deterministic signals)
         ↓
LLM processes rules against signals → produces anchored findings
```

### CLI → Strategy

```
secguardian-index → index.json (signals)
         ↓
AI Agent loads signals + rules → LLM execution → findings → output layer
```

### CI → Strategy

CI does not inject into or modify the execution strategy. CI evaluates
the artifacts the pipeline produces. In the future (v0.16+), CI may use
deterministic signals for a fast gate check before the full LLM scan.

See [runtime-model.md](runtime-model.md) for CI as verification constraint layer,
[architecture-vNext.md](architecture-vNext.md) for the full evolution path,
and [engineering-principles.md](engineering-principles.md) EP-6 for the
one-pipeline constraint.

---

## 7. CRITICAL WARNING

> **Do not build a separate Security Engine binary.**
>
> The execution strategy is a collaboration between two existing components:
> the indexer (producing deterministic signals) and the AI Agent (performing
> LLM reasoning). There is no gap that requires a third component.
>
> A separate Engine binary would:
> - Create a parallel execution path that diverges from LLM output
> - Require an IR layer the indexer cannot currently provide
> - Abstract an interface before a second strategy exists (violates EP-1)
> - Add maintenance burden without improving detection quality
>
> Instead, invest in the indexer: cross-file call graphs, type hierarchies,
> data-flow pre-analysis. These are concrete, verifiable improvements that
> make both deterministic pre-filtering and LLM reasoning more effective.

---

## 8. Commitments

| Commitment | Rationale |
|-----------|-----------|
| No separate Security Engine binary | Indexer + AI Agent already provide the two collaborating layers |
| No Engine interface/API | The collaboration is data-driven (index.json → findings.json), not API-driven |
| No DSL for detector rules | Markdown is authorable, LLM-understandable, and sufficient today |
| No dual execution path | One pipeline: indexer → signals + LLM → findings → renderer |
| Signal enhancement over engine abstraction | Improve the indexer's output; don't abstract execution behind interfaces |
| LLM constraints: anchor + evidence | Ensure traceability without limiting LLM's intelligence |

---

## 9. Related Documents

- [architecture-vNext.md](architecture-vNext.md) — Full architecture overview + evolution phases
- [runtime-model.md](runtime-model.md) — Single-pipeline execution + CI fast gate
- [design-principles.md](design-principles.md) — ADR-007 (Signal-LLM model) + ADR-008 (Progressive Enhancement)
- [engineering-principles.md](engineering-principles.md) — EP-1 (Signal Anchoring) + EP-1~EP-7 full constraints
- [execution-model-current.md](execution-model-current.md) — Current pipeline stage breakdown
- `internal/engine/engine_contract.md` — Execution strategy contract (anchor + evidence + pre-filter rules)
- `internal/output/output_contract.md` — Output formatting contract
- [ci-cd-interface.md](../ci-cd-interface.md) — CI/CD artifact consumption contract
