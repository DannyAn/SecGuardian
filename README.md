# SecGuardian

> **AI-Native Security Workflow for the Entire Software Development Lifecycle**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](https://github.com/secguardian/secguardian)
[![Version](https://img.shields.io/badge/version-0.6.0-blue.svg)](https://github.com/secguardian/secguardian/blob/develop/CHANGELOG.md)
[![Go](https://img.shields.io/badge/Go-1.25%2B-00ADD8.svg)](https://go.dev)
[![Detectors](https://img.shields.io/badge/detectors-60-brightgreen.svg)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)
[![CWE Top 25](https://img.shields.io/badge/CWE_Top_25-100%25-brightgreen.svg)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)

SecGuardian is an enterprise-grade AI application security framework. It integrates AI reasoning with security engineering practices to help teams build, review, fix, and release secure software through **four automated security gates**.

By moving beyond raw AI code generation and introducing **Rule Packs**, SecGuardian translates standards like OWASP ASVS, NIST SSDF, and PCI DSS into machine-executable audit rules that run in your CLI and CI/CD pipelines.

---

## Quick Start

Choose how you want to install:

### Plugin zip (recommended)

Download the plugin zip for your AI agent from [Releases](https://github.com/DannyAn/SecGuardian/releases):

| If you use... | Download this file |
|---|---|
| Claude Code | `secguardian-0.10.0-claude-code-<os>-<arch>.zip` |
| OpenCode | `secguardian-0.10.0-opencode-<os>-<arch>.zip` |
| Gemini CLI | `secguardian-0.10.0-gemini-cli-<os>-<arch>.zip` |

Extract the zip into your agent's plugin directory, or install it through your agent's extension manager. Then use:

```bash
/secguard ./src           # Secure coding guidance
/secreview                # Code review (auto git diff)
/secfix                   # Auto-remediation
/secaudit                 # Full audit
```

### Source tarball (with deploy.sh)

Download `secguardian-0.10.0-source.tar.gz` from [Releases](https://github.com/DannyAn/SecGuardian/releases), extract, then:

```bash
bash scripts/deploy.sh          # Install for all supported platforms
bash scripts/deploy.sh cc       # Claude Code only
bash scripts/deploy.sh nga      # OpenCode only
bash scripts/deploy.sh cac      # Gemini CLI only
```

### Build from source (development)

```bash
git clone https://github.com/DannyAn/SecGuardian.git
cd SecGuardian
bash scripts/dev-deploy.sh
```

### Try the demo

After deploying, run against the built-in vulnerable examples:

```bash
/secguard examples/cpp-vuln-demo/src cpp
/secreview examples/python-vuln-demo/src python
/secaudit examples/java-vuln-demo/src java
```

### Standalone indexer (Go developers)

```bash
cd internal && go build -o secguardian-index .
./secguardian-index --path ./src --output index.json
```

---

## The Secure SDLC Pipeline

 The Software Development Lifecycle (SDLC) describes the stages of building software — from writing code and reviewing changes to shipping a release. SecGuardian embeds security into each of these stages. Rather than a single monolithic scan, it provides contextual tools purpose-built for each phase.

```mermaid
graph TD
    A[Writing Code] -->|/secguard - Prevent| B(Committed Code)
    B --> C{Pull Request}
    C -->|/secreview - Detect| D[Security Findings]
    D -.->|/secfix - Remediate| C
    D -->|Approved| E(Merge)
    E --> F{Release Candidate}
    F -->|/secaudit - Verify| G[Evidence & Reports]
    G -->|Pass| H((Release))

    classDef gate fill:#2b3137,stroke:#00ADD8,stroke-width:2px,color:#fff;
    class D,G gate;
```

### The Four Security Gates

| Command | Stage | Primary User | Outcome |
| --- | --- | --- | --- |
| **`/secguard`** | Implementation | Developers | Continuous secure coding guidance during development. |
| **`/secreview`** | Pull Request | Reviewers | Context-aware AI code review using business logic and exploitability analysis. |
| **`/secfix`** | Remediation | Developers | Auto-generates deterministic, ready-to-apply patches from findings. |
| **`/secaudit`** | Release | Security / Ops | Evaluates the application against enterprise Rule Packs before release. |

These four commands represent different stages of Secure SDLC, not different levels of scanning.

---

## Knowledge-Driven Audit Framework

Audit rules and security knowledge are maintained as Markdown files in `knowledge/`, not duplicated across the project. This makes them version-controllable, reviewable, and independent of the AI model — knowledge outlasts the AI.

```
docs/audit-framework/  ← Audit Execution Framework design docs
knowledge/audit-rules/ ← 17 audit rules (single source of truth)
skills/secaudit/       ← AI Workflow definitions
commands/secaudit.md   ← User entry point
```

All three commands (`/secguard`, `/secreview`, `/secaudit`) share the same invocation pattern: `<path> <language>`. Knowledge is always loaded from `knowledge/` at scan time.

### Current coverage

CWE Top 25: **100%** coverage. OWASP Top 10: **100%** coverage.

60 detectors across 7 security namespaces, supporting C/C++/Java/Python/Go/JavaScript:

| Namespace | Count | Coverage |
| --- | --- | --- |
| memory | 13 | Buffer overflow, UAF, double-free, null dereference |
| concurrency | 4 | Race conditions, deadlocks |
| system | 7 | Command injection, path traversal |
| crypto | 9 | Weak algorithms, hardcoded keys |
| web | 21 | XSS, SQLi, SSRF, CSRF, prototype pollution |
| resource | 6 | File/socket/resource leaks, lock misuse |
| error | 6 | Stack trace leakage, sensitive data in logs |

Analysis strategies include Taint Analysis, Data Flow Analysis, Attack Surface Analysis, Trust Boundary Analysis, and State Machine Analysis. These are tools, not the product — the long-term value lies in the Rule Packs that define what to analyze and the workflow that acts on the results.

### Standards in development

- OWASP ASVS (Application Security Verification Standard)
- NIST SSDF (Secure Software Development Framework)
- CIS Benchmarks
- PCI DSS
- Enterprise Security Baselines

---

## Developer Experience

SecGuardian is designed for zero friction in daily use. All commands work with zero arguments — they auto-detect the target language, current directory, and most recent scan context.

### Automated Remediation

Reduce a 30-minute vulnerability triage cycle to roughly two minutes:

```bash
# 1. Detect vulnerabilities in your current PR
/secreview

# 2. Generate ready-to-apply patches
/secfix findings/web-sql-injection/

# 3. Review the patch and apply
git diff
git apply findings/web-sql-injection/*.patch

# 4. Re-run to verify
/secreview
```

SecGuardian never merges code automatically. The developer retains final decision-making authority on every patch.

### CI/CD Integration

```yaml
# .github/workflows/security.yml
- uses: secguardian/secguardian-action@v1
  with:
    mode: secaudit
    skill: secaudit
    path: src/
```

Also supports GitLab SAST (`artifacts:reports:sast`) and Azure DevOps SARIF upload.

### Scan Output

```
.codeagent/<extension>/scans/<scan-id>/
├── human/executive-summary.md     # Executive dashboard
├── findings/                      # Per-detector finding files
├── ai/remediation-pack.json       # AI-consumable remediation pack
├── report.md                      # Human-readable report
├── dashboard.html                 # Management dashboard
├── results.sarif                  # SARIF 2.1.0 (CI/CD input)
├── summary.json                   # Summary statistics
├── manifest.json                  # Scan metadata + finding index
├── status.json                    # CI gate status
└── delta.json                     # Delta vs previous scan
```

---

## Vision

Our vision is to make enterprise-grade application security accessible to every development team. Security engineers remain at the center of the process — they work with better tooling, not fewer people.

We are building toward that vision in three phases:

> **AI Security Scanner** → **AI Security Workflow** → **AI Security Governance Platform**

The Audit Framework and Rule Packs we are building today lay the foundation for that third phase: a governance platform where organizations define their security policies as executable rules, run them across every stage of development, and produce audit-ready evidence for every release.

---

## License

Proprietary. All rights reserved.
