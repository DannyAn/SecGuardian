# README Refactor Plan

> **Document**: README evolution report — NOT the actual README changes
> **Status**: Analysis only — README.md will be updated in a separate PR
> **Updated**: 2026-07-04

---

## 1. Current README Assessment

The current README (v0.12) was substantially rewritten during FEATURE-007
(Strategic Repositioning) and is in good shape relative to v0.5.
This plan identifies targeted improvements to align with the vNext architecture
documents, not a full rewrite.

### Section-by-Section Review

| Section | Verdict | Priority | Notes |
|---------|---------|----------|-------|
| Tagline | ✅ Keep | — | "AI-Native Security Workflow for the Entire SDLC" is good |
| Badges | ✅ Keep | — | Standard, informative |
| Paragraph 1 (Why paragraph) | 🔄 Tweak wording | Medium | "four automated security gates" → "four security roles" |
| Paragraph 2 (Standards) | ✅ Keep | — | OWASP/NIST/PCI DSS mention is correct |
| Quick Start | ✅ Keep | — | Clear, actionable |
| SDLC Pipeline (mermaid) | 🔄 Tweak | Low | Mermaid is good; labels could mention roles |
| Four Security Gates table | 🔄 Rename | High | "Gates" → "Roles" |
| Knowledge-Driven Audit | ✅ Keep | — | Accurately describes knowledge |
| Coverage table | ✅ Keep | — | Useful reference |
| Standards in Development | 🟡 Consider merge | Low | Could move to knowledge/ section |
| Developer Experience | ✅ Keep | — | Correctly prioritizes developer UX |
| CI/CD Integration | 🔄 Rewrite frame | Medium | Currently implies CI = primary scanning mode |
| Scan Output | ✅ Keep | — | Accurate artifact list |
| Vision (three phases) | ✅ Keep | — | Already aligns with vNext |
| License | ✅ Keep | — | |

---

## 2. Specific Changes Recommended

### Change 1: "Four Security Gates" → "Four Security Roles"

**Current wording**: "four automated security gates" in the hero paragraph.

**Problem**: "Gates" implies CI/blocker orientation.
"Roles" implies the product vision (AI Security Engineer).

**Suggested change**: Replace "gates" with "roles" or "personas" in the first
paragraph. For example:

> It integrates AI reasoning with security engineering practices to help teams
> build, review, fix, and release secure software through **four security roles**
> that accompany the SDLC.

**Impact**: Low effort, high signal. Aligns with architecture-vNext.md.

### Change 2: Gate Table → Role Table

**Current**: Table titled "The Four Security Gates" with columns
"Command / Stage / Primary User / Outcome".

**Problem**: 
- "Gate" is a CI concept, not a developer concept
- "Stage" could be more precise (SDLC stage)
- "Primary User" is useful but could add "Security Role"

**Suggested change**: Rename to "The Four Security Roles." Add a column
mapping each command to its role. For example:

| Command | Security Role | SDLC Stage | Primary User | Outcome |
|---------|--------------|-----------|-------------|---------|
| `/secguard` | Secure Coding Advisor | Implementation | Developers | Continuous secure coding guidance |
| `/secreview` | Security Reviewer | Pull Request | Reviewers | Context-aware AI code review |
| `/secfix` | Remediation Engineer | Fix | Developers | Auto-generated patches |
| `/secaudit` | Release Auditor | Release | Security/Ops | Evidence & compliance report |

**Impact**: Medium effort. Table layout changes but all content preserved.

### Change 3: CI/CD Integration Section Rewording

**Current section**: Describes CI integration with `mode: secaudit` and
"Supports GitLab SAST and Azure DevOps SARIF upload."

**Problem**: This section currently implies CI is a first-class scanning mode
with the same depth as AI Agent scanning. Per ADR-005, CI's value is telemetry
and gate decisions, not scanning.

**Suggested change**: Reframe the section to emphasize:

1. CI's role is **gate and trend**, not scanning
2. Developers should scan with AI Agent; CI should check
3. SARIF output is for evidence and dashboard, not primary analysis

Example rewording:

> **CI/CD Gate** — SecGuardian in CI mode checks whether the release meets
> your security baseline. It runs a telemetry-focused scan (faster, no LLM)
> against Rule Pack gates. If the security score dropped or new Critical
> findings appeared, CI blocks the release.
>
> SARIF output is uploaded for your security dashboard and compliance
> evidence chain. Daily scanning is done by developers via `/secguard`;
> CI is the safety net, not the primary scanner.

**Impact**: Medium effort. Changes the framing without removing any existing
functionality.

### Change 4: Add Architecture Reference

**Current**: README has no link to architecture documentation.

**Problem**: As the project evolves, readers need a reference for:
- Why the product is structured this way
- What is the Security Engine
- How CI differs from AI Agent
- Design principles

**Suggested change**: Add a small "Architecture" section (or link from
Knowledge-Driven Audit section):

> See [docs/architecture/architecture-vNext.md](docs/architecture/architecture-vNext.md)
> for the full architecture proposal.

**Impact**: Low effort. One link.

### Change 5: Add Design Principles Reference

**Current**: README lists features but not design principles.

**Problem**: Contributors need to understand why certain decisions were made
(LLM-agnostic, knowledge-first, developer UX priority).

**Suggested change**: Add a brief "Design Principles" callout or expand the
Vision section to reference the principles document.

**Impact**: Low effort. One paragraph or a bullet list.

---

## 3. Phased Execution Plan

### Phase 1: Narrative Alignment (Immediate, Small PR)

**Changes**:
- "four automated security gates" → "four security roles"
- Gate table → Role table (add Security Role column)
- Add link to docs/architecture/architecture-vNext.md
- Add link to docs/architecture/design-principles.md

**Risk**: Low. Only wording and link changes. No structural modifications.

**Verification**:
```bash
grep -c "gate" README.md  # Should decrease but not reach 0
grep -c "role" README.md  # Should increase
```

### Phase 2: CI Section Reframing (Medium PR)

**Changes**:
- Rewrite CI/CD Integration section to emphasize telemetry + gate
- Keep all existing YAML examples and platform support mentions
- Add "CI is the safety net, not the primary scanner" framing

**Risk**: Low-Medium. CI users might misinterpret reduced emphasis as
"CI support degraded." Must keep all existing CI features documented.

**Verification**: CI sections still contain correct YAML examples.
New framing does not remove any platform support mention.

### Phase 3: Architecture Depth (Future PR, after Engine v1)

**Changes**:
- Add Security Engine reference
- Update coverage narrative to include Engine path
- Add "Architecture" section or subsection under Knowledge-Driven Audit

**Risk**: Medium. Needs Engine to exist first (v0.15+).

**Verification**: Links to security-engine.md resolve.

---

## 4. Wording Evolution Tracker

| Current Term | Evolve To | When | Reason |
|-------------|-----------|------|--------|
| "security gate" | "security role" | Phase 1 | Role ≠ Gate |
| "scanning" (for CI) | "telemetry check" / "gate check" | Phase 2 | CI value is telemetry |
| "four commands" | "four security roles" | Phase 1 | Commands are surface; roles are substance |
| "AI security tool" | "AI security platform" | Phase 1 | Tool is narrow; platform is extensible |
| "output protocol" | "Contract" | Phase 3 | Protocol implies wire format; contract implies guarantee |

## 5. Decision Log

| Question | Decision | Rationale |
|----------|----------|-----------|
| Should we rename "Gates" to "Roles" now? | Yes, Phase 1 | Low effort, high alignment signal |
| Should we remove CI YAML examples? | No | Still valuable documentation, just reframe |
| Should we add a full Architecture section? | No, Phase 3 | Too early; Engine doesn't exist yet |
| Should we deprecate "scanner" language? | Yes, gradually | "Scanner" is too narrow for the vision |
| Should we change the mermaid diagram? | Maybe Phase 2 | Mermaid is visual; labels can evolve but diagram structure is fine |
