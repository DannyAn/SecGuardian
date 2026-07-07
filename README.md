# SecGuardian

> **AI-Native Application Security Platform — Security Expertise as Executable Workflows**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](https://github.com/secguardian/secguardian)
[![Version](https://img.shields.io/badge/version-0.12.0-blue.svg)](https://github.com/secguardian/secguardian/blob/master/CHANGELOG.md)
[![Go](https://img.shields.io/badge/Go-1.25%2B-00ADD8.svg)](https://go.dev)
[![Detectors](https://img.shields.io/badge/detectors-67-brightgreen.svg)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)
[![CWE Top 25](https://img.shields.io/badge/CWE_Top_25-100%25-brightgreen.svg)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)

SecGuardian is an AI-native application security platform that transforms security expertise into executable workflows, measurable engineering practices, and continuous security intelligence across the software development lifecycle.

Unlike traditional SAST tools that run as standalone scanners, SecGuardian embeds **four security roles** into your existing AI coding agent (Claude Code, OpenCode, Gemini CLI). Each role corresponds to a real-world security function — Secure Coding Advisor, Security Reviewer, Remediation Engineer, and Release Auditor. Together they provide continuous security coverage from implementation through release.

**How it works under the hood**: A Tree-sitter based indexer (`secguardian-index`, Go binary) parses your source code into a deterministic symbol table + call graph (`index.json`). The AI Agent loads 67 detector rules (Markdown knowledge base) and performs semantic analysis against the indexed code structure. Findings are anchored to index symbols for traceability, validated for evidence completeness, and rendered into human + machine-readable reports (Markdown + SARIF 2.1.0).

> 📐 See [docs/architecture/architecture-vNext.md](docs/architecture/architecture-vNext.md) for the full architecture, [security-engine.md](docs/architecture/security-engine.md) for the Signal-LLM collaboration model, and [design-principles.md](docs/architecture/design-principles.md) for the 8 ADRs that guide all design decisions.

---

## Quick Start

### Install (Plugin zip — recommended)

Download the plugin zip for your AI agent from [Releases](https://github.com/DannyAn/SecGuardian/releases):

| AI Agent | Download |
|---|---|
| Claude Code | `secguardian-0.12.0-claude-code-<os>-<arch>.zip` |
| OpenCode | `secguardian-0.12.0-opencode-<os>-<arch>.zip` |
| Gemini CLI | `secguardian-0.12.0-gemini-cli-<os>-<arch>.zip` |

Extract into your agent's plugin directory or install via extension manager. Then:

```bash
/secguard ./src           # Secure coding advisor
/secreview                # PR security review (auto git diff)
/secfix                   # Auto-generate patches from findings
/secaudit                 # Full release audit
```

### Build from source (development)

```bash
git clone https://github.com/DannyAn/SecGuardian.git
cd SecGuardian
bash scripts/deploy.sh all
```

### Try the demo

```bash
/secguard examples/cpp-vuln-demo/src cpp
/secreview examples/python-vuln-demo/src python
/secaudit examples/java-vuln-demo/src java
```

---

## The Four Security Roles

SecGuardian models four real-world security roles. Each role maps to a command and a stage in the SDLC — not a "scanning level," but a security function:

```
IMPLEMENTATION  →  PULL REQUEST  →  REMEDIATION  →  RELEASE
     │                  │                │              │
  /secguard         /secreview        /secfix       /secaudit
  Secure Coding     Security          Remediation   Release
  Advisor           Reviewer          Engineer      Auditor
```

| Command | Security Role | SDLC Stage | Primary User | What It Does |
|---------|--------------|-----------|-------------|--------------|
| **`/secguard`** | Secure Coding Advisor | Implementation | Developers | Scans code as you write it. Detects vulnerabilities with fix guidance. 67 detectors across 7 security namespaces. |
| **`/secreview`** | Security Reviewer | Pull Request | Reviewers | Reviews changed lines in PRs. Assesses exploitability and business impact. Produces review findings with risk context. |
| **`/secfix`** | Remediation Engineer | Fix | Developers | Reads findings from any scan. Generates apply-ready unified diff patches. Developer reviews and applies — never auto-merges. |
| **`/secaudit`** | Release Auditor | Release | Security Team / CI | Full audit against enterprise Rule Packs. Produces evidence reports, compliance matrices, and SARIF for CI/CD gate decisions. |

**Key principle**: These are roles, not scanning levels. A human security team has specialists — SecGuardian provides AI counterparts for each.

---

## Who Uses What

### 👨‍💻 Developers (Daily)

```bash
/secguard ./src                    # Scan current project, auto-detect language
/secguard ./src cpp memory.*       # C++ memory safety only
/secreview                         # Review current PR changes
/secfix                            # Auto-fix findings from latest scan
```

- Zero-argument defaults: auto-detect language, auto-locate latest scan
- Incremental scanning: `git diff` mode for PR review
- Immediate feedback loop: scan → review → fix → re-scan

### 🔐 Security Engineers (Per-Release)

```bash
/secaudit ./src java               # Full Java audit against enterprise rules
/secaudit ./src cpp crypto.*       # Crypto-focused audit
/secaudit ./src python --sarif     # Audit + SARIF for compliance evidence
```

- Full audit with evidence chain: every finding traces to detector rule + code location
- Compliance mapping: OWASP ASVS, NIST SSDF, PCI DSS
- SARIF 2.1.0 output for GitHub Code Scanning / GitLab SAST / Azure DevOps

### ⚙️ CI/CD Pipeline (Automated)

```bash
# Fast gate — no LLM required (deterministic signal check)
python3 scripts/render-report.py --ci \
    --findings .codeagent/secguardian/secaudit/scans/latest/findings/ \
    --index .codeagent/secguardian/index.json \
    --output ./gate-results/
# Exit 0 = PASS, Exit 1 = FAIL
```

CI reads scan artifacts (SARIF + summary.json + status.json) produced by the AI Agent scan. It does NOT run its own scan. CI is a **verification constraint layer** over artifacts — it checks:

1. **Security score** ≥ threshold?
2. **Critical findings** = 0?
3. **Score drift** ≤ tolerance vs baseline?

For periodic full-repo scanning, schedule `/secaudit` via cron/CI trigger → render-report.py --ci for gate decision. See [docs/architecture/runtime-model.md](docs/architecture/runtime-model.md) §4.1 for the CI fast gate design.

---

## Architecture

```
Source Code (C/C++/Go/Java/Python/JS)
    │
    ▼
┌──────────────────────┐
│ secguardian-index     │  Go binary, Tree-sitter CGO parser
│ → index.json          │  symbols + call_graph + alloc_free + lock_graph
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Execution Strategy    │  Signal-LLM Collaboration
│ ┌─────────┐ ┌───────┐│
│ │ Signals │ │  LLM  ││  Signals: anchor + pre-filter (deterministic)
│ │(Indexer)│ │(Agent)││  LLM:    semantic analysis + patch generation
│ └─────────┘ └───────┘│
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ render-report.py      │  report.md + SARIF + summary + status + delta
└──────────────────────┘
```

**No separate Security Engine binary.** The indexer provides deterministic signals (symbols, call graph, alloc/free, lock graph). The AI Agent provides LLM reasoning. They collaborate through `index.json` — no intermediate abstraction layer.

- 📐 [Architecture Overview](docs/architecture/architecture-vNext.md)
- ⚡ [Signal-LLM Collaboration Model](docs/architecture/security-engine.md)
- 📏 [Design Principles (8 ADRs)](docs/architecture/design-principles.md)
- 🔒 [Engineering Constraints (EP-1~EP-7)](docs/architecture/engineering-principles.md)
- 📄 [Execution Strategy Contract](internal/engine/engine_contract.md)

---

## Knowledge-Driven Detection

Detection rules are maintained as version-controlled Markdown files in `knowledge/`. They are independent of the AI model — knowledge outlasts the AI.

**67 detectors across 7 security namespaces** covering C, C++, Go, Java, Python, and JavaScript:

| Namespace | Count | Coverage |
|-----------|-------|----------|
| memory | 13 | Buffer overflow, UAF, double-free, null dereference, format string |
| concurrency | 4 | Race conditions, deadlocks, data races |
| system | 8 | Command injection, path traversal, privilege escalation |
| crypto | 9 | Weak algorithms, hardcoded keys, insufficient key length |
| web | 21 | XSS, SQLi, SSRF, CSRF, IDOR, JWT misuse, deserialization |
| resource | 6 | File/socket leaks, lock misuse, double close |
| error | 6 | Stack trace leak, debug mode in production, sensitive data in logs |

CWE Top 25: **100%** coverage. OWASP Top 10: **100%** coverage.

[language-index.md](knowledge/language-index.md) provides per-language detector mapping.
Individual detector rules in [knowledge/guard-rules/](knowledge/guard-rules/).

---

## Scan Output

Every scan produces a complete artifact set in `.codeagent/secguardian/<command>/scans/<scan-id>/`:

```
scans/<scan-id>/
├── human/executive-summary.md     # One-page dashboard + finding distribution
├── findings/                      # Per-detector finding files (JSON)
├── ai/remediation-pack.json       # AI-consumable remediation pack
├── report.md                      # Human-readable audit report
├── dashboard.html                 # Management dashboard (open in browser)
├── results.sarif                  # SARIF 2.1.0 (CI/CD input)
├── summary.json                   # Statistics + security score
├── manifest.json                  # Scan metadata + finding index
├── status.json                    # CI gate: PASSED/FAILED/WARN
└── delta.json                     # Delta vs previous scan (trend analysis)
```

`latest` symlink always points to the most recent scan. `/secfix` uses it to auto-locate findings.

---

## Verification Pipeline

SecGuardian ships with a 5-layer verification system. Run the appropriate layer based on what you changed:

| Layer | Command | When |
|-------|---------|------|
| L1 Design Consistency | `bash scripts/self-check.sh` | Every commit |
| L2 Structural Integrity | `bash scripts/ci-check.sh` | Before push |
| L3 Deployment Health | `bash scripts/dev-verify.sh` | After deploy |
| L4 End-to-End | `bash scripts/e2e-verify.sh` | Architecture changes |
| L5 Full Release | L1 → L2 → L3 → L4 | Before release |

CI mode: `bash scripts/e2e-verify.sh --ci` (non-zero exit on failure).

---

## Vision

> **AI Security Scanner** → **AI Security Workflow** → **AI Security Governance Platform**

SecGuardian is in phase 2 today: an AI security workflow that embeds into the SDLC. The knowledge base, detector rules, and execution strategy defined today lay the foundation for phase 3 — a governance platform where organizations define security policies as executable rules, run them across every development stage, and produce audit-ready evidence for every release.

---

## License

Proprietary. All rights reserved.
