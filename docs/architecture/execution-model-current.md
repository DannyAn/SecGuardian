# SecGuardian Current Execution Model

> **Document**: The single, current execution path
> **Purpose**: Ground truth for how scanning works today
> **Updated**: 2026-07-04
> **Rule**: No dual-runtime expression or CI-as-runtime framing

---

## 1. The One Pipeline

SecGuardian has exactly **one execution pipeline**. It is always triggered by
an AI Agent (Claude Code, OpenCode, Gemini CLI) or directly from a terminal
via wrapper script.

```
Trigger
  │
  ▼
┌─────────────────────┐
│  1. Index Building  │   secguardian-index (Go binary)
│  Parse → Symbols → │   Tree-sitter (5 langs) or Regex fallback
│  Call Graph → Lock │   Output: index.json
│  Graph → Alloc/Free│
└─────────┬───────────┘
          │ index.json
          ▼
┌─────────────────────┐
│  2. Knowledge Load  │   Skill file + knowledge/detectors/
│  Skill (SKILL.md)   │   Loaded by AI Agent or tool
│  Detector rules →   │   67 detector rules across 7 namespaces
│  Language profile → │   5 language profiles
│  Output protocol →  │   v5.0 scan output specification
└─────────┬───────────┘
          │ rule context + index
          ▼
┌─────────────────────┐
│  3. LLM Execution   │   Single pass, LLM-driven reasoning
│  (Single Pass)      │   Currently the ONLY execution strategy
│  LLM reads rules +  │   No deterministic engine exists
│  index → reasons → │   Rule matching inside LLM reasoning
│  generates findings │   Finding generation via tool calls
└─────────┬───────────┘
          │ findings.json
          ▼
┌─────────────────────┐
│  4. Output Layer    │   render-report.py (Python)
│  Findings → Report  │   Produces 6 output files
│  → SARIF → Summary  │   report.md + results.sarif + summary.json
│  → Status → Delta   │   + status.json + delta.json + manifest.json
│  → Dashboard        │   + dashboard.html
└─────────────────────┘
```

**No branch. No fork. No dual runtime. One pipeline.**

---

## 2. Stage Details

### Stage 1: Index Building

```
Binary:  secguardian-index (compiled from internal/)
Input:   Source code directory (--path)
Output:  index.json (AnalysisContext schema)

Sub-stages:
  a. Parse All Files       → AST extraction (Tree-sitter or Regex)
  b. Build Symbol Index    → Function/variable/type names + locations
  c. Build Call Graph      → Text-approximate caller/callee edges
  d. Match Alloc/Free      → In-file malloc/free pairing
  e. Build Lock Graph      → Mutex lock/unlock locations
  f. Write Context         → Serialize to index.json
```

Indexer is seeded from `commands/secguard.md` → AI Agent runs
`secguardian-index --path <path> --output <output>`.

Index is cached at `.codeagent/secguardian/index.json`.
Reuse across commands; `--force` rebuilds.

### Stage 2: Knowledge Loading

```
Source:       skills/<command>/<lang>/SKILL.md
              knowledge/detectors/*.md (67 rules)
              knowledge/languages/<lang>.md
              knowledge/protocols/scan-output.md

Loading:      AI Agent reads SKILL.md → loads referenced
              knowledge files → builds context window for LLM
```

Knowledge is always loaded at scan time. It is version-controlled
Markdown. No preprocessing, no compilation, no DSL parsing.

### Stage 3: LLM Execution (Single Pass)

```
Inputs:   SKILL.md instructions
          detector rules (Markdown)
          index.json (JSON context)
          user request (path, language)

Process:  LLM reasons about each detector rule against the index
          LLM outputs structured findings via tool calls
          Findings written to .codeagent/<extension>/scans/<scan-id>/

Constraints:
  - Single LLM call per scan (no multi-turn analysis)
  - Findings are deterministic per LLM run (same input → same output)
  - No post-processing before output layer
```

### Stage 4: Output Layer

This stage follows the output contract defined in `internal/output/output_contract.md`.

```
Script:   render-report.py

Inputs:   findings/ directory (per-detector finding files)
          knowledge/protocols/scan-output.md (format spec)

Outputs:
  ├── report.md              Human-readable security report
  ├── results.sarif          SARIF 2.1.0 (CI/CD integration)
  ├── summary.json           Finding counts + security score
  ├── status.json            CI gate status (PASSED/FAILED/WARN)
  ├── delta.json             Changes vs previous scan
  ├── manifest.json          Scan metadata + finding index
  └── dashboard.html         Management dashboard (optional)
```

---

## 3. What This Pipeline Is NOT

| Not This | Because |
|----------|---------|
| Not a SAST engine | No CFG, no DFG, no SSA/IR, no constraint solving |
| Not a dual-runtime system | One pipeline, one execution mode |
| Not CI-independent | CI (future) consumes same artifacts from same pipeline |
| Not engine-orchestrated | No Security Engine, no execution kernel |
| Not DSL-compiled | Rules are Markdown consumed by LLM, not compiled |

---

## 4. What This Pipeline IS

| Is This | Evidence |
|---------|----------|
| LLM-driven security analysis | All detection logic inside LLM reasoning |
| Knowledge-assisted scanning | Rules loaded from version-controlled Markdown |
| Single-pass execution | One LLM call produces all findings |
| Output-standardized reports | v5.0 protocol produces 7 artifact types |
| Cache-friendly indexing | index.json reused across commands |

---

## 5. Key Engineering Facts

- **Indexer**: Go binary, Tree-sitter CGO (5 langs) + Regex fallback (all platforms)
- **Knowledge**: 67 detectors, 7 namespaces, ~120 lines per rule on avg
- **Execution**: Single LLM call; no chained reasoning, no multi-turn
- **Output**: Python renderer, 7 file types, SARIF 2.1.0 compliant
- **Deployment**: Plugin dir per agent (Claude/OpenCode/Gemini); same pipeline everywhere

---

## 6. Pipeline Boundaries

| Boundary | What Happens Here | What Does NOT Happen |
|----------|------------------|---------------------|
| Indexer → Knowledge | index.json delivered | No rule pre-matching at this stage |
| Knowledge → LLM | Rules + index in context | No preprocessing of rules |
| LLM → Output | Findings JSON produced | No report formatting |
| Output → User | Reports rendered | No re-scanning or verification |

The pipeline is linear, bounded, and observable at every stage.
