# OUTPUT CONTRACT v1

> **Document**: Output formatting protocol — single-direction, no analysis in renderer.
> **Status**: Ratified. Renderer does not analyze; engine does not format.
> **Location**: `internal/output/` (specification only)

---

## 1. Purpose

The output layer is the **only** layer that formats and renders scan results.
It receives raw findings from the engine and produces human-readable reports,
CI-compatible SARIF, and management dashboards.

The output layer does NOT:
- Analyze code
- Match detector rules
- Read index.json
- Make security decisions

---

## 2. Data Flow

```
Engine emits:
  findings.json (raw, structured per finding)
  events.json   (log stream, optional)

Renderer receives:
  findings.json
  output protocol spec (knowledge/protocols/scan-output.md)

Renderer produces:
  report.md        (human-readable)
  results.sarif    (SARIF 2.1.0, CI/CD)
  summary.json     (statistics + security score)
  status.json      (PASSED/FAILED/WARN)
  delta.json       (vs previous scan)
  manifest.json    (scan metadata + finding index)
  dashboard.html   (management view, optional)
```

---

## 3. Contract

### Input

| Field | Source | Format |
|-------|--------|--------|
| `findings.json` | Engine | Array of structured finding objects |
| `output_root` | Command | Directory path |
| `protocol_version` | knowledge/protocols/ | v5.0 |

### Output

| Artifact | Consumer | Format |
|----------|----------|--------|
| `report.md` | Developer / Security Engineer | Markdown |
| `results.sarif` | CI/CD, GitHub, GitLab | SARIF 2.1.0 JSON |
| `summary.json` | Dashboard, CI gate | JSON |
| `status.json` | CI gate, exit code | JSON |
| `delta.json` | Trend analysis | JSON |
| `manifest.json` | Scan discovery | JSON |
| `dashboard.html` | Management | HTML |

### Boundaries

| Boundary | Owner | Reason |
|----------|-------|--------|
| Security analysis | Engine | Renderer does not touch security logic |
| Detector matching | Engine | Renderer receives finished findings |
| index.json access | Engine | Renderer reads findings.json, not index.json |
| File system layout | Command | Renderer writes to path provided by command |

---

## 4. Current Implementation

The current renderer is `render-report.py` (located at project root).
It reads findings from a directory and produces all 7 artifact types.

Configuration:
```
# Usage (current)
python3 render-report.py         \
  --findings-dir <path>          \
  --output-dir <path>            \
  --protocol-dir <path>

# Output
<output-dir>/
  report.md
  results.sarif
  summary.json
  status.json
  delta.json
  manifest.json
  dashboard.html
```

The renderer does NOT need index.json. It only reads the finished findings
that the engine produced. This is by design — the renderer is format-only.

---

## 5. CI/CD Integration

CI/CD systems consume the formatted artifacts, not the raw findings:

```
Pipeline → Engine → findings.json
                    ↓
              Renderer → results.sarif → CI gate
                        → summary.json → Dashboard
                        → status.json  → Exit code
```

See `docs/ci-cd-interface.md` for the full CI/CD consumption contract.

---

## 6. Related Documents

- `internal/engine/engine_contract.md` — Engine produces findings.json
- `docs/ci-cd-interface.md` — CI/CD artifact consumption
- `knowledge/protocols/scan-output.md` — v5.0 output protocol spec
