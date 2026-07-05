# EXECUTION STRATEGY CONTRACT v2

> **Document**: Execution strategy behavior contract — constraints that bind signal-LLM collaboration.
> **Status**: Ratified. All commands and skills must follow these constraints.
> **Location**: `internal/engine/` (behavior contract — no engine binary)
> **Updated**: 2026-07-05 (EPIC-005 R2 — from Engine API to behavior constraints)

---

## 1. Purpose

This contract defines the **behavioral constraints** that govern how
deterministic signals (from the indexer) and LLM reasoning (from the AI Agent)
collaborate to produce findings.

It does NOT define an Engine API. There is no separate Engine binary.
The execution strategy is a collaboration between two existing components:
- **Indexer** → produces `index.json` (deterministic signals)
- **AI Agent** → loads detector rules, performs LLM reasoning, produces findings

This contract defines the rules that ensure this collaboration is traceable,
verifiable, and consistent across different AI Agent platforms and models.

---

## 2. Behavior Constraints

### Anchor Rule (Rule A): Finding-Location Traceability

> Every finding's `location` MUST reference a symbol or file+line present in `index.json`.

**Requirement**: The `location` field of each finding must point to either:
- A function name that exists in `index.json → symbols.functions`
- A variable name that exists in `index.json → symbols.variables`
- A type name that exists in `index.json → symbols.types`
- A file+line number that exists in `index.json → files`

**When the anchor is missing**: If the LLM identifies a vulnerability at a location
with no corresponding index entry, it MUST:
1. Mark the finding as `confidence: low`
2. Include an `anchor_gap_reason` field explaining why the index didn't capture it
3. Still provide evidence (code quote) per the Evidence Rule

**Why this matters**: Without anchor traceability, findings cannot be verified
against a deterministic view of the codebase. Different LLM runs on the same
code may produce different finding sets with no way to audit the difference.

### Evidence Rule (Rule B): Code-Backed Assertions

> Every finding's `evidence` field MUST quote the specific code snippet
> that demonstrates the vulnerability.

**Requirement**: The `evidence` field must contain:
1. The file path and line number
2. The relevant code snippet (quoted verbatim)
3. An explanation of why this code matches the detector rule

**Not acceptable**: Pattern-based inference without code quotes (e.g., "the
function appears to handle authentication"). Evidence must be independently
verifiable by a human reviewer reading the quoted code.

**Why this matters**: Evidence-backed findings can be reviewed, validated, and
actioned. Findings without code evidence are indistinguishable from hallucination.

### Pre-Filter Rule (Rule C): Signal-Scoped Detector Applicability

> Detectors SHOULD be scoped by deterministic signals to reduce noise and
> focus LLM attention on relevant code paths.

**Pre-filter examples**:

| Signal Present | Detectors to Activate |
|---------------|----------------------|
| `symbols.functions` contains `malloc`/`realloc`/`calloc` | memory-leak, double-free, use-after-free |
| `symbols.functions` contains `strcpy`/`sprintf`/`gets`/`scanf` | buffer-overflow, format-string |
| `symbols.functions` contains `system`/`exec`/`popen` | command-injection |
| No crypto library functions in symbols | Skip crypto-misuse detectors |
| No SQL library functions in symbols | Skip SQL-injection detectors |
| `call_graph.edges` shows user-input → sensitive-sink path | Prioritize injection detectors |

**Why this matters**: Without pre-filtering, the LLM must scan all code against
all 67 detectors. This wastes context window and misses findings when the LLM
runs out of attention budget. Pre-filtering focuses LLM resources on high-signal areas.

---

## 3. Current Execution Reality

### How It Actually Works Today

```
secguardian-index → index.json (deterministic signals)
                           │
                           ▼
AI Agent loads:
  - index.json (signals for anchoring + pre-filtering)
  - skills/<command>/<lang>/SKILL.md (detector selection)
  - knowledge/detectors/*.md (detector rule definitions)
                           │
                           ▼
LLM processes rules against signals (single pass)
  - Anchors findings to index symbols
  - Provides code evidence per finding
  - Uses signals to scope detector applicability
                           │
                           ▼
findings.json → render-report.py → report.md + SARIF + summary + status
```

There is **no intermediate Engine layer**. The LLM prompt itself is the
execution mechanism. This contract defines the behavioral guardrails that
the LLM must follow — constraints that are enforced through prompt
instructions, not through API calls or binary execution.

### Why No Separate Engine

The indexer provides structure (symbols, call edges, alloc/free).
The LLM provides reasoning (semantic analysis, context understanding).
These two collaborate directly through `index.json`. A third component
between them would:
- Add latency without adding value
- Require an IR abstraction the indexer doesn't support
- Create a maintenance burden without improving detection quality

See `docs/architecture/security-engine.md` §7 for the full rationale.

---

## 4. Single-Direction Output Rule (Rule D)

> Output is single-direction: Engine produces raw findings → Renderer formats.

```
Deterministic Signals + LLM Reasoning → findings.json (raw) + events.json (log)
                                          ↓
                                 Renderer → report.md (human) + results.sarif (CI)
                                          → summary.json (stats) + status.json (gate)
                                          → delta.json (trend) + manifest.json (index)
```

- Signal layer does not format output
- LLM layer does not decide output structure
- Renderer does not analyze code
- Command defines output root path only

---

## 5. Layer Responsibility Boundaries

| Concern | Owner | Reason |
|---------|-------|--------|
| Language detection | Command | The strategy executes; it does not decide scope |
| Detector selection | Skill | The strategy runs what it receives |
| Symbol extraction | Indexer | Deterministic, code-derived signals |
| Semantic analysis | LLM (AI Agent) | The primary reasoning engine |
| Finding anchoring | LLM (constrained by Rule A) | Every finding must trace to a signal |
| Evidence provision | LLM (constrained by Rule B) | Every finding must quote code |
| Report formatting | Renderer | Format is separate from analysis |
| SARIF generation | Renderer | SARIF is a format concern, not analysis |
| CI/CD gate decisions | CI layer | CI evaluates artifacts, not analysis |

---

## 6. Related Documents

- `docs/architecture/security-engine.md` — Full Signal-LLM collaboration model
- `internal/output/output_contract.md` — Output formatting protocol
- `docs/ci-cd-interface.md` — CI/CD artifact consumption contract
- `docs/architecture/engineering-principles.md` — Engineering constraints EP-1~EP-7
- `docs/architecture/design-principles.md` — ADR-007 (Signal-LLM) + ADR-008 (Progressive Enhancement)
- `AGENTS.md` — Indexer capability boundaries
