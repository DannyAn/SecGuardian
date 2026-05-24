# SecGuardian — Application for hardcore software engineer @ X

**Candidate**: JonyAn (bjellick@163.com)
**Project**: SecGuardian — AI-Native Security Guardian
**Repository**: https://gitee.com/jonyan/secguardian
**Submitted to**: code@x.com

---

## Why This Project

SecGuardian is not a "toy project". It is a production-grade, AI-native security audit platform that **replaces a $50K human security consultant with an AI system that thinks like one**. It uses a novel architecture that no existing SAST tool employs: structured knowledge prompts as a reasoning engine, layered into three distinct analysis depths.

This project demonstrates the exact kind of "hardcore engineering" Elon asks for: **systems thinking, multi-platform build engineering, and the ability to design a product from competitive analysis through to deployable artifact.**

---

## What I Built (numbers that matter)

| Metric | Value |
|--------|-------|
| Total commits | 22 (clean, incremental development history) |
| Source files | 127 tracked |
| Detector rules | 30 structured detection rules across 4 namespaces + 3 languages |
| Security skills | 25 AI-driven analysis skills (17 deep audit + 8 language-specific) |
| Language coverage | C/C++, Java, Python, Go |
| Shell scripts | 8 production-grade build/deploy/CLI scripts |
| CI/CD integration | GitHub Actions + SARIF 2.1.0 output |
| Annotated vulnerabilities | 49 real code examples across 4 languages for accuracy benchmarking |
| Documentation | Full competitive analysis, commercialization roadmap, work plan |

---

## Architecture — What Makes This Different

### The Problem

Traditional SAST tools (CodeQL, Semgrep, Fortify) do **pattern matching**. They have 200-800 rules, each checking "does this line contain API X?" They produce 30-60% false positives. They require security experts to triage results. They cannot reason about business logic, data flow context, or sanitization adequacy.

### My Solution

SecGuardian uses a **3-tier AI-native architecture**:

```
Layer 1: secguard — AI-guided code vulnerability detection
  → 30 structured detectors, each with 4-step detection logic, FP exclusion tables
  → CWE + CVSS mapping, SARIF 2.1.0 output for GitHub Code Scanning
  → Namespace filtering (memory.*, system.*, crypto.*)

Layer 2: secaudit — AI deep security audit (flagship)
  → 17 domain-specific audit skills that think like human security consultants
  → Not pattern matching — context-aware reasoning about data flow
  → Example: taint-analysis skill performs 5-phase Source→Sink tracking
    with sanitization adequacy validation (not just true/false)

Layer 3: secreview — security code review
  → Language-specific anti-pattern detection
  → Best practice compliance checking
```

### The Taint Analysis Engine — An Example of Depth

Instead of a rule like "flag all `cursor.execute()` calls", SecGuardian's taint-analysis skill performs **five distinct phases**:

1. **Source Identification**: HTTP params, file uploads, WebSocket messages, DB query results, third-party API responses, environment variables, message queues, shared memory, NFS files — 12+ source categories
2. **Propagation Tracking**: Assignment, string formatting, array access, function call return values — with explicit rules for what propagates vs what sanitizes
3. **Sink Location**: SQL execution, command execution, XSS output, file operations, eval, SSRF, deserialization, privilege operations — 8 sink categories
4. **Sanitization Validation**: Distinguishes effective sanitization (parameterized queries, context-aware encoding, allowlist validation) from ineffective sanitization (blacklist filtering, client-only validation, trim(), wrong context encoding)
5. **Output Generation**: Propagation graph visualization, VULNERABLE/SAFE/NEEDS_REVIEW verdicts, per-path fix recommendations

**This is not a prompt template. It is a structured reasoning protocol.** Each of the 17 secaudit skills has equivalent depth.

---

## Engineering Discipline (the build system tells the story)

The project follows strict engineering practices:

1. **Clean git history**: 22 atomic commits, detailed messages, no "fix typo" or "WIP" noise
2. **Dual license architecture**: `LICENSE-CODE.txt` (MIT) for engine, `LICENSE-KNOWLEDGE.txt` (Proprietary) for AI knowledge base — proper IP separation from day one
3. **Multi-platform build pipeline**: Single `build.sh` orchestrates packaging → deployment to Claude Code, OpenCode, and Gemini CLI with zero configuration
4. **Integrity checking**: `tools/check.sh` validates all 30 detectors, 25 skills, 10 concepts, 4 language profiles, and version consistency across 3 extension manifests
5. **Competitive analysis**: Documented 3-layer market structure with 9 competitor comparison before writing production code

### How to deploy (evidence of engineering quality):

```bash
# One-command full lifecycle:
bash scripts/build.sh all --zip

# What happens:
# 1. package.sh reads 3 extension.json manifests
# 2. Assembles skills/ + knowledge/ per manifest specification
# 3. Generates Claude Code plugin manifest (.claude-plugin/plugin.json)
# 4. Copies slash commands (commands/*.md)
# 5. Deploys to Claude Code, OpenCode, Gemini CLI simultaneously
# 6. Optionally creates .zip archives for distribution
```

Every script supports `-h/--help` with structured documentation.

---

## Actual Code — What I Want You To Review

I'm not just sending a cover letter. Review the actual work:

### Core Architecture Files

| File | What It Shows |
|------|--------------|
| `skills/secaudit-taint-analysis/SKILL.md` | 5-phase taint analysis protocol (192 lines of structured reasoning) |
| `knowledge/detectors/buffer-overflow.md` | Detector design pattern with 4-step logic + FP exclusion table |
| `scripts/package.sh` | Multi-target build system reading JSON manifests |
| `scripts/secguardian.sh` | CLI entry point with full argument parsing and audit context assembly |
| `manifest.json` | Central project registry — product positioning, extension inventory |

### Testing & Benchmarking

| File | What It Shows |
|------|--------------|
| `examples/python-vuln-demo/src/webapp.py` | 7 real annotated vulnerabilities (SQLi, CMDi, SSTI, SSRF, secret exposure) |
| `scripts/benchmark.sh` | Accuracy measurement framework — TP/FP/FN tracking per detector per language |
| `tools/check.sh` | 7-point integrity checker (detector existence, JSON validity, version consistency) |

### Documentation That Actually Matters

| File | What It Shows |
|------|--------------|
| `docs/competitive-analysis.md` | 3-tier SAST market analysis, 9 competitor comparison, pricing strategy |
| `docs/roadmap-to-commercial.md` | Gap analysis, pricing model ($2K-$48K/year), unit economics, milestone timeline |
| `docs/work-plan.md` | Phased execution plan with KPIs, risk register, and working procedures |

---

## Why X Should Care

X is building the "everything app" — an application that handles payments, messaging, media, and likely financial transactions. **Every line of code in such an app is a potential security vulnerability.** Traditional SAST tools flag false positives; manual security audits cost $20K+ per engagement.

SecGuardian represents a new approach: **AI that audits code like a human security consultant**, understanding context instead of matching patterns. This scales security review to every PR, every push, without the $50K invoice.

I built this because I believe the next generation of developer tools won't be "better pattern matchers" — they'll be **reasoning systems** that think alongside engineers.

---

## How To Review This Application

1. Clone the repository: `git clone git@gitee.com:jonyan/secguardian.git`
2. Review the git log: `git log --oneline` (22 clean commits, no noise)
3. Read `skills/secaudit-taint-analysis/SKILL.md` to understand the reasoning depth
4. Run `bash tools/check.sh` to verify project integrity
5. Run `bash scripts/build.sh cc` to see the build pipeline work
6. Read `docs/competitive-analysis.md` for market context
7. Run `bash scripts/secguardian.sh list skills` to see the full capability inventory

---

## What I'd Build at X

Given the distributed systems challenges at X's scale, I would contribute in these areas:

1. **Security of the payment infrastructure** — applying taint analysis to trace every dollar through the system
2. **API gateway security** — building automated audit pipelines that catch auth bypass and injection before deployment
3. **Developer tooling** — creating the kind of multi-platform build systems and integrity checkers I've demonstrated in this project

I don't need a "senior" title. I just want to work on hard problems with engineers who care about quality.

---

— JonyAn (bjellick@163.com)
