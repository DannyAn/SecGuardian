# SecGuardian CI/CD Integration Guide

> How to embed security scanning into your CI pipeline — progress, results, and gating.
> Platform: GitHub Actions | Gitee Go

---

## 1. Output Structure (Quick Reference)

Every scan produces:

```
.codeagent/<extension>/scans/<scan-id>/
├── manifest.json       # Full scan summary (reads: humans + CI scripts)
├── results.sarif       # SARIF 2.1.0 (reads: GitHub Code Scanning)
├── status.json         # CI gating decision (reads: CI exit code)
├── delta.json          # Trend comparison (reads: daily build dashboards)
├── findings/
│   ├── C-001.json      # Individual finding detail
│   └── ...
└── latest → <scan-id>/ # Symlink — always points to most recent scan
```

**CI scripts should ALWAYS read from `latest/` — never guess the scan-id.**

---

## 2. CI Gate Logic (3 Steps)

### Step A: Check if scan completed

```bash
SCAN_DIR=".codeagent/secguard-secguardian/scans/latest"
if [ ! -f "$SCAN_DIR/manifest.json" ]; then
  echo "::error::No scan results found. Run secguardian-scan first."
  exit 2
fi
```

### Step B: Read the gating decision

| File | Purpose | Script reads |
|------|---------|-------------|
| `status.json` | CI gating — passed/failed + exit code | `jq '.exit_code'` |
| `manifest.json` | Full summary — total findings, language, duration | `jq '.summary.findings'` |
| `latest/manifest.json` | Always up-to-date scan | `cat latest/.scan_id` |

```bash
EXIT_CODE=$(jq -r '.exit_code' "$SCAN_DIR/status.json")
TOTAL=$(jq -r '.summary.findings.total' "$SCAN_DIR/manifest.json")
SCORE=$(jq -r '.score' "$SCAN_DIR/status.json")

echo "Security Gate: score=$SCORE, findings=$TOTAL, exit=$EXIT_CODE"
```

### Step C: Fail the pipeline if gate fails

```bash
if [ "$EXIT_CODE" != "0" ]; then
  echo "::error::Security Gate BLOCKED — ${TOTAL} findings, score ${SCORE}"
  exit 1
fi
echo "::notice::Security Gate PASSED — score ${SCORE}"
```

---

## 3. Reading Scan Progress

During scan execution (not relevant for one-shot CI runs, useful for long audits):

### Phase 1: Code Indexing (seconds)

```
→ Running code indexer (secguardian-index)...
  Parsed: webapp.py (5 functions, 2 vars)
  Parsed: crypto_utils.py (7 functions, 1 vars)
  Symbols: 12 functions, 3 variables, 2 types
  Call graph: 4 edges
  ✓ Code index generated: .codeagent/.../index.json
```

### Phase 2: AI Analysis (10-60 seconds depending on scope)

The manifest.json status starts as `pending` and transitions to `completed`:

```json
{
  "scan": {
    "status": "completed|partial|failed"
  }
}
```

CI scripts wait for `status` === `completed` before reading results:

```bash
# Wait for scan to complete (poll manifest.json)
for i in 1 2 3 4 5; do
  STATUS=$(jq -r '.scan.status' "$SCAN_DIR/manifest.json" 2>/dev/null || echo "pending")
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && echo "Scan failed" && exit 1
  sleep 10
done
```

### Phase 3: Output Generation

After scan completes, these files are available:
- `manifest.json` — status = completed, with all findings populated
- `status.json` — exit_code populated (0/1/2)
- `findings/*.json` — individual finding details

---

## 4. Reading Finding Details

### Summary from manifest.json

```json
{
  "summary": { "findings": { "critical": 1, "high": 2, "medium": 0, "total": 3 } },
  "findings": [
    { "id": "C-001", "severity": "critical", "detector": "web.xss",
      "cwe": "CWE-79", "file": "src/webapp.py", "line": 42,
      "title": "XSS via mark_safe", "finding_file": "findings/C-001.json" }
  ]
}
```

### Detail from findings/<id>.json

```bash
# Read a specific finding
cat .codeagent/secguard-secguardian/scans/latest/findings/C-001.json

# Extract key info with jq
jq '{id, severity, title, location: {file, line}, confidence}' \
  .codeagent/secguard-secguardian/scans/latest/findings/*.json
```

### Security Dashboard PR Comment (GitHub Actions)

```yaml
- name: Post scan summary as PR comment
  uses: actions/github-script@v7
  with:
    script: |
      const manifest = require('.codeagent/secguard-secguardian/scans/latest/manifest.json');
      const summary = manifest.summary.findings;
      const body = `## 🔒 SecGuardian Scan Results
        | Severity | Count |
        |---|---|
        | Critical | ${summary.critical} |
        | High | ${summary.high} |
        | Medium | ${summary.medium} |
        | Low | ${summary.low} |
        **Score**: ${manifest.score}/100`;
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: body
      });
```

---

## 5. GitHub Actions — Complete Workflow

```yaml
# .github/workflows/security-scan.yml
name: SecGuardian Security Scan
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2  # needed for git-diff incremental mode

      - name: SecGuardian Scan
        uses: secguardian/secguardian-action@v1
        with:
          mode: secguard
          path: src/
          sarif: true

      - name: CI Gate Check
        id: gate
        run: |
          SCAN_DIR=".codeagent/secguard-secguardian/scans/latest"
          EXIT=$(jq -r '.exit_code' "$SCAN_DIR/status.json")
          SCORE=$(jq -r '.score' "$SCAN_DIR/status.json")
          echo "exit_code=$EXIT" >> $GITHUB_OUTPUT
          echo "score=$SCORE" >> $GITHUB_OUTPUT

      - name: Upload SARIF to GitHub Code Scanning
        if: success()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: .codeagent/secguard-secguardian/scans/latest/results.sarif
          category: secguardian

      - name: Fail pipeline on gate breach
        if: steps.gate.outputs.exit_code != '0'
        run: |
          echo "::error::Security gate breached (score: ${{ steps.gate.outputs.score }})"
          exit 1

      - name: Add PR comment with results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const manifest = require('.codeagent/secguard-secguardian/scans/latest/manifest.json');
            const s = manifest.summary.findings;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## 🔒 SecGuardian Scan
                **Score**: ${manifest.score || 'N/A'}/100
                | Critical | High | Medium | Low | Total |
                |---|---|---|---|---|
                | ${s.critical} | ${s.high} | ${s.medium} | ${s.low} | ${s.total} |
                Details: .codeagent/ | Confidence: ${JSON.stringify(manifest.confidence || {})}`
            });
```

---

## 6. Gitee Go — Complete Pipeline

```yaml
# .gitee/workflows/security-scan.yml
name: SecGuardian Security Scan
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2

      # Gitee Go does not have a marketplace action; use the Bash CLI directly
      - name: Install secguardian-index
        run: |
          if [ -f internal/go.mod ] && command -v go &>/dev/null; then
            echo "Building secguardian-index from source..."
            cd internal && go build -o secguardian-index .
            sudo mv secguardian-index /usr/local/bin/
          else
            echo "Go not available — scans will run without pre-computed index"
          fi

      - name: Run security scan
        run: |
          bash scripts/secguardian.sh scan --path src/ --sarif
          echo "Scan complete."

      - name: CI Gate Check
        run: |
          SCAN_DIR=".codeagent/secguard-secguardian/scans/latest"
          EXIT=$(jq -r '.exit_code' "$SCAN_DIR/status.json" 2>/dev/null || echo "2")
          TOTAL=$(jq -r '.summary.findings.total' "$SCAN_DIR/manifest.json" 2>/dev/null || echo "0")
          echo "Exit code: $EXIT, Total findings: $TOTAL"
          if [ "$EXIT" != "0" ]; then
            echo "Security gate FAILED"
            exit 1
          fi
          echo "Security gate PASSED"
```

---

## 7. Daily Build Trend Tracking

For version-level / daily-build static analysis:

```bash
#!/bin/bash
# cron/daily-security-scan.sh
#
# Run daily, track trends via delta.json

SCAN_BASE=".codeagent/secguard-secguardian/scans"

# Run scan
bash scripts/secguardian.sh scan --path src/

# Read latest results
LATEST_DIR="$SCAN_BASE/latest"
SCORE=$(jq -r '.score' "$LATEST_DIR/status.json")
CRITICAL=$(jq -r '.summary.findings.critical' "$LATEST_DIR/manifest.json")
HIGH=$(jq -r '.summary.findings.high' "$LATEST_DIR/manifest.json")

# Send metrics to monitoring
echo "security_scan score=$SCORE critical=$CRITICAL high=$HIGH" | \
  curl -s --data-binary @- "https://monitoring.internal/metrics"

# Check for new findings vs previous scan
if [ -f "$LATEST_DIR/delta.json" ]; then
  NEW=$(jq '.findings.new | length' "$LATEST_DIR/delta.json")
  if [ "$NEW" -gt 0 ]; then
    echo "⚠️  ${NEW} new findings since last scan"
    jq '.findings.new[] | "\(.severity) \(.file):\(.line) — \(.id)"' \
      "$LATEST_DIR/delta.json"
  fi
fi
```

---

## 8. Threshold Configuration Guide

The `status.json` threshold determines CI pass/fail:

| Threshold | Meaning | Default | Recommendation |
|-----------|---------|---------|---------------|
| `critical_max` | Max critical allowed | 0 | 0 (block on any critical) |
| `high_max` | Max high allowed | 5 | 5-10 (allow minor findings) |
| `medium_max` | Max medium allowed | N/A | No block (warning only) |

Override thresholds in CI:

```bash
# Set strict gates for production branches
jq '.threshold.critical_max = 0 | .threshold.high_max = 3' \
  .codeagent/secguard-secguardian/scans/latest/status.json > /tmp/status.json
mv /tmp/status.json .codeagent/secguard-secguardian/scans/latest/status.json

# Then check gate
jq -e '.exit_code == 0' .codeagent/secguard-secguardian/scans/latest/status.json
```

---

## 9. Confidence Filtering Guide

Findings are labeled with confidence. Use this to reduce false-positive noise:

```bash
# Only fail on high-confidence findings
HIGH=$(jq '[.findings[] | select(.confidence.level == "high")] | length' \
  .codeagent/secguard-secguardian/scans/latest/manifest.json)

echo "High-confidence findings: $HIGH"
# Use $HIGH for gating instead of total findings
```

Confidence levels:

| Level | Meaning | Action |
|-------|---------|--------|
| `high` | Path + symbol verified, exploit chain complete | **Block CI** |
| `medium` | Pattern match, incomplete evidence | **Warn in PR comment** |
| `low` | Best practice violation, no direct exploit | **Log only, no action** |

```yaml
# GitHub Action step: fail only on high+medium confidence
- name: Confidence-gated gate
  run: |
    HIGH=$(jq '[.findings[] | select(.confidence.level == "high")] | length' \
      .codeagent/secguard-secguardian/scans/latest/manifest.json)
    MEDIUM=$(jq '[.findings[] | select(.confidence.level == "medium")] | length' \
      .codeagent/secguard-secguardian/scans/latest/manifest.json)
    echo "High: $HIGH, Medium: $MEDIUM"
    [ "$HIGH" -eq 0 ] && [ "$MEDIUM" -lt 5 ] && exit 0
    exit 1
```

---

## Reference: File Purpose Summary

| File | Read by | Primary Use |
|------|---------|------------|
| `manifest.json` | CI scripts, humans | Full scan summary + findings index |
| `results.sarif` | GitHub Code Scanning | PR with inline annotations |
| `status.json` | CI gate scripts | 3-line Bash pass/fail |
| `delta.json` | Dashboard scripts | Trend tracking |
| `findings/<id>.json` | Humans, debug tools | Individual finding detail |
| `.system_prompt.md` | AI session | Context (not CI-consumable) |
| `index.json` | AI context | Pre-computed code symbols (not CI-consumable) |
