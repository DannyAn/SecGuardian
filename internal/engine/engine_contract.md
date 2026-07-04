# SECENGINE CONTRACT v1

> **Document**: Engine execution protocol — the only layer that reads code and writes results.
> **Status**: Ratified. All commands and skills must follow this contract.
> **Location**: `internal/engine/` (specification only — no engine binary exists yet)

---

## 1. Purpose

The engine is the **only** layer that:
- Reads source code (via index.json)
- Executes detector rules
- Produces raw findings

Commands dispatch to the engine. Skills define which detectors to run.
Neither reads index.json directly. Neither writes findings.

---

## 2. Contract

### Inputs

| Input | Source | Who Provides |
|-------|--------|-------------|
| `index.json` | `secguardian-index` (Go binary) | Pre-flight |
| `file_list` | Language filter + scan mode | Command |
| `detector_list` | Skill detector selection | Skill |
| `scan_mode` | full / incremental / namespace-filtered | Command |

### Outputs

| Output | Format | Consumer |
|--------|--------|----------|
| `findings.json` | Structured JSON per finding | Renderer |
| `events.json` | Log stream (optional) | Debug / telemetry |

### Boundaries (What the Engine Explicitly Does NOT Do)

| Boundary | Owner | Reason |
|----------|-------|--------|
| Language detection | Command | Engine executes, does not decide scope |
| Detector selection | Skill | Engine runs what it receives |
| Report formatting | Renderer | Engine produces raw findings only |
| File system operations (mkdir, cp) | Command / Renderer | Engine is stateless processing |
| SARIF generation | Renderer | SARIF is a format concern, not analysis |
| CI/CD gate decisions | CI layer | Engine produces findings; CI evaluates |

---

## 3. Execution Model

```
Engine receives:
  1. index.json (pre-built by secguardian-index)
  2. detector_list (from skill)
  3. scan_mode (from command)

Engine processes:
  For each detector in detector_list:
    - Read relevant index sections (symbols, call_graph, alloc_free, lock_graph)
    - Match detector patterns against index candidates (LLM-assisted or deterministic)
    - Produce finding if match found

Engine emits:
  findings.json → written to output directory (path provided by command)
  events.json → written to output directory (optional, debug)
```

### LLM-Assisted Strategy (Current)

The engine currently uses LLM-assisted strategy:
- LLM reads index.json context + detector rules
- LLM reasons about matches within index-derived candidate space
- LLM outputs structured findings

### Deterministic Strategy (Future Research)

When available, the engine may switch to deterministic matching.
Strategy switch happens within the engine — no command/skill changes needed.

---

## 4. index.json Access Rule

> **Rule C: index.json is engine-only.**

- Commands MUST NOT reference index.json structure
- Skills MUST NOT reference index.json structure
- Renderers MUST NOT read index.json (they read findings.json)

The only exception: `secguardian-index` (Go binary, produces index.json) and
the engine that consumes it.

---

## 5. Output Rule

> **Rule D: Output is single-direction.**

```
Engine → findings.json (raw) + events.json (log)
         ↓
Renderer → report.md (human) + results.sarif (CI) + summary.json (stats)
         ↓
Command defines output root path only
```

Engine does not format. Renderer does not analyze. Command does not produce
output content.

---

## 6. Related Documents

- `internal/output/output_contract.md` — Output formatting protocol
- `docs/ci-cd-interface.md` — CI/CD consumption contract
- `internal/context/context.go` — AnalysisContext struct (the data the engine processes)
