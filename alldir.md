.
├── AGENTS.md
├── CHANGELOG.md
├── CLAUDE.md
├── DEVELOPER.md
├── GEMINI.md
├── LICENSE-CODE.txt
├── LICENSE-KNOWLEDGE.txt
├── README-EN.md
├── README.md
├── SECURITY.md
├── action.yml
├── alldir.md
├── build.sh
├── commands
│   ├── gemini
│   │   ├── secaudit.toml
│   │   ├── secfix.toml
│   │   ├── secguard.toml
│   │   └── secreview.toml
│   ├── secaudit.md
│   ├── secfix.md
│   ├── secguard.md
│   └── secreview.md
├── docs
│   ├── README.md
│   ├── SecGuardian-Technical-Whitepaper.pptx
│   ├── competitive-analysis.md
│   ├── dogfood
│   │   └── 2026-06-04-self-scan.md
│   ├── governance
│   │   ├── 00_Governance_Model.md
│   │   ├── 01_Security_Redlines.md
│   │   ├── 02_Secure_Coding.md
│   │   ├── 03_Architecture_Review.md
│   │   ├── 04_Threat_Modeling.md
│   │   ├── 05_SAST_Rules.md
│   │   ├── 06_SCA_Governance.md
│   │   ├── 07_Container_K8s.md
│   │   ├── 08_Cloud_Security.md
│   │   ├── 09_Release_Gates.md
│   │   ├── 10_Vuln_SLA.md
│   │   ├── 11_Privacy_Compliance.md
│   │   ├── 12_Security_KPI.md
│   │   └── README.md
│   ├── next-up.md
│   ├── reference
│   │   ├── beijing-ai-security-companies.md
│   │   ├── ci-integration-guide.md
│   │   ├── gitlab-ci-template.md
│   │   ├── interview-ppt.md
│   │   ├── portfolio-deepseek.md
│   │   └── whitepaper.md
│   ├── roadmap-to-commercial.md
│   ├── sdd
│   │   ├── README.md
│   │   ├── brainstorm-log.md
│   │   └── epics
│   │       ├── EPIC-001-core-scanning-engine
│   │       │   ├── FEATURE-001-output-protocol
│   │       │   │   ├── adr.md
│   │       │   │   ├── changes
│   │       │   │   │   ├── CHANGE-001-v5-directory-tree.md
│   │       │   │   │   └── CHANGE-002-finding-output-helper.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-quality-gates.md
│   │       │   │       ├── TASK-002-protocol-files.md
│   │       │   │       ├── TASK-003-renderer-directory-tree.md
│   │       │   │       ├── TASK-004-command-output-mode.md
│   │       │   │       └── TASK-005-record-finding-helper.md
│   │       │   ├── FEATURE-002-detector-quality
│   │       │   │   ├── adr.md
│   │       │   │   ├── changes
│   │       │   │   │   └── CHANGE-001-evidence-system.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-schema-update.md
│   │       │   │       ├── TASK-002-p0-missing-detectors.md
│   │       │   │       └── TASK-003-p1-p2-p3-batches.md
│   │       │   ├── FEATURE-003-verification-pipeline
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   └── spec.md
│   │       │   ├── FEATURE-004-output-protocol-v7
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-protocol-docs.md
│   │       │   │       ├── TASK-002-renderer-executive-summary.md
│   │       │   │       ├── TASK-003-renderer-remediation-pack.md
│   │       │   │       ├── TASK-004-renderer-report-simplify.md
│   │       │   │       ├── TASK-005-renderer-html-report.md
│   │       │   │       ├── TASK-006-e2e-verification.md
│   │       │   │       └── TASK-007-command-update.md
│   │       │   ├── FEATURE-005-indexer-robustness
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-index-json-stats.md
│   │       │   │       ├── TASK-002-js-minified-guard.md
│   │       │   │       ├── TASK-003-path-exclusion.md
│   │       │   │       └── TASK-004-lang-param.md
│   │       │   ├── FEATURE-006-finding-identity-redesign
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   └── spec.md
│   │       │   ├── FEATURE-007-strategic-repositioning
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   └── spec.md
│   │       │   ├── FEATURE-008-audit-framework
│   │       │   │   ├── adr.md
│   │       │   │   ├── changes
│   │       │   │   │   └── CHANGE-002-architecture-refinement.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   └── spec.md
│   │       │   ├── FEATURE-009-audit-domain-model
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   └── spec.md
│   │       │   └── epic.md
│   │       ├── EPIC-002-platform-engineering
│   │       │   ├── FEATURE-001-manifest-driven-tokens
│   │       │   │   ├── adr.md
│   │       │   │   ├── changes
│   │       │   │   │   └── CHANGE-001-renderer-decouple.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-sync-script.md
│   │       │   │       ├── TASK-002-tokenize-files.md
│   │       │   │       └── TASK-003-renderer-dynamic-load.md
│   │       │   ├── FEATURE-002-mcp-server
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-design-v0.1.md
│   │       │   │       ├── TASK-002-review-round-1.md
│   │       │   │       ├── TASK-003-review-round-2.md
│   │       │   │       └── TASK-004-implementation-backlog.md
│   │       │   ├── FEATURE-004-deployment-home-path
│   │       │   │   ├── adr.md
│   │       │   │   ├── changes
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   └── epic.md
│   │       ├── EPIC-003-code-health-and-hygiene
│   │       │   ├── FEATURE-001-code-health-fixes
│   │       │   │   ├── adr.md
│   │       │   │   ├── plan.md
│   │       │   │   ├── progress.md
│   │       │   │   ├── spec.md
│   │       │   │   └── tasks
│   │       │   │       ├── TASK-001-version-sync.md
│   │       │   │       ├── TASK-002-go-build-false-positive.md
│   │       │   │       ├── TASK-003-agents-docs.md
│   │       │   │       ├── TASK-004-js-parser-keywords.md
│   │       │   │       ├── TASK-005-parser-re-vars.md
│   │       │   │       ├── TASK-006-context-tests.md
│   │       │   │       └── TASK-007-go-mod-tidy.md
│   │       │   └── epic.md
│   │       └── EPIC-004-product-interface-consolidation
│   │           ├── FEATURE-001-command-unification
│   │           │   ├── adr.md
│   │           │   ├── plan.md
│   │           │   ├── progress.md
│   │           │   └── spec.md
│   │           └── epic.md
│   ├── templates
│   │   └── case-study-template.md
│   └── work-plan.md
├── examples
│   ├── cpp-vuln-demo
│   │   ├── session-ses_0d78.md
│   │   └── src
│   │       ├── allocator.c
│   │       ├── concurrency.c
│   │       ├── crypto.c
│   │       ├── memory_extra.c
│   │       ├── network.c
│   │       ├── parser.c
│   │       ├── system.c
│   │       └── windows.c
│   ├── fp-verification-demo-c
│   │   ├── README.md
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── p0_safe_functions.c
│   │       ├── p1_safecopy_wrapper.c
│   │       ├── p1_safequery_wrapper.c
│   │       ├── p2_bounds_checked.c
│   │       ├── p2_lock_guard.c
│   │       ├── p2_raii_memory.c
│   │       └── p3_edge_case.c
│   ├── fp-verification-demo-go
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── p0_safe_functions.go
│   │       ├── p1_safe_wrappers.go
│   │       ├── p2_counter_evidence.go
│   │       ├── p3_edge_go.go
│   │       └── tp_true_positives.go
│   ├── fp-verification-demo-java
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── p0_safe_functions.java
│   │       ├── p1_safe_wrappers.java
│   │       ├── p2_counter_evidence.java
│   │       ├── p3_edge_case.java
│   │       └── tp_true_positives.java
│   ├── fp-verification-demo-js
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── p0_safe_functions.js
│   │       ├── p1_safe_wrappers.js
│   │       ├── p2_counter_evidence.js
│   │       ├── p3_edge_js.js
│   │       └── tp_true_positives.js
│   ├── fp-verification-demo-python
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── p0_safe_functions.py
│   │       ├── p1_safe_wrappers.py
│   │       ├── p2_counter_evidence.py
│   │       ├── p3_edge_case.py
│   │       └── tp_true_positives.py
│   ├── go-vuln-demo
│   │   └── src
│   │       ├── crypto_utils.go
│   │       ├── execlike.go
│   │       └── webapp.go
│   ├── java-vuln-demo
│   │   └── src
│   │       ├── AuthController.java
│   │       ├── DeserializationService.java
│   │       └── UserController.java
│   ├── js-vuln-demo
│   │   ├── package.json
│   │   └── src
│   │       ├── auth.js
│   │       ├── crypto_utils.js
│   │       ├── dependency.js
│   │       ├── deserialization.js
│   │       ├── execlike.js
│   │       ├── file_ops.js
│   │       └── webapp.js
│   └── python-vuln-demo
│       ├── session-ses_0d30.md
│       └── src
│           ├── crypto_utils.py
│           ├── file_handler.py
│           └── webapp.py
├── extensions
│   ├── secaudit-secguardian
│   │   └── extension.json
│   ├── secfix-secguardian
│   │   └── extension.json
│   ├── secguard-secguardian
│   │   └── extension.json
│   └── secreview-secguardian
│       └── extension.json
├── internal
│   ├── context
│   │   ├── context.go
│   │   └── context_test.go
│   ├── dist
│   │   └── release
│   │       └── 0.12.0
│   │           ├── secguardian-index-0.12.0-darwin-amd64
│   │           ├── secguardian-index-0.12.0-linux-amd64
│   │           ├── secguardian-index-0.12.0-linux-arm64
│   │           └── secguardian-index-0.12.0-windows-amd64.exe
│   ├── go.mod
│   ├── go.sum
│   ├── indexer
│   │   ├── diff_parser.go
│   │   ├── diff_parser_test.go
│   │   ├── indexer.go
│   │   └── indexer_test.go
│   ├── main.go
│   └── parser
│       ├── parser_javascript.go
│       ├── parser_re.go
│       ├── parser_re_test.go
│       ├── parser_test_helpers.go
│       ├── parser_ts.go
│       ├── parser_ts_test.go
│       └── types.go
├── knowledge
│   ├── LICENSE.txt
│   ├── audit-rules
│   │   ├── auth-and-session.md
│   │   ├── authorization.md
│   │   ├── cryptography.md
│   │   ├── data-protection.md
│   │   ├── dependency-security.md
│   │   ├── http-security-headers.md
│   │   ├── information-exposure.md
│   │   ├── infra-hardening.md
│   │   ├── input-validation.md
│   │   ├── logging-and-monitoring.md
│   │   ├── output-encoding.md
│   │   ├── secrets-management.md
│   │   └── secure-transport.md
│   ├── guard-rules
│   │   ├── concurrency-data-race.md
│   │   ├── concurrency-deadlock.md
│   │   ├── concurrency-race-condition.md
│   │   ├── concurrency-thread-unsafe-signal.md
│   │   ├── crypto-aes-ecb-mode.md
│   │   ├── crypto-custom-crypto.md
│   │   ├── crypto-hardcoded-iv.md
│   │   ├── crypto-hardcoded-secrets.md
│   │   ├── crypto-insufficient-key-length.md
│   │   ├── crypto-password-storage.md
│   │   ├── crypto-tls-version.md
│   │   ├── crypto-weak-crypto-algorithm.md
│   │   ├── crypto-weak-random.md
│   │   ├── error-debug-mode-production.md
│   │   ├── error-exception-swallow.md
│   │   ├── error-log-sensitive-data.md
│   │   ├── error-panic-to-client.md
│   │   ├── error-stack-trace-leak.md
│   │   ├── error-unified-error-format.md
│   │   ├── memory-bad-cast.md
│   │   ├── memory-buffer-overflow.md
│   │   ├── memory-double-free.md
│   │   ├── memory-format-string.md
│   │   ├── memory-heap-buffer-overflow.md
│   │   ├── memory-integer-overflow.md
│   │   ├── memory-memory-leak.md
│   │   ├── memory-mismatched-free.md
│   │   ├── memory-null-dereference.md
│   │   ├── memory-off-by-one.md
│   │   ├── memory-oob-read.md
│   │   ├── memory-uninitialized-memory.md
│   │   ├── memory-use-after-free.md
│   │   ├── resource-file-double-close.md
│   │   ├── resource-file-leak.md
│   │   ├── resource-file-use-after-close.md
│   │   ├── resource-lock-misuse.md
│   │   ├── resource-refcount-misuse.md
│   │   ├── resource-socket-leak.md
│   │   ├── system-command-injection.md
│   │   ├── system-insecure-permissions.md
│   │   ├── system-insecure-temp-file.md
│   │   ├── system-path-traversal.md
│   │   ├── system-privilege-escalation.md
│   │   ├── system-secrets-detection.md
│   │   ├── system-symlink-attack.md
│   │   ├── system-toctou.md
│   │   ├── web-auth-bypass.md
│   │   ├── web-code-injection.md
│   │   ├── web-csrf.md
│   │   ├── web-deserialization.md
│   │   ├── web-excessive-data-exposure.md
│   │   ├── web-idor.md
│   │   ├── web-input-validation.md
│   │   ├── web-jwt-misuse.md
│   │   ├── web-mass-assignment.md
│   │   ├── web-missing-authentication.md
│   │   ├── web-missing-authorization.md
│   │   ├── web-nosql-injection.md
│   │   ├── web-open-redirect.md
│   │   ├── web-prototype-pollution.md
│   │   ├── web-resource-exhaustion.md
│   │   ├── web-sql-injection.md
│   │   ├── web-ssrf.md
│   │   ├── web-ssti.md
│   │   ├── web-unrestricted-upload.md
│   │   ├── web-xss.md
│   │   └── web-xxe.md
│   ├── language-index.md
│   ├── languages
│   │   ├── cpp.md
│   │   ├── go.md
│   │   ├── java.md
│   │   ├── javascript.md
│   │   └── python.md
│   ├── protocols
│   │   ├── findings-schema.json
│   │   ├── sarif-output.md
│   │   ├── scan-output.md
│   │   └── verification-protocol.md
│   ├── review-rules
│   │   ├── cpp.md
│   │   ├── go.md
│   │   ├── java.md
│   │   ├── javascript.md
│   │   └── python.md
│   ├── standards
│   │   ├── owasp-asvs-auth.md
│   │   ├── owasp-cheatsheet-mapping.md
│   │   ├── sei-cert-c.md
│   │   ├── sei-cert-cpp.md
│   │   ├── sei-cert-java.md
│   │   └── tls-config-reference.md
│   └── threat-catalog.md
├── manifest.json
├── scripts
│   ├── benchmark.sh
│   ├── bin
│   │   ├── secguardian-index-darwin-amd64
│   │   ├── secguardian-index-darwin-arm64
│   │   ├── secguardian-index-linux-amd64
│   │   ├── secguardian-index-linux-arm64
│   │   └── secguardian-index-windows-amd64.exe
│   ├── build.ps1
│   ├── check-command-templates.py
│   ├── ci-check.sh
│   ├── cwe-coverage.sh
│   ├── deploy.sh
│   ├── dev-verify.sh
│   ├── e2e-verify.sh
│   ├── gen-toml.sh
│   ├── gitee-release.sh
│   ├── github-release.sh
│   ├── install.ps1
│   ├── install.sh
│   ├── opencode-plugin.js
│   ├── package.sh
│   ├── record-finding.py
│   ├── release.sh
│   ├── render-report.py
│   ├── secfix.py
│   ├── secguardian-index
│   ├── secguardian-index.ps1
│   ├── secguardian.ps1
│   ├── self-check.sh
│   ├── sync-language-index.sh
│   ├── sync-manifest.sh
│   ├── sync-toml.sh
│   ├── sync-version.sh
│   ├── validate-findings.py
│   ├── validate-index.py
│   └── verify-lang-pipeline.sh
├── secguardian-0.12.0-source.tar.gz
├── skills
│   ├── LICENSE.txt
│   ├── secaudit
│   │   ├── SKILL.md
│   │   └── references
│   │       ├── attack-surface-analysis.md
│   │       ├── data-flow-analysis.md
│   │       ├── state-machine-analysis.md
│   │       ├── taint-analysis.md
│   │       └── trust-boundary-analysis.md
│   ├── secguard
│   │   ├── cpp
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       ├── cpp-security-cheatsheet.md
│   │   │       └── examples
│   │   │           └── output-schemas.md
│   │   ├── go
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       └── go-security-cheatsheet.md
│   │   ├── java
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       └── java-security-cheatsheet.md
│   │   ├── js
│   │   │   ├── SKILL.md
│   │   │   └── references
│   │   │       └── js-security-cheatsheet.md
│   │   └── python
│   │       ├── SKILL.md
│   │       └── references
│   │           └── python-security-cheatsheet.md
│   └── secreview
│       ├── cpp
│       │   ├── SKILL.md
│       │   └── references
│       │       └── cpp-anti-patterns.md
│       ├── go
│       │   ├── SKILL.md
│       │   └── references
│       │       └── go-anti-patterns.md
│       ├── java
│       │   ├── SKILL.md
│       │   └── references
│       │       └── java-anti-patterns.md
│       ├── js
│       │   ├── SKILL.md
│       │   └── references
│       │       └── js-anti-patterns.md
│       └── python
│           ├── SKILL.md
│           └── references
│               └── python-anti-patterns.md
└── tools
    └── check.sh

110 directories, 407 files
