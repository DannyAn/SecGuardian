# SecGuardian Execution Context Architecture

> **Document**: Single-pipeline architecture
> **Status**: ONE execution pipeline; CI is a verification constraint layer over artifacts
> **Updated**: 2026-07-04 (Round 2 review — CI as verification constraint layer)

---

## 1. One Pipeline

SecGuardian has exactly **one execution pipeline**. It runs inside an AI Agent
(Claude Code, OpenCode, Gemini CLI) or a terminal via wrapper script.

```
Same Pipeline:     indexer → knowledge rules → LLM execution → findings → renderer
                    ↓
Interactive mode:   full LLM reasoning, explanations, patches
                    full report + findings output
```

There is one execution path. No branch, no fork, no dual runtime.

---

## 2. Interactive Execution Profile

| Attribute | Description |
|-----------|-------------|
| **Primary users** | Developers, Security Engineers |
| **Interaction model** | Conversational (slash commands / terminal) |
| **Execution trigger** | Manual (`/secguard ./src`) |
| **Context** | Maintained across session; project index cached |
| **Output consumers** | Human (report.md), findings panel in agent chat |
| **Feedback loop** | Immediate: run → review → fix → re-run |
| **LLM usage** | Full: analysis + explanation + patch generation |
| **Scan scope** | Current file / project / incremental diff |

**Execution flow** (the one and only pipeline):

```
User: "/secguard ./src cpp"
    │
    ▼
Agent finds command definition
    │
    ▼
Runs secguardian-index (cached or fresh)
    │
    ▼
Agent loads skill → reads knowledge/detectors/ + index.json
    │
    ▼
LLM processes rules against index (single pass)
    │
    ▼
Findings written to .codeagent/scans/<scan-id>/
    │
    ▼
report.md + findings/ → user reads output
```

---

## 3. The Shared Pipeline

Every stage is shared across all usage modes. The pipeline is not duplicated.

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   Indexer    │──▶│  Knowledge   │──▶│  LLM (exec)  │──▶│   Output     │
│ secguardian- │   │  Loading     │   │  Single pass │   │   Layer      │
│ index        │   │  detectors/  │   │               │   │ report, SARIF│
│ (Go binary)  │   │ (Markdown)   │   │               │   │              │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
       │                  │                   │                  │
       │   index.json     │   rule context    │   findings.json   │   artifacts
       ▼                  ▼                   ▼                  ▼
   Symbol table    79 detector rules      LLM reasoning    6 output files
  + call graph     + language profiles   + rule matching   (report, SARIF,
  + alloc/free     + output protocol                       summary, status,
  + lock graph                                              delta, manifest)
```

### Why It Does Not Need to Split

The pipeline is language-dependent (indexer works per language),
content-dependent (knowledge works per rule), model-dependent
(LLM works per model), and producer-agnostic (output works per
format). There is no architectural reason to split.

---

## 4. CI: Verification Constraint Layer

CI is not a runtime or a profile.

> CI is a **verification constraint layer** over SecGuardian artifacts.

CI does NOT define execution behavior.
CI does NOT define a runtime profile.
CI does NOT consume from a different pipeline.

CI only evaluates artifacts produced by the one pipeline:

See `docs/ci-cd-interface.md` for the CI/CD consumption contract definition.

| Artifact | What CI Evaluates |
|----------|------------------|
| `results.sarif` | Finding severity count, compliance with gate rules |
| `status.json` | PASSED / FAILED / WARN gate status |
| `summary.json` | Security score, score drift vs baseline |

CI's role is not to detect vulnerabilities. It is to **verify** that the
pipeline's output meets organizational security constraints.

```
Pipeline → results.sarif + status.json + summary.json
                                      ↓
                               CI evaluates:
                               - score >= threshold?
                               - critical finding count == 0?
                               - score drift <= tolerance?
```

---

## 5. Implications

### Impact on Skill Design

Skills do not need to know about CI. A skill describes:
- Which detectors to load
- What language to scan
- What output format to produce

CI is irrelevant at skill-authoring time. Verification happens later,
in a different layer, against the artifacts the pipeline produces.

### Impact on Output Protocol

The scan output protocol (v5.0) defines all artifacts. All consumers
read from the same output directory. CI reads a subset:

- Interactive: All artifacts (report.md, findings/, dashboard.html, SARIF, etc.)
- CI: SARIF + summary.json + status.json (gate-specific artifacts)

Both from the same output directory. No separate pipeline.

### Impact on Verification

| Concern | What We Verify |
|---------|---------------|
| Indexer correctness | Builds valid index.json for all supported langauges |
| Knowledge loading | All 67 detectors load without error |
| Execution output | LLM produces valid findings in expected format |
| SARIF compliance | results.sarif conforms to SARIF 2.1.0 schema |
| Gate behavior | status.json exit code matches findings |

The same verification suite covers all usage modes. CI adds gate-specific
checks (exit code) on top of the same foundation.
