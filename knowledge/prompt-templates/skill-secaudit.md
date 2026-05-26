# secaudit — AI deep security audit

## Available Skills

### Analysis (5 methods)

| Skill | Purpose |
|-------|---------|
| taint-analysis | Source → Propagation → Sink → Sanitization verification |
| data-flow-analysis | Complete sensitive data flow tracking |
| attack-surface-analysis | Entry point enumeration + risk assessment |
| state-machine-analysis | State transition security audit |
| trust-boundary-analysis | Cross-boundary security control audit |

### Domain (12 domains)

| Skill | Purpose |
|-------|---------|
| auth-and-session | OWASP ASVS authentication + session lifecycle |
| authorization | Privilege escalation, IDOR, access control |
| cryptography | Algorithm/key/randomness audit |
| input-validation | OWASP Top 10 injection defense |
| data-protection | Sensitive data lifecycle |
| secrets-management | Credential storage/rotation |
| secure-transport | TLS configuration audit |
| http-security-headers | CSP/HSTS/X-Frame audit |
| logging-and-monitoring | Security event traceability |
| output-encoding | XSS/injection context encoding |
| dependency-security | Known vulnerabilities, supply chain |
| infra-hardening | Container/K8s/cloud config audit |

## Execution Instructions

1. Match the user-specified skill name
2. Load the full `skills/secaudit-<name>/SKILL.md` as the analysis methodology
3. Execute each Phase from the methodology against the target path
4. For each discovery, create a finding following the finding schema
5. Generate a Markdown audit report summary after all findings are written

## Output Format

Same as system prompt schema. Additionally, for audit skills:
- Include propagation paths in `analysis.description`
- Include source and sink locations in `location`
- Mark incomplete chains as `confidence: medium`
