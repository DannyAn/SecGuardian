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

### 4.1 Deterministic Fast Gate (Future: v0.16+)

When deterministic signal quality reaches sufficient maturity (post v0.15
data-flow pre-analysis), CI can run a **fast gate** without invoking the LLM.
The fast gate does not detect vulnerabilities — it performs hygiene checks
on the scan process itself:

```
Pipeline → results.sarif + summary.json + status.json
                                      ↓
                          CI Fast Gate evaluates:
                          1. Anchor check: do all findings have valid index anchors?
                             - Unanchored finding ratio > threshold → WARN
                          2. Pre-filter match rate: what % of detector activations
                             were pre-flagged by deterministic signals?
                             - Match rate < threshold → possible missed detections
                          3. De-duplication: are there duplicate findings at the
                             same code location?
                             - Duplicate ratio > threshold → signal grouping issue
```

**The fast gate does NOT replace the LLM scan.** It provides a quick health
check before or alongside the full pipeline. If the fast gate flags anomalies
(e.g., high unanchored finding ratio), the team knows the LLM may be
hallucinating findings and should re-run with tighter constraints.

**Fast gate vs. full scan**:

| Aspect | Fast Gate | Full LLM Scan |
|--------|-----------|---------------|
| LLM required | No | Yes |
| Detection quality | N/A (hygiene only) | Full CWE/CERT coverage |
| Determinism | 100% (signal arithmetic) | Variable (LLM reasoning) |
| Duration | <1s | 1-5 min |
| Use case | Pre-commit hook, CI health check | PR review, release audit |

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
