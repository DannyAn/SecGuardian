# Engine

> Audit framework execution engine — defines HOW to run a Rule Pack.

## Current: AI Agent + workflow-secaudit

The default `secguardian` Rule Pack is executed by `skills/secaudit/workflow-secaudit/SKILL.md`.
This is a 17-phase sequential pipeline: 1 setup phase + 16 rule phases.

## Execution Flow

### Step 0: Resolve Rule Pack

```
User input:
  /secaudit ./src python
    -> Default rulepack: secguardian
    -> Load: audit-framework/rulepacks/secguardian/pack.json

  /secaudit --rulepack secguardian ./src python
    -> Explicit rulepack selection
    -> Load: audit-framework/rulepacks/secguardian/pack.json

  /secaudit --rulepack owasp-asvs ./src python
    -> Load: audit-framework/rulepacks/owasp-asvs/pack.json
    -> Falls back to skills/secaudit/workflow-secaudit/ if no explicit workflow
```

### Step 1: Read workflow_source

```
pack.json.workflow_source = "skills/secaudit/workflow-secaudit/SKILL.md"
```

For the default pack, load the workflow-scaudit skill. For custom packs, load the
pack-defined workflow (from pack.json.workflow_source or rulepacks/<name>/workflow.md).

### Step 2: Execute Phases (from workflow)

The workflow-secaudit defines 17 phases:

```
Phase  0: Setup — Tech stack identification    (meta, no rule file)
Phase  1: Attack Surface Analysis              -> rules/attack-surface-analysis.md
Phase  2: Input Validation                     -> rules/input-validation.md
Phase  3: Authentication & Session             -> rules/auth-and-session.md
Phase  4: Authorization & Access Control        -> rules/authorization.md
Phase  5: Cryptography Security                -> rules/cryptography.md
Phase  6: Secrets & Credential Management      -> rules/secrets-management.md
Phase  7: Secure Transport                     -> rules/secure-transport.md
Phase  8: Data Protection & Privacy            -> rules/data-protection.md
Phase  9: Taint Analysis                       -> rules/taint-analysis.md
Phase 10: Data Flow & Trust Boundaries         -> rules/data-flow-analysis.md
Phase 11: Trust Boundary Analysis              -> rules/trust-boundary-analysis.md
Phase 12: State Machine & Business Logic       -> rules/state-machine-analysis.md
Phase 13: Dependency & Supply Chain Security   -> rules/dependency-security.md
Phase 14: Infrastructure Hardening             -> rules/infra-hardening.md
Phase 15: HTTP Security Headers                -> rules/http-security-headers.md
Phase 16: Logging & Audit Trail                -> rules/logging-and-monitoring.md
```

Each rule phase loads its file from `pack.json.rule_base_path` (default: `audit-framework/rulepacks/secguardian/rules/`)
with fallback to `knowledge/audit-rules/`.

### Step 3: Handle --focus

If `--focus <domain>` is specified, skip non-matching phases. Load only the
matching phase's rule file (or exact skill name from skills/secaudit/<name>/).

### Step 4: Post-Processing (from workflow)

After all phases complete:

1. Cross-phase deduplication
2. Severity ordering by CVSS
3. OWASP Top 10 / CWE Top 25 classification
4. Security score: 100 - (Critical*25 + High*10 + Medium*3 + Low*1)
5. Fix roadmap: immediate / short-term / long-term

### Step 5: Render

Invoke reporter to generate output (report.md + results.sarif + summary.json etc).

## Rule Pack vs Workflow

| Layer | Role | File |
|-------|------|------|
| Pack manifest | WHAT to run + ordering | `audit-framework/rulepacks/<name>/pack.json` |
| Workflow | HOW to run (phases, post-processing) | `skills/secaudit/workflow-secaudit/SKILL.md` |
| Rules | WHAT to check | `audit-framework/rulepacks/<name>/rules/*.md` (fallback: `knowledge/audit-rules/*.md`) |

## Extra (focus-only) Skills

Skills not in the default workflow but available via --focus:

| Skill | Reason |
|-------|--------|
| output-encoding | Valid standalone audit, not part of 16-phase pipeline |
