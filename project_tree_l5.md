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
├── build.sh
├── commands
│   ├── claude
│   │   ├── secaudit.md
│   │   ├── secfix.md
│   │   ├── secguard.md
│   │   └── secreview.md
│   ├── gemini
│   │   ├── secaudit.toml
│   │   ├── secfix.toml
│   │   ├── secguard.toml
│   │   └── secreview.toml
│   └── opencode
│       ├── secaudit.md
│       ├── secfix.md
│       ├── secguard.md
│       └── secreview.md
├── dist
│   ├── secaudit-secguardian
│   │   ├── commands
│   │   │   ├── claude
│   │   │   └── opencode
│   │   ├── extension.json
│   │   ├── knowledge
│   │   │   ├── SECURITY.md
│   │   │   ├── protocols
│   │   │   ├── standards
│   │   │   └── threat-catalog.md
│   │   ├── scripts
│   │   │   ├── bin
│   │   │   ├── init-scan.sh
│   │   │   ├── opencode-plugin.js
│   │   │   ├── record-finding.py
│   │   │   ├── render-report.py
│   │   │   ├── secguardian-index
│   │   │   ├── secguardian-index.ps1
│   │   │   ├── validate-findings.py
│   │   │   └── validate-index.py
│   │   └── skills
│   │       └── secaudit
│   ├── secguard-secguardian
│   │   ├── commands
│   │   │   ├── claude
│   │   │   └── opencode
│   │   ├── extension.json
│   │   ├── knowledge
│   │   │   ├── SECURITY.md
│   │   │   ├── protocols
│   │   │   ├── standards
│   │   │   └── threat-catalog.md
│   │   ├── scripts
│   │   │   ├── bin
│   │   │   ├── init-scan.sh
│   │   │   ├── opencode-plugin.js
│   │   │   ├── record-finding.py
│   │   │   ├── render-report.py
│   │   │   ├── secguardian-index
│   │   │   ├── secguardian-index.ps1
│   │   │   ├── validate-findings.py
│   │   │   └── validate-index.py
│   │   └── skills
│   │       ├── cpp
│   │       ├── go
│   │       ├── java
│   │       ├── js
│   │       └── python
│   └── secreview-secguardian
│       ├── commands
│       │   ├── claude
│       │   └── opencode
│       ├── extension.json
│       ├── knowledge
│       │   ├── SECURITY.md
│       │   ├── protocols
│       │   ├── standards
│       │   └── threat-catalog.md
│       ├── scripts
│       │   ├── bin
│       │   ├── init-scan.sh
│       │   ├── opencode-plugin.js
│       │   ├── record-finding.py
│       │   ├── render-report.py
│       │   ├── secguardian-index
│       │   ├── secguardian-index.ps1
│       │   ├── validate-findings.py
│       │   └── validate-index.py
│       └── skills
│           ├── cpp
│           ├── go
│           ├── java
│           ├── js
│           └── python
├── docs
│   ├── LLM-Investigation-Architecture-Guide.md
│   ├── README.md
│   ├── SecGuardian-Technical-Whitepaper.pptx
│   ├── architecture
│   │   ├── architecture-vNext.md
│   │   ├── design-principles.md
│   │   ├── engineering-principles.md
│   │   ├── execution-model-current.md
│   │   ├── readme-refactor-plan.md
│   │   ├── review-arch-deepseek.md
│   │   ├── review-arch-round1.md
│   │   ├── review-arch-round2.md
│   │   ├── review-arch-round3.md
│   │   ├── review-check20260705.md
│   │   ├── runtime-model.md
│   │   └── security-engine.md
│   ├── bugfix
│   │   ├── prod-secguard-bug.md
│   │   └── prod-secreview-bug.md
│   ├── ci-cd-interface.md
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
│   ├── platform-install-conventions.md
│   ├── reference
│   │   ├── beijing-ai-security-companies.md
│   │   ├── ci-integration-guide.md
│   │   ├── gitlab-ci-template.md
│   │   ├── interview-ppt.md
│   │   ├── portfolio-deepseek.md
│   │   └── whitepaper.md
│   ├── roadmap-to-commercial.md
│   ├── scan-report-no-answers.md
│   ├── sdd
│   │   ├── README.md
│   │   ├── brainstorm-log.md
│   │   ├── epics
│   │   │   ├── EPIC-001-core-scanning-engine
│   │   │   ├── EPIC-002-platform-engineering
│   │   │   ├── EPIC-003-code-health-and-hygiene
│   │   │   ├── EPIC-004-product-interface-consolidation
│   │   │   ├── EPIC-005-architecture-refactoring
│   │   │   ├── EPIC-006-system-quality-engineering
│   │   │   ├── EPIC-007-indexer-signal-refactoring
│   │   │   ├── EPIC-008-oop-semantic-indexing
│   │   │   ├── EPIC-009-llm-reliability-engine
│   │   │   ├── EPIC-010-investigation-engine
│   │   │   └── signal-matrix-architecture.md
│   │   ├── req-20260704.md
│   │   ├── req-20260709-worker-isolation.md
│   │   ├── req=20260707.md
│   │   └── verification-three-rounds.md
│   ├── templates
│   │   └── case-study-template.md
│   └── work-plan.md
├── examples
│   ├── cpp-vuln-demo
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── allocator.c
│   │       ├── concurrency.c
│   │       ├── crypto.c
│   │       ├── memory_extra.c
│   │       ├── network.c
│   │       ├── p0_safe_functions.c
│   │       ├── p1_safecopy_wrapper.c
│   │       ├── p1_safequery_wrapper.c
│   │       ├── p2_bounds_checked.c
│   │       ├── p2_lock_guard.c
│   │       ├── p2_raii_memory.c
│   │       ├── p3_edge_case.c
│   │       ├── parser.c
│   │       ├── system.c
│   │       └── windows.c
│   ├── cpp-vuln-demo-no-answers
│   │   ├── $SCAN_DIR
│   │   │   └── findings
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── session-ses_0ba6-haha.md
│   │   ├── session-ses_0ba6-secguard-c.md
│   │   └── src
│   │       ├── allocator.c
│   │       ├── concurrency.c
│   │       ├── crypto.c
│   │       ├── memory_extra.c
│   │       ├── network.c
│   │       ├── p0_safe_functions.c
│   │       ├── p1_safecopy_wrapper.c
│   │       ├── p1_safequery_wrapper.c
│   │       ├── p2_bounds_checked.c
│   │       ├── p2_lock_guard.c
│   │       ├── p2_raii_memory.c
│   │       ├── p3_edge_case.c
│   │       ├── parser.c
│   │       ├── system.c
│   │       └── windows.c
│   ├── go-vuln-demo
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── crypto_utils.go
│   │       ├── execlike.go
│   │       ├── p0_safe_functions.go
│   │       ├── p1_safe_wrappers.go
│   │       ├── p2_counter_evidence.go
│   │       ├── p3_edge_go.go
│   │       ├── tp_true_positives.go
│   │       └── webapp.go
│   ├── go-vuln-demo-no-answers
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── session-ses_0ba2-go.md
│   │   └── src
│   │       ├── crypto_utils.go
│   │       ├── execlike.go
│   │       ├── p0_safe_functions.go
│   │       ├── p1_safe_wrappers.go
│   │       ├── p2_counter_evidence.go
│   │       ├── p3_edge_go.go
│   │       ├── tp_true_positives.go
│   │       └── webapp.go
│   ├── java-vuln-demo
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── session-ses_0c3f.md
│   │   └── src
│   │       └── com
│   ├── java-vuln-demo-no-answers
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       └── com
│   ├── js-vuln-demo
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── package.json
│   │   └── src
│   │       ├── auth.js
│   │       ├── crypto_utils.js
│   │       ├── dependency.js
│   │       ├── deserialization.js
│   │       ├── execlike.js
│   │       ├── file_ops.js
│   │       ├── p0_safe_functions.js
│   │       ├── p1_safe_wrappers.js
│   │       ├── p2_counter_evidence.js
│   │       ├── p3_edge_js.js
│   │       ├── tp_true_positives.js
│   │       └── webapp.js
│   ├── js-vuln-demo-no-answers
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── package.json
│   │   └── src
│   │       ├── auth.js
│   │       ├── crypto_utils.js
│   │       ├── dependency.js
│   │       ├── deserialization.js
│   │       ├── execlike.js
│   │       ├── file_ops.js
│   │       ├── p0_safe_functions.js
│   │       ├── p1_safe_wrappers.js
│   │       ├── p2_counter_evidence.js
│   │       ├── p3_edge_js.js
│   │       ├── tp_true_positives.js
│   │       └── webapp.js
│   ├── python-vuln-demo
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   └── src
│   │       ├── crypto_utils.py
│   │       ├── file_handler.py
│   │       ├── p0_safe_functions.py
│   │       ├── p1_safe_wrappers.py
│   │       ├── p2_counter_evidence.py
│   │       ├── p3_edge_case.py
│   │       ├── tp_true_positives.py
│   │       └── webapp.py
│   ├── python-vuln-demo-no-answers
│   │   ├── $SCAN_DIR
│   │   │   └── findings
│   │   ├── benchmark.md
│   │   ├── expected-results.json
│   │   ├── session-ses_0ba2-fuck.md
│   │   └── src
│   │       ├── crypto_utils.py
│   │       ├── file_handler.py
│   │       ├── p0_safe_functions.py
│   │       ├── p1_safe_wrappers.py
│   │       ├── p2_counter_evidence.py
│   │       ├── p3_edge_case.py
│   │       ├── tp_true_positives.py
│   │       └── webapp.py
│   └── strip-all-demos.py
├── extensions
│   ├── secaudit-secguardian
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
│   ├── engine
│   │   └── engine_contract.md
│   ├── go.mod
│   ├── go.sum
│   ├── indexer
│   │   ├── diff_parser.go
│   │   ├── diff_parser_test.go
│   │   ├── indexer.go
│   │   ├── indexer_test.go
│   │   ├── prescreener.go
│   │   └── prescreener_test.go
│   ├── main.go
│   ├── output
│   │   └── output_contract.md
│   └── parser
│       ├── parser_call_site_test.go
│       ├── parser_javascript.go
│       ├── parser_re.go
│       ├── parser_re_test.go
│       ├── parser_signal_cgo_test.go
│       ├── parser_signal_test.go
│       ├── parser_test_helpers.go
│       ├── parser_ts.go
│       ├── parser_ts_test.go
│       └── types.go
├── knowledge
│   ├── protocols
│   │   ├── findings-schema.json
│   │   ├── sarif-output.md
│   │   ├── scan-output.md
│   │   └── verification-protocol.md
│   ├── standards
│   │   ├── cwe-mapping.md
│   │   ├── owasp-asvs-auth.md
│   │   ├── owasp-cheatsheet-mapping.md
│   │   ├── sei-cert-c.md
│   │   ├── sei-cert-cpp.md
│   │   ├── sei-cert-java.md
│   │   └── tls-config-reference.md
│   └── threat-catalog.md
├── manifest.json
├── project_tree_l4.md
├── project_tree_l5.md
├── scripts
│   ├── __pycache__
│   │   ├── migrate-detection-spec-to-frontmatter.cpython-312.pyc
│   │   ├── render-report.cpython-312.pyc
│   │   └── strip-answer-cards.cpython-312.pyc
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
│   ├── init-scan.sh
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
│   ├── uninstall.sh
│   ├── validate-findings.py
│   ├── validate-index.py
│   ├── verify-commands.sh
│   ├── verify-lang-pipeline.sh
│   └── verify-signals.sh
├── skills
│   ├── LICENSE.txt
│   ├── secaudit
│   │   ├── SKILL.md
│   │   ├── references
│   │   │   ├── attack-surface-analysis.md
│   │   │   ├── data-flow-analysis.md
│   │   │   ├── state-machine-analysis.md
│   │   │   ├── taint-analysis.md
│   │   │   └── trust-boundary-analysis.md
│   │   └── rules
│   │       ├── auth-and-session.md
│   │       ├── authorization.md
│   │       ├── cryptography.md
│   │       ├── data-protection.md
│   │       ├── dependency-security.md
│   │       ├── http-security-headers.md
│   │       ├── information-exposure.md
│   │       ├── infra-hardening.md
│   │       ├── input-validation.md
│   │       ├── logging-and-monitoring.md
│   │       ├── output-encoding.md
│   │       ├── secrets-management.md
│   │       └── secure-transport.md
│   ├── secguard
│   │   ├── cpp
│   │   │   ├── SKILL.md
│   │   │   ├── references
│   │   │   └── rules
│   │   ├── go
│   │   │   ├── SKILL.md
│   │   │   ├── references
│   │   │   └── rules
│   │   ├── java
│   │   │   ├── SKILL.md
│   │   │   ├── references
│   │   │   └── rules
│   │   ├── js
│   │   │   ├── SKILL.md
│   │   │   ├── references
│   │   │   └── rules
│   │   └── python
│   │       ├── SKILL.md
│   │       ├── references
│   │       └── rules
│   └── secreview
│       ├── cpp
│       │   ├── SKILL.md
│       │   ├── references
│       │   └── rules
│       ├── go
│       │   ├── SKILL.md
│       │   ├── references
│       │   └── rules
│       ├── java
│       │   ├── SKILL.md
│       │   ├── references
│       │   └── rules
│       ├── js
│       │   ├── SKILL.md
│       │   ├── references
│       │   └── rules
│       └── python
│           ├── SKILL.md
│           ├── references
│           └── rules
└── tools
    └── check.sh

149 directories, 337 files
