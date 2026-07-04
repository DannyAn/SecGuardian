# SecGuardian Execution Strategy Layer

> **Document**: Strategy Definition — NOT a system design
> **Status**: Current system ONLY implements LLM-assisted strategy
> **Updated**: 2026-07-04 (Round 2 review — added deterministic pre-pass authority,
>   current deterministic signals, LLM role constraints)

---

## 1. Why a Strategy Layer (Not a System)

The original "Security Engine" design assumed a deterministic execution kernel
that could operate independently of an LLM. That assumption is premature.

Current reality:
- No engine runtime exists
- No execution isolation layer exists
- No rule compiler exists
- No AST IR layer exists
- All detection logic is prompt-driven reasoning, not pattern matching

What exists today is an **execution strategy**: the way the system chooses to
execute security analysis. Currently it is LLM-assisted. In the future it
could be deterministic. But neither is a "system" — they are strategies.

This document defines the strategy layer: what it is, what is current,
what direction is possible, and where the boundaries are.

---

## 2. Current State: LLM-Assisted Strategy

### How It Works

The current execution path is:

```
indexer → knowledge rules (Markdown) → LLM execution (single pass) → findings → renderer
```

The LLM is not a plugin. The LLM **is** the execution engine.
All detection logic, rule matching, and finding generation runs inside
the LLM's reasoning process, guided by:
- The skill file's prompts (SKILL.md)
- The detector rules loaded from knowledge/detectors/
- The index.json context

### Current Reality

| Aspect | Reality |
|--------|---------|
| Rule format | Markdown knowledge base, unstructured |
| Detection logic | LLM prompt-driven reasoning |
| Finding generation | LLM outputs JSON via tool calls |
| Rule matching | LLM reads index.json + rule context, reasons about matches |
| False positive control | LLM heuristic (not algorithmic) |
| Determinism | Low — output varies per LLM run |
| Testability | Cannot unit-test without LLM |

This works today. It is the product's core value: LLM-driven security scanning
that is **controllable, verifiable, and implementable**.

---

## 3. Current Deterministic Signals

The system already contains deterministic signals that are independent of
LLM reasoning. These are not future features. They are **current** candidate
generation inputs that the indexer already produces and the LLM already
consumes.

| Signal | Source | What It Represents |
|--------|--------|-------------------|
| `index.json: symbols.functions` | Tree-sitter / Regex parse | All function definitions with file + line ranges |
| `index.json: symbols.variables` | Tree-sitter / Regex parse | Global variable declarations |
| `index.json: symbols.types` | Tree-sitter / Regex parse | Struct, class, enum definitions |
| `index.json: call_graph.edges` | Text-approximate call graph | Caller → callee relationships with file + line |
| `index.json: alloc_free.pairs` | In-file text matching | malloc sites with optional corresponding free sites |
| `index.json: lock_graph.mutexes` | In-file text scanning | lock/unlock locations with file + line |
| `knowledge/detectors/*.md` | Version-controlled Markdown | 67 detector rules across 7 security namespaces |

These signals exist today. They are produced by `secguardian-index` and loaded
by the LLM at scan time. They are deterministic per codebase state.

### What This Means

Because these signals are deterministic:
- The **candidate space** (what could be a vulnerability) is bounded by the
  index's content
- A function not in `symbols.functions` cannot have call edges
- A variable not in `symbols.variables` cannot be part of an alloc/free pair
- The index defines what is analyzable; the LLM operates within that scope

---

## 4. Deterministic Pre-Pass Authority

### Core Constraint

> The deterministic pre-pass (index-driven candidate generation) is
> **authoritative**.

This means:
- The set of vulnerability candidates is defined by what the index contains
  combined with detector rule patterns — NOT by LLM reasoning
- LLM receives these candidates from the index context; it does not invent
  new candidates outside what the index contains
- If the index does not contain a relevant symbol (e.g., a function call,
  a variable assignment), the LLM cannot retroactively introduce it

This constraint exists because the index is the **only structured,
deterministic view of the codebase**. Any finding that cannot be traced
to an index entry has no verifiable evidence chain and should not be
actionable.

### LLM Role Constraints

```
LLM MAY:
  - validate candidates against detector rules
  - explain why a candidate is or is not a vulnerability
  - generate fix patches for confirmed findings
  - reduce false positives from candidate set

LLM MAY NOT:
  - introduce new findings outside index-derived candidate space
  - override candidate determination constraints
  - produce findings without index evidence
```

### Practical Example

```
Pre-pass (deterministic):
  index.json shows: alloc at line 88 in src/main.c, no matching free
                    → candidate: "possible memory leak at main.c:88"

LLM (validation):
  Reads the candidate, checks function scope, identifies if free
  happens via a wrapper or cleanup function
  → confirms: "memory leak at main.c:88"
  → explains: "malloc return not freed in error path"
  → generates: fix patch

Without pre-pass constraint:
  LLM might find "memory leak" at line 88 based on prompt
  → no traceable evidence
  → cannot verify whether index actually has this alloc
  → diff between runs produces inconsistent findings
```

---

## 5. Future Direction: Deterministic Strategy

It is possible that parts of the current LLM-assisted strategy can be
replaced with deterministic rule matching. This is a **research direction**,
not an implementation plan.

### What This Means

A future deterministic strategy would:
- Take structured rule definitions (YAML/JSON) instead of Markdown prose
- Match rules against index.json programmatically (regex, AST patterns)
- Produce deterministic findings without LLM variability
- Feed deterministic findings to LLM for explanation + patch (optional)

### What This Does NOT Mean

- It does NOT mean building a separate engine service
- It does NOT mean replacing the LLM
- It does NOT mean designing interfaces, APIs, or telemetry schemas now
- It does NOT mean splitting the pipeline
- It does NOT mean changing how detectors are authored

Deterministic execution, when it arrives, will be a **strategy switch**
within the same pipeline — not a new system.

---

## 6. Knowledge Consumption

### Current: Markdown → LLM

```
knowledge/detectors/*.md  ──→  skill loads as prompt text  ──→  LLM interprets rules
```

Detector rules are loaded as Markdown text into the LLM's context window.
The LLM interprets each rule's definition, detection pattern, and examples.
No structured parsing happens before the LLM.

### Future: Structured → Strategy Engine

```
knowledge/detectors/*.md  ──→  structured extract (YAML frontmatter)  ──→  deterministic matcher
                                                                        ──→  LLM (for explanation only)
```

A future strategy might extract structured metadata from detector rules
(enabling deterministic matching) while keeping the Markdown body for
LLM explanation. This would be a gradual evolution: start with 1-2 detectors
that have unambiguous patterns (e.g., hardcoded-credentials), validate
deterministic output against LLM output, then expand.

---

## 7. Integration Points

The execution strategy integrates at these points:

### CLI → Strategy

```
secguardian-index → index.json
         ↓
strategy layer loads knowledge rules → LLM (current)
         ↓
findings → output layer
```

### AI Agent → Strategy

```
Agent reads command definition → strategy layer (via skill)
         ↓
strategy layer (LLM-assisted) produces findings
         ↓
Agent may generate explanations + patches
```

### CI → Strategy

CI does not inject into or modify the strategy layer. CI evaluates
the artifacts the pipeline produces (SARIF, status.json, summary.json)
as a verification constraint layer. See [runtime-model.md](runtime-model.md) for execution context, `internal/engine/engine_contract.md` for engine boundaries, and `internal/output/output_contract.md` for output formatting protocol.

---

## 8. CRITICAL WARNING

> **Do not implement a security engine as a separate service or execution
> kernel until the indexer has a proper IR layer and the knowledge base
> has structured rule definitions that have been validated against 2+
> production use cases.**

Premature engine implementation creates:
- A parallel execution path that diverges from LLM output
- Debug hell when Engine and LLM disagree on findings
- Wasted effort building infrastructure that the indexer (currently
  text-approximate, not AST-level) cannot fully support
- A system that fails silently: Engine finds nothing, user assumes
  no vulnerabilities

The current LLM-assisted strategy is the correct strategy for v0.x.
Engine research should be limited to: "can we make 1-2 unambiguous
detectors deterministic?" — and only after indexer quality is proven.

---

## 9. Commitment

To prevent strategy drift, this document makes the following commitments:

| Commitment | Rationale |
|-----------|-----------|
| Security Engine is NOT a system | It is an execution strategy definition |
| Current strategy: LLM-assisted | This is the only strategy implemented today |
| Deterministic pre-pass is authoritative | Index-derived candidates define the finding space; LLM validates within it |
| Deterministic strategy: future research | Not a current implementation target |
| No Engine interface/API/telemetry defined | Premature abstraction without production use cases |
| No DSL assumption | Rules remain Markdown; structured metadata is gradual |
| No dual execution path | One pipeline; strategy is the execution mode |

Any design work that violates these commitments must first be discussed
with the project owner and documented as a CHANGE entry.
