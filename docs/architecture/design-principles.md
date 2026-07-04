# SecGuardian Design Principles (ADRs)

> **Document**: Architecture Decision Records
> **Status**: Ratified — all future modules must follow
> **Updated**: 2026-07-04
> **Format**: Each principle is an ADR: Context → Decision → Consequences

---

## ADR-001: Security Roles as Module Boundaries (Architecture Rule 0)

### Context

SecGuardian has four commands: `/secguard`, `/secreview`, `/secfix`, `/secaudit`.
Historically, these were described as "scanning levels" or "detection modes."
The README called them "Four Security Gates."

This framing creates a subtle problem: it implies the product is a scanner
with different modes. But the product vision is an AI Security Engineer —
a system that behaves like a security team member at each SDLC stage.

A human security team does not have "scanning level 1" and "scanning level 2."
It has **roles**: a Secure Coding Advisor, a Reviewer, a Remediation Engineer,
a Release Auditor.

### Decision

Every major module must correspond to a real-world security role.

| Command | Security Role | SDLC Stage |
|---------|--------------|------------|
| `/secguard` | Secure Coding Advisor | Implementation |
| `/secreview` | Security Reviewer | Pull Request |
| `/secfix` | Remediation Engineer | Fix |
| `/secaudit` | Release Auditor | Release |

Future modules must follow this pattern. A new module should be named after
a security role, not a technical function.

**Rationale**: Role-based boundaries are more stable than technology-based
boundaries. A "Secure Coding Advisor" stays relevant even if technology
changes; a "Taint Analyzer" does not.

### Consequences

- **Positive**: Module boundaries map naturally to user expectations
- **Positive**: Easy to add new roles (Compliance Officer, Security Architect)
- **Risk**: Existing internal code may not cleanly follow role boundaries
- **Mitigation**: This document establishes the convention; code refactoring
  happens gradually

---

## ADR-002: LLM Agnosticism

### Context

SecGuardian is sometimes described as "an AI security tool" or "an AI scanner."
This creates a dependency perception: if the AI model changes, the product changes.

In reality, the project's core assets are:
- `knowledge/detectors/` — 67 security detection rules
- `knowledge/protocols/` — Output schemas (SARIF, summary, delta)
- `knowledge/languages/` — Language profiles for 5 languages
- `indexer/` — Tree-sitter based code analysis

These assets work **without** a specific AI model. They just happen to be
currently consumed through LLM prompts.

The risk is product lock-in: if Claude Code disappears or changes pricing,
the product should still work with Gemini, OpenCode, or any future agent.

### Decision

SecGuardian is not an AI model. It is not tied to any specific LLM.

- **Knowledge is the product** — detectors, rules, protocols, language profiles
- **Prompt is an implementation detail** — current delivery mechanism
- **Model is replaceable** — architecture must not depend on a specific model's
  capabilities

### Consequences

- **Positive**: Security knowledge has a longer lifespan than any AI model
- **Positive**: No vendor lock-in for core detection capability
- **Risk**: Current skill files contain significant prompt engineering that
  assumes Claude Code's agentic capabilities
- **Mitigation**: P0 for Security Engine — extract deterministic logic from
  prompts into testable code

---

## ADR-003: Knowledge Is the Core Asset

### Context

The project contains 67 detector rules across 7 security namespaces. These rules
are Markdown files in `knowledge/detectors/`. Each rule is self-contained:
definition → detection pattern → fix → whitelist.

Currently, these rules are only loaded through SKILL.md prompts. The LLM reads
the prompt, loads matching rules, and applies them to the index.

This means:
- Rules are only executable through an AI Agent
- There is no independent way to run a rule
- Rules cannot be unit-tested without an LLM
- Rules cannot be exported to non-LLM tools (plain SAST, IDE plugins)

### Decision

Security knowledge (detectors, rules, protocols) is the primary product.
AI models and prompts are runtime dependencies, not the product itself.

Concretely:
- Every detector rule must be independently loadable and interpretable
- Rules should be versionable, reviewable, and testable without an LLM
- Knowledge modifications must not require model upgrades

### Consequences

- **Positive**: Rule quality improves (reviewed as code, not as prompt text)
- **Positive**: Rules outlast AI model versions
- **Positive**: Rules can be exported to other tools
- **Work to do**: Need a Knowledge Loader abstraction that reads rules
  independently of SKILL.md
- **Risk**: Structured rules (YAML/JSON) add tooling overhead
- **Mitigation**: Keep Markdown as authoring format; add structured metadata
  as optional frontmatter

---

## ADR-004: AI Agents Are Runtimes

### Context

SecGuardian currently supports three AI Agent platforms:
- Claude Code (primary, most feature-complete)
- OpenCode (secondary)
- Gemini CLI (tertiary)

Each has different:
- Extension/skill loading mechanisms
- MCP support levels
- System prompt constraints
- Tool call capabilities

Despite these differences, the product should behave consistently on all platforms.
Currently, platform-specific code lives in `extensions/` and platform-specific
skills in `skills/<platform>/`.

### Decision

AI Agents are execution environments (runtimes), not product features.
SecGuardian's behavior should be consistent across all runtimes.

Differences between runtimes should be limited to:
- Deployment mechanism (extension.json vs direct file copy)
- Platform-specific skill loading paths
- MCP tool availability

Core security behavior must not differ by runtime.

### Consequences

- **Positive**: Adding a new agent (e.g., Cursor, Copilot) only needs
  a new extension wrapper
- **Positive**: Product is not tied to a single agent's ecosystem
- **Risk**: Different agents have different capabilities (MCP support,
  tool call limits) that affect behavior
- **Mitigation**: Core knowledge loading through filesystem, not MCP tools,
  to minimize agent-specific dependency
- **Risk**: Skill files contain platform-specific path references
- **Mitigation**: Abstract paths through environment variables or config

---

## ADR-005: CI/CD's Primary Value Is Telemetry

### Context

SecGuardian's CI integration runs the same scan pipeline as the AI Agent.
The pipeline loads skills, calls LLM, and produces findings.

But CI and AI Agent have different needs:
- AI Agent: interactive, contextual, explanatory
- CI: deterministic, fast, gate-oriented
- AI Agent: findings → report → fix → re-scan
- CI: findings → gate → SARIF → dashboard

Running the full LLM pipeline in CI is:
- Slow (LLM latency adds minutes to CI)
- Expensive (per-scan API costs)
- Unstable (LLM variability affects gate decisions)
- Overkill (CI just needs "pass/fail" and trend data)

### Decision

CI/CD's primary value is telemetry and gate decisions, not scanning.
Scanning happens in the AI Agent (developer's daily workflow).
CI checks:
1. Did the security score change? (telemetry)
2. Are there any new Critical findings? (gate)
3. Did we regress on any namespace? (trend)

The CI path should be **lighter** than the AI Agent path.

### Consequences

- **Positive**: CI runs faster and cheaper (no LLM calls)
- **Positive**: Gate decisions are deterministic
- **Positive**: Security dashboard gets reliable trend data
- **Risk**: If CI only gates, developers might skip agent scanning
- **Mitigation**: CI gating creates incentive to scan earlier (shift-left)
- **Risk**: CI path quality might lag behind AI Agent path
- **Mitigation**: Periodic cross-validation: CI output vs AI Agent output

---

## ADR-006: Developer UX First

### Context

As the project matures, there is pressure to optimize for CI/CD.
CI requires:
- Zero-interaction operation
- Deterministic exit codes
- Standardized output (SARIF)
- Low latency

These requirements sometimes conflict with developer experience:
- Developer wants contextual conversation, not just exit codes
- Developer wants incremental scans, not full re-scans
- Developer wants narrative explanations, not just JSON

Prioritizing CI requirements over developer UX would make the product less
useful for its primary users.

### Decision

Developer UX is the primary design constraint. Never sacrifice AI Agent
interaction quality for CI compatibility.

- Commands are designed for interactive use first
- CI integration is adapted afterward
- If a feature works well for developers but poorly for CI, that's acceptable
- If a feature works well for CI but poorly for developers, it's not acceptable

### Consequences

- **Positive**: Developers love the tool (adoption driver)
- **Positive**: CI teams get better output because developer path is primary
- **Risk**: CI integration may seem second-class
- **Mitigation**: CI path is explicit about its tradeoffs; document clearly
  what CI does differently
- **Risk**: Developer-only features may not fit enterprise compliance needs
- **Mitigation**: Enterprise features (audit evidence, governance) built on
  shared core, not on AI Agent path

---

## ADR-007: Execution Strategy Convergence

### Context

Today, security analysis logic is distributed across:
- `commands/sec*.md` — Command definitions
- `skills/*/SKILL.md` — AI agent workflows and prompt templates
- `knowledge/detectors/*.md` — Detection rules (consumed through prompts)
- `knowledge/protocols/` — Output schemas

There is no unified execution model. Each skill file re-describes how to
run detectors. Each command re-describes its execution flow.

This distribution means:
- Cannot unit-test a detector without running an LLM
- Cannot add a new detector without modifying a skill prompt
- Execution behavior varies between platforms

### Decision

The current execution logic should eventually converge into a single
**execution strategy definition**. This is NOT a system or engine.
It is a shared understanding of:

1. **How rules are loaded** — from knowledge/detectors/ (currently Markdown)
2. **How rules are matched** — against index.json (currently LLM reasoning)
3. **How findings are generated** — structured output (currently LLM tool calls)

The convergence direction is "strategy" not "system":

```
Current:                Future:
skills/secguard/        execution strategy layer
  SKILL.md (prompt)       LLM-assisted strategy (current)
skills/secaudit/          deterministic strategy (research, optional)
  SKILL.md (prompt)       shared rule loading
                          shared index matching
```

**Important**: The current LLM-assisted strategy is the ONLY implemented
strategy. Deterministic matching is a research direction. No engine,
interface, or API should be abstracted before a second strategy exists.
See [engineering-principles.md](engineering-principles.md) EP-1 for the
premature abstraction constraint.

### Consequences

- **Positive**: Strategy definitions make execution logic reviewable
- **Positive**: When a second strategy arrives, it is a concrete addition,
  not an interface extraction
- **Work to do**: Document the current strategy clearly (done:
  [execution-model-current.md](execution-model-current.md))
- **Risk**: This ADR might still be interpreted as "build an engine"
- **Mitigation**: `engineering-principles.md` explicitly forbids premature
  kernel abstraction; any engine design requires 2+ production use cases
- **Risk**: Strategy divergence between skills
- **Mitigation**: The common pattern (indexer → knowledge → LLM → findings)
  is already shared; strategy documents codify what already exists
