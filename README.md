# SecGuardian

> **AI-Powered Security Workflow for the Entire Software Development Lifecycle**

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](https://github.com/secguardian/secguardian)
[![Version](https://img.shields.io/badge/version-0.6.0-blue)](https://github.com/secguardian/secguardian/blob/develop/CHANGELOG.md)
[![Go](https://img.shields.io/badge/Go-1.25%2B-00ADD8)](https://go.dev)
[![Detectors](https://img.shields.io/badge/detectors-60-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)
[![CWE Top 25](https://img.shields.io/badge/CWE_Top_25-100%25-brightgreen)](https://github.com/secguardian/secguardian/blob/develop/knowledge/language-index.md)

SecGuardian is an AI-powered application security framework that helps engineering teams build, review, fix, and release secure software through four security gates.

Instead of acting as another vulnerability scanner, SecGuardian integrates AI reasoning with security engineering practices across the entire Secure SDLC — from writing code to shipping a release candidate.

```

                Secure SDLC — Four Gates


        Coding
           |
           v
     /secguard — Prevent

           |
           v
     [Pull Request]
           |
           v
     /secreview — Detect
           |
     ┌─────┴─────┐
     |           |
   Merge     /secfix — Remediate
              Generate & apply patches
                |
                └── Re-run /secreview

           |
           v
     [Release Candidate]
           |
           v
      /secaudit — Verify
```

---

## Why SecGuardian?

AI reasoning is becoming a commodity. Within a year, every development tool will understand code and detect patterns just as well.
 
The real differentiator is not how smart the AI gets — it is what you build on top of it.
 
SecGuardian focuses on three things that compound in value over time:
 
**1. Enterprise Security Knowledge (Rule Packs)**
 
How to organize OWASP ASVS, NIST SSDF, CIS Benchmarks, PCI DSS, and enterprise security redlines into executable audit rules that teams can run, customize, and maintain independently of the AI engine.
 
**2. Secure SDLC Workflow (Four Gates)**
 
From coding to pull request to release acceptance — a complete pipeline with four clear decision gates, each answering a yes/no question about whether the software moves to the next stage.
 
**3. Actionable Outputs for the Whole Organization**
 
Outputs designed for the audience that needs them: developers get fix recommendations, security engineers get evidence packages, release managers get security scores, and CI/CD pipelines get SARIF. These aren't just AI agent logs — they are consumable by everyone involved in shipping software.

---

## Four Security Gates

| Command      | Purpose                   | Primary Users                     | Outcome                                       |
| ------------ | ------------------------- | --------------------------------- | --------------------------------------------- |
| `/secguard`  | Secure Coding Guidance    | Developers                        | Prevent vulnerabilities during implementation |
| `/secreview` | AI Security Code Review   | Developers / Reviewers            | Detect security defects before merge          |
| `/secfix`    | AI Remediation            | Developers / Reviewers            | Generate & apply security fixes before merge  |
| `/secaudit`  | AI Release Security Audit | Security Teams / Release Managers | Verify security baselines before release      |

These four commands represent different stages of Secure SDLC rather than different levels of scanning.

---

## SecGuard

Secure Coding Guidance.

Designed for engineers while writing code.

SecGuard continuously analyzes implementation logic and provides secure coding guidance before vulnerabilities become part of the codebase.

Typical capabilities:

- Secure coding recommendations
- Dangerous API detection
- Security-aware code generation
- Language-specific secure practices
- Educational explanations

Goal:

> Prevent vulnerabilities before they are committed.

---

## SecReview

AI Security Code Review.

Designed for pull requests, repositories and completed implementations.

Unlike traditional linters, SecReview reasons about code behavior, business logic and exploitability.

Typical outputs:

- Security findings
- CWE mapping
- Severity assessment
- Exploit scenarios
- Fix recommendations
- SARIF output

Goal:

> Detect security defects before merge.

---


## SecFix

AI Remediation.

For developers who know a fix is needed — and would rather review a patch than write one.

SecFix reads findings from `/secreview` (or `/secguard`, `/secaudit`) and generates ready-to-apply patches for each finding. The developer reviews each patch, adjusts if needed, and applies — reducing a 30-minute fix cycle to 2-5 minutes.

Typical workflow:

- `/secreview ./src cpp git diff` — detects 3 findings
- `/secfix findings/web-sql-injection/` — generates 3 patch files
- Developer reviews patches (`git diff`), approves and applies
- `/secreview ./src cpp git diff` — re-run to verify fixes

Key principles:

- **Decision stays with the developer.** SecFix generates patches, it does not apply them automatically.
- **Every patch is traceable.** Each finding links to its source finding ID in `/secreview` output.
- **Re-run is required.** The gate is not considered clear until `/secreview` passes on the fixed code.

Goal:

> Fix security defects in minutes, not hours.

---


## SecAudit

AI Release Security Audit.
 
Built on a pluggable Rule Pack architecture (`audit-framework/`). The default `secguardian` pack covers 17 audit domains. Future packs include `company-redline-v3`, `owasp-asvs`, and `pci-dss`.

SecAudit is **not another code review tool.**

It simulates an enterprise security acceptance process by evaluating an application against predefined security baselines and audit rule packs.
Each audit is scoped by a Rule Pack: `/secaudit --rulepack secguardian ./src`.

Typical use cases:

- Enterprise Security Redline validation
- Internal Security Checklist verification
- OWASP ASVS assessment
- Release security gate
- Security acceptance preparation

Goal:

> Determine whether a release is ready for security acceptance.

---

## AI Security Audit Framework

SecAudit is built on a reusable audit framework.

```

               Rule Pack

        Company Security Redline

              OWASP ASVS

              NIST SSDF

           Internal Standards

                   |
                   v

          AI Reasoning Engine

                   |
                   v

        Evidence Collection

                   |
                   v

         Audit Report Generator

                   |
                   v

         Release Decision
```

Instead of hardcoding audit logic, SecGuardian separates:

- Audit Rules
- AI Reasoning
- Evidence Collection
- Report Generation

making it easy to support different enterprise security standards.

---

## Deep AI Analysis

SecAudit combines multiple analysis strategies, including:

- Taint Analysis
- Data Flow Analysis
- Attack Surface Analysis
- Trust Boundary Analysis
- State Machine Analysis

Analysis strategies are tools, not the product. The long-term value comes from the Rule Packs that define what to analyze, and the workflow that acts on the results.

---

## Rule Packs & Knowledge System
 
SecGuardian organizes enterprise security standards into executable Rule Packs. Each Rule Pack maps a published standard to a structured set of audit rules, each with pass/fail criteria, evidence requirements, and remediation guidance.
 
A Rule Pack is not a document — it is a machine-executable knowledge asset that can be versioned, reviewed, and customized per organization.
 
```
Published Standard (e.g., OWASP ASVS)
         |
         v
   Rule Pack Definition
     - Audit rules with pass/fail criteria
     - Evidence collection requirements
     - Severity mappings
     - Remediation guidance
         |
         v
   AI Reasoning Engine (runs the rules)
         |
         v
   Evidence + Decision
```
 
This separation means the AI engine can be upgraded independently of the security knowledge, and vice versa — the Rule Packs outlast the AI model.
 
**Current coverage includes:**


- Authentication & Session
- Authorization
- Input Validation
- Output Encoding
- Cryptography
- Secret Management
- Secure Transport
- Data Protection
- Dependency Security
- Infrastructure Hardening
- Logging & Audit
- Information Exposure

**Rule Packs in development:**

- OWASP ASVS
- NIST SSDF
- CIS Benchmarks
- PCI DSS
- Enterprise Security Baselines
- Cloud Security
- Kubernetes Security
- AI Application Security

---

## Supported Platforms

| Platform      | Local CLI                                                      | CI/CD                              |
|---------------|----------------------------------------------------------------|------------------------------------|
| **Claude Code** | `npm install -g @anthropic-ai/claude-code`                     | --                                 |
| **OpenCode**    | [opencode.ai](https://opencode.ai)                              | --                                 |
| **Gemini CLI**  | Google Gemini CLI                                               | --                                 |
| **GitHub Actions** | --                                                         | `uses: secguardian/secguardian-action@v1` + SARIF |
| **GitLab CI**   | --                                                             | SAST artifacts                     |
| **Azure DevOps**| --                                                             | SARIF upload                       |

---

## Installation

### One-command deploy

```bash
# Build + deploy to all supported platforms
bash scripts/dev-deploy.sh

# Or per-platform
bash scripts/deploy.sh cc     # Claude Code
bash scripts/deploy.sh nga    # OpenCode
bash scripts/deploy.sh cac    # Gemini CLI
```

### Indexer (standalone)

```bash
cd internal && go build -o secguardian-index .
./secguardian-index --version
./secguardian-index --health
./secguardian-index --path ./src --output index.json
```

---

## Detector Coverage

60 detectors across 7 security namespaces, supporting C/C++/Java/Python/Go/JavaScript:

| Namespace    | Count | Coverage |
|-------------|-------|----------|
| memory      | 13    | Buffer overflow, UAF, double-free, null dereference |
| concurrency | 4     | Race conditions, deadlocks |
| system      | 7     | Command injection, path traversal |
| crypto      | 9     | Weak algorithms, hardcoded keys |
| web         | 21    | XSS, SQLi, SSRF, CSRF, prototype pollution |
| error       | 6     | Stack trace leakage, sensitive data in logs |

CWE Top 25: 100% coverage. OWASP Top 10: 100% coverage.

---

## CI/CD Integration

```yaml
# .github/workflows/security.yml
- uses: secguardian/secguardian-action@v1
  with:
    mode: secaudit
    skill: taint-analysis
    path: src/

# SARIF results auto-upload to GitHub Security -> Code Scanning
```

GitLab SAST (`artifacts:reports:sast`) and Azure DevOps also supported.

---

## Scan Output

```
.codeagent/<extension>/scans/<scan-id>/
├── human/executive-summary.md     # Executive dashboard
├── human/                         # Human-readable findings
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

## Verification

```bash
# Scan example vuln codebases
/secguard examples/cpp-vuln-demo/src cpp
/secguard examples/python-vuln-demo/src python
/secguard examples/java-vuln-demo/src java
/secguard examples/go-vuln-demo/src go
/secguard examples/js-vuln-demo/src javascript

# Deep audit examples
/secaudit taint-analysis examples/python-vuln-demo/src/
/secaudit cryptography examples/python-vuln-demo/src/crypto_utils.py

# PR review examples
/secreview ./src cpp git diff                # Working tree changes
/secreview ./src py git diff main             # Branch diff vs main
```

---

## Vision

Our vision is to make enterprise-grade application security accessible to every development team — without replacing security engineers.
 
We are building toward that vision in three phases:
 
> **AI Security Scanner** → **AI Security Workflow** → **AI Security Governance Platform**
 
What we are building today — the Audit Framework and Rule Packs — lays the foundation for that third phase: a governance platform where organizations define their security policies as executable rules, run them across every stage of development, and produce audit-ready evidence for every release.

---

## License

Proprietary. All rights reserved.
