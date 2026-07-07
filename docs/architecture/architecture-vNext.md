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
| Execution | Skill → LLM prompt → Finding | Signal-LLM collaboration (signals anchor + LLM reasons) |
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
│            EXECUTION STRATEGY LAYER                    │
│                                                       │
│  ┌─────────────────┐  ┌──────────────────┐           │
│  │ 确定性信号层      │  │  LLM 推理层       │           │
│  │ (Indexer)        │  │ (AI Agent)       │           │
│  │                  │  │                  │           │
│  │ 锚定 + 预筛      │  │ 语义分析 + 补丁  │           │
│  │ + 去重           │  │ + 解释说明       │           │
│  └────────┬─────────┘  └────────┬─────────┘           │
│           └──────────┬───────────┘                    │
│                      ▼                                │
│               findings.json                           │
│                                                       │
│  No separate Engine binary. Indexer + AI Agent        │
│  collaborate through index.json.                      │
│                                                       │
│  See docs/architecture/security-engine.md for         │
│  the Signal-LLM collaboration model.                  │
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

If signal enhancement enables richer pre-filtering (future versions), it will be
a **data-quality improvement within the same pipeline**, not a separate system:

```
Source Code → indexer → knowledge rules
                           │
                    ┌──────┴──────┐
                    ▼              ▼
         Signal-LLM collaboration   Enhanced signals (future)
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

### Phase 2: Signal Enhancement R1 (v0.14)

**What**: Enhance deterministic signal quality — cross-file call graphs and type
hierarchy extraction. No engine. No DSL. Just better indexer output.

| Change | Today | Target |
|--------|-------|--------|
| Call graph scope | Same-file `strings.Contains` | Cross-file global symbol table matching |
| Type information | Names only | Inheritance chains, interface implementations, Go embedding |
| Index output | Current `call_graph.edges` | New `type_hierarchy.nodes` + `type_hierarchy.edges` |

**Impact**: Detectors that need call-chain analysis (taint tracking) get more
accurate pre-filtering. Type-based detectors get reliable type relationships.
LLM reasoning is not replaced — it benefits from richer, more accurate signal input.

### Phase 3: Signal Enhancement R2 (v0.15)

**What**: Data-flow pre-analysis and CI fast gate. Research phase —
may require IR beyond Tree-sitter AST capability.

| Component | Approach |
|-----------|----------|
| Source-sink pairing | Function parameter → sensitive operation mapping |
| Variable reachability | Which functions can reach which variable assignments |
| CI fast gate | Anchor check + pre-filter match rate (no LLM) |

**Constraint**: No SecurityEngine interface, no API, no telemetry schema.
Signal enhancements are concrete indexer improvements. CI fast gate reads
artifacts; it does not execute analysis.

> ⚠️ **Research phase**: Data-flow analysis may need an IR layer beyond
> Tree-sitter AST. This milestone will be re-evaluated after v0.14 signals
> are validated in production.

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
| Security Engine | (no separate binary) | Indexer signals + LLM reasoning collaborate through index.json |
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
| Signal quality insufficient for anchoring | Weak pre-filtering, missed findings | Phase 2 progressively enhances indexer output |
| Rule structure assumption | DSL before need | EP-5: knowledge stays Markdown until proven otherwise |
| CI pipeline split | Debug hell | EP-6: one pipeline, CI is artifact consumer |
| LLM variability across platforms | Inconsistent findings | Anchor + evidence constraints ensure traceability; pre-filter scopes LLM attention |
