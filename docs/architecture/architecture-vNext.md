# SecGuardian Architecture — vNext

> **Document**: Architecture Overview
> **Status**: Proposal — coexists with today's implementation
> **Updated**: 2026-07-04 (Round 1 review — corrected from over-engineering)

---

## 1. Product Vision: AI Security Engineer

SecGuardian's long-term vision is an **AI Security Engineer** — a system that
accompanies the entire software development lifecycle, not as a scanning tool
but as a security team member.

A human security team has specialists:
- A **Secure Coding Advisor** who guides developers during implementation
- A **Security Reviewer** who examines pull requests
- A **Remediation Engineer** who generates and applies fixes
- A **Release Auditor** who certifies releases

SecGuardian models these roles. Each command corresponds to one role.

### Current Reality vs. Long-Term Vision

| Aspect | Today (v0.12) | Direction (v0.16+) |
|--------|--------------|-------------------|
| Role model | Implicit in commands | Explicit architecture boundary |
| Execution | Skill → LLM prompt → Finding | LLM-assisted strategy (primary), deterministic matcher (research) |
| LLM dependence | High (core logic in prompt) | Still primary; deterministic parts extracted incrementally |
| Knowledge loading | Via SKILL.md prompt | Via knowledge layer (same source) |
| Report rendering | render-report.py | Same output layer |

**Key constraint**: Every evolution must coexist with today's implementation.

---

## 2. Architecture Overview

The architecture is organized into four layers plus one strategy note.

```
┌──────────────────────────────────────────────────────┐
│                    RUNTIME LAYER                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │
│  │  AI Agent    │  │     CLI      │  │   CI/CD    │ │
│  │  (Claude/    │  │  (terminal)  │  │  (future   │ │
│  │   OpenCode/  │  │              │  │   consumer)│ │
│  │   Gemini)    │  │              │  │            │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬──────┘ │
│         │                │                │         │
│         └────────────────┴────────────────┘         │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                  COMMAND LAYER                        │
│  ┌──────────┐ ┌──────────┐ ┌──────┐ ┌──────────┐   │
│  │ /secguard│ │/secreview│ │/secfix│ │/secaudit │   │
│  │ Secure   │ │ Security │ │Remed. │ │ Release  │   │
│  │ Coding   │ │ Reviewer │ │Engine │ │ Auditor  │   │
│  │ Advisor  │ │          │ │er     │ │          │   │
│  └────┬─────┘ └────┬─────┘ └──┬───┘ └────┬─────┘   │
│       │            │          │          │          │
│       └────────────┴──────────┴──────────┘          │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│              STRATEGY NOTE (Future)                   │
│                                                       │
│  There is NO separate Security Engine today.          │
│                                                       │
│  All execution logic lives in LLM prompts inside      │
│  each skill's SKILL.md.                               │
│                                                       │
│  Future research: deterministic rule matching         │
│  that can produce base findings without LLM.          │
│  When it arrives, it will be a strategy switch        │
│  within the pipeline, not a new system.               │
│                                                       │
│  See docs/architecture/security-engine.md for         │
│  the strategy definition.                             │
└──────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                KNOWLEDGE LAYER                        │
│  ┌──────────┐ ┌──────────────┐ ┌────────────────┐   │
│  │Detectors │ │  Languages   │ │  Protocols     │   │
│  │67 rules  │ │ C/Go/Java/   │ │ Output v5.0    │   │
│  │in 7 nspcs│ │ Python/JS    │ │ SARIF 2.1.0    │   │
│  └──────────┘ └──────────────┘ └────────────────┘   │
│  ┌──────────┐ ┌──────────────┐ ┌────────────────┐   │
│  │Standards │ │  Threat Cat. │ │  Indexer Spec   │   │
│  │CERT/CWE/ │ │              │ │  (index.json    │   │
│  │OWASP/NIST│ │              │ │   schema)       │   │
│  └──────────┘ └──────────────┘ └────────────────┘   │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────┐
│                  OUTPUT LAYER                         │
│  ┌──────────┐ ┌──────────┐ ┌──────┐ ┌────────────┐ │
│  │ report.md│ │summary.js│ │SARIF │ │ findings/   │ │
│  │ (Human)  │ │on (Stats)│ │(CI)  │ │ (Machine)   │ │
│  └──────────┘ └──────────┘ └──────┘ └────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────┐ │
│  │delta.json│ │status.jso│ │ dashboard.html       │ │
│  │(Trend)   │ │n (Gate)  │ │ (Management)         │ │
│  └──────────┘ └──────────┘ └──────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Owns | Does NOT Own |
|-------|------|-------------|
| **Runtime** | Execution environment, user interaction, context | Security logic, rule knowledge |
| **Command** | Role-specific entry points, command contracts | Execution pipeline internals |
| **Knowledge** | Detector rules, language profiles, output protocols | How rules are executed (strategy note) |
| **Output** | Report rendering, format compliance, CI integration | Finding content, rule logic |

There is no "Security Engine" layer because it does not exist yet.
Execution strategy is a note, not a system. See [security-engine.md](security-engine.md)
and [execution-model-current.md](execution-model-current.md) for details.

---

## 3. Security Roles Model

Each command maps to a real-world security role. This is Architecture Rule 0.

### Role Definitions

| Command | Role | SDLC Stage | Primary Output | Decision Authority |
|---------|------|-----------|---------------|-------------------|
| `/secguard` | Secure Coding Advisor | Implementation | Guidance + Prevention hints | Developer |
| `/secreview` | Security Reviewer | Pull Request | Code review findings + risk assessment | Reviewer (human) |
| `/secfix` | Remediation Engineer | Fix | Patches + fix descriptions | Developer (applies) |
| `/secaudit` | Release Auditor | Release | Evidence report + compliance check | Security Team |

### Role Contracts

#### secguard: Secure Coding Advisor

```
When:  Developer is writing code
Needs: Current file / project index
Does:  Scans for vulnerabilities, provides fix guidance
Produces: Findings with remediation suggestions
Decides: Developer keeps or dismisses
```

#### secreview: Security Reviewer

```
When:  Pull Request is opened
Needs: Git diff + project index
Does:  Reviews only changed lines, assesses exploitability
Produces: Review findings with context
Decides: Reviewer approves or blocks
```

#### secfix: Remediation Engineer

```
When:  Findings exist (from secguard or secreview)
Needs: Finding details + project context
Does:  Generates deterministic, apply-able patches
Produces: .patch files + descriptions
Decides: Developer reviews and applies
```

#### secaudit: Release Auditor

```
When:  Release candidate is ready
Needs: Complete project index + Rule Pack selection
Does:  Full audit against enterprise standards
Produces: Evidence report + compliance matrix + gate decision
Decides: Security team certifies release
```

---

## 4. Data Flow

### Current Data Flow (v0.12) — The Only Pipeline

```
Source Code
    │
    ▼
┌──────────────────┐
│ secguardian-index │  (Go binary, Tree-sitter / Regex)
│  Parse → Symbol  │
│  Table → Call    │
│  Graph → Alloc   │
│  /Free → Lock    │
│  Graph           │
└────────┬─────────┘
         │
         ▼  index.json
┌──────────────────┐
│   SKILL.md       │  (Markdown — loaded by AI Agent)
│  Loads knowledge │
│  /detectors/     │
│  + index.json    │
│  + user prompt   │
└────────┬─────────┘
         │
         ▼  (LLM processes rules against index — single pass)
┌──────────────────┐
│  LLM (AI Agent)  │  (Claude / Gemini / et al.)
│  Reads rules +   │
│  index → reasons │
│  → generates     │
│  findings        │
└────────┬─────────┘
         │
         ▼  findings.json
┌──────────────────┐
│  render-report.py│  (Python renderer)
│  → report.md     │
│  → results.sarif │
│  → summary.json  │
│  → status.json   │
│  → delta.json    │
│  → manifest.json │
│  → dashboard.html│
└──────────────────┘
```

This is the **only execution path**. No branch, no fork, no dual runtime.
See [execution-model-current.md](execution-model-current.md) for the detailed
stage breakdown.

### Future Direction (Strategy Evolution)

If deterministic rule matching is explored (future research), it will be
a **strategy switch within the same pipeline**, not a separate system:

```
Source Code → indexer → knowledge rules
                           │
                    ┌──────┴──────┐
                    ▼              ▼
         LLM-assisted strategy   Deterministic matcher (research)
                    │              │
                    └──────┬──────┘
                           ▼
                    findings → output layer
```

**Current**: LLM-assisted strategy (only).
**Research**: Deterministic strategy (no implementation before indexer quality
and rule structure are proven).

---

## 5. Evolution Path

The path from today's architecture is gradual. Each phase coexists with
the previous. Engine/systems-level abstraction is explicitly avoided.

### Phase 1: Architecture Documentation (v0.13) — ✅ Complete

**What**: Establish architecture vocabulary, document boundaries, clarify roles.

| Deliverable | Status |
|------------|--------|
| architecture-vNext.md | ✅ This document |
| runtime-model.md | ✅ Execution contexts, not dual runtime |
| security-engine.md | ✅ Strategy layer, not a system |
| design-principles.md | ✅ 7 ADRs |
| engineering-principles.md | ✅ Anti-over-engineering constraints |
| execution-model-current.md | ✅ Single pipeline documentation |
| readme-refactor-plan.md | ✅ README evolution plan |
| SDD Feature Package | ✅ Complete |

**Code changes**: None.

### Phase 2: Knowledge Extraction (v0.14)

**What**: Extract structured metadata from detector rules incrementally.
No engine. No DSL. Just better rule structure for LLM consumption.

| Change | Today | Tomorrow |
|--------|-------|----------|
| Rule metadata | Pure Markdown | Markdown + optional YAML frontmatter |
| Knowledge loading | Via prompt only | Via prompt + structured extract |
| Index matching | LLM reads index.json | Reference matcher for simple patterns |

**Coexistence**: LLM-assisted strategy remains primary. Structured metadata
is optional — rules still work as pure Markdown.

### Phase 3: Strategy Exploration (v0.15)

**What**: Explore whether 1-2 unambiguous detectors (e.g., hardcoded-credentials)
can produce deterministic findings without an LLM. **Research phase** —
not a production engine.

| Component | Approach |
|-----------|----------|
| Detector selection | Pick patterns with low false-positive risk |
| Implementation | Standalone script, not a shared interface |
| Validation | Engine output vs LLM output on same codebase |
| Decision | If match rate > 95%, promote to optional strategy |

**Constraint**: No SecurityEngine interface, no API, no telemetry schema.
Just a concrete function that matches one rule.

### Phase 4: Consumption Mode Expansion (v0.16+)

**What**: Support CI/CD as an artifact consumer of the existing pipeline.
No new execution path. CI reads from the same output directory.

| Runtime | Execution | LLM |
|---------|-----------|-----|
| AI Agent | LLM-assisted (primary) | ✅ Full analysis + explanation |
| CLI | LLM-assisted | ✅ Full |
| CI/CD (future) | Same pipeline, reads SARIF | ❌ Gate-only mode (research) |

### Phase 5: Governance Platform (v0.17+)

**What**: Add enterprise features on top of existing pipeline:
- Custom Rule Packs (organization-specific rules)
- Compliance mapping (OWASP ASVS, NIST SSDF, PCI DSS)
- Security dashboard with trend history
- Evidence chain for audits

All built on the same pipeline. No architecture change.
See [engineering-principles.md](engineering-principles.md) for constraints.

---

## 6. Architecture Invariants

These rules must never be violated:

1. **Commands are roles** — Each command maps to a real security role
2. **Knowledge is independent** — Detectors, rules, protocols work without AI
3. **LLM is replaceable** — No architecture dependency on a specific model
4. **CI/CD is artifact consumer** — Not a separate runtime
5. **Developer UX dominates** — Never sacrifice CLI/Agent experience for CI
6. **One pipeline** — No execution path duplicates

See [engineering-principles.md](engineering-principles.md) for the expanded
version of these invariants.

---

## 7. Mapping to Current Project Structure

| Architecture Layer | Current Location | Notes |
|--------------------|-----------------|-------|
| Runtime | `.claude/plugins/secguardian/` | Same across agents |
| Command | `commands/sec*.md` | 4 command definitions |
| Security Engine | (does not exist) | Strategy note in docs; not a system |
| Knowledge | `knowledge/{detectors,languages,protocols,standards}/` | Version-controlled Markdown |
| Indexer | `internal/` | Go binary, Tree-sitter + Regex |
| Output | `render-report.py` + scan output directory | v5.0 protocol |
| Engine Contract | `internal/engine/engine_contract.md` | Spec: engine boundaries |
| Output Contract | `internal/output/output_contract.md` | Spec: renderer boundaries |
| CI/CD Interface | `docs/ci-cd-interface.md` | Spec: CI as artifact consumer |

---

## 8. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Premature engine abstraction | Wasted effort, divergent output | engineering-principles.md EP-1 forbids this |
| Rule structure assumption | DSL before need | EP-5: knowledge stays Markdown until proven otherwise |
| CI pipeline split | Debug hell | EP-6: one pipeline, CI is artifact consumer |
| LLM dependency too deep | Hard to evolve | Phase 2 starts incremental knowledge extraction |
