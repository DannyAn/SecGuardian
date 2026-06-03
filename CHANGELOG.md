# Changelog

All notable changes to SecGuardian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.3] - 2026-06-03

### Added

- **Professional audit report** (`report.md`): Six-section commercial deliverable
  with security score A-F + OWASP/CWE compliance dashboard + evidence chain +
  before/after fix code + prioritized remediation roadmap with estimated hours.
  Single file serves decision makers, tech leads, and engineers.
- **User workflow guidance**: Terminal output now includes "如何使用结果" section
  mapping each user intent to the right file.
- **Design journal** (`docs/design-journal.md`): Chronological record of 10 major
  architectural decisions with rationale, trade-offs, and lessons learned.
- **`knowledge/detectors/secrets-detection.md`**: 61st detector — regex patterns
  for hardcoded secrets + storage security matrix + lifecycle checklist.

### Changed

- **Output protocol v2.0 fully enforced**: All 6 commands and 27 skills now
  produce `report.md` (human) + `results.sarif` (machine) instead of legacy
  `findings/<id>.json`. Phase renamed "生成 Findings" → "持久化输出".
- **SARIF 2.1.0 compliance**: OASIS standard format with `partialFingerprints`
  dedup, per-tool upload support, field mapping documented.
- **`secguard/cpp` Phase 5-7** merged into single "Phase 5: 持久化输出".

### Removed

- **`knowledge/cheatsheets/`**: Over-engineered abstraction layer. Content
  migrated to detectors (secrets-detection) or skill references (tls-config).
  Remaining files (crypto-algorithms, injection-patterns) deleted — detectors
  already cover these domains exhaustively.
- **`knowledge/prompt-templates/`**: CLI-only prompt assembly, superseded by
  `commands/*.md` + `skills/*/SKILL.md`.
- **`internal/` dead packages**: `prompt/`, `budget/`, `reflection/`, `scheduler/`
  — 7 files, zero imports. `main.go` CLI subcommands (scan/audit/review/detectors)
  — 60-entry detector registry removed. Result: 13→6 Go files, 5→3 packages.
- **`secguardian-index` standalone binary from release**: Now only platform-
  specific zips. Binary included inside each zip.

### Fixed

- Protocol version: all descriptions upgraded to "Scan Output Protocol 2.0"
- `output-schemas.md` rewritten with Markdown finding example + SARIF field mapping
- `report.md` re-anchored as single commercial deliverable vs multi-file confusion

## [0.5.2] - 2026-06-02

### Added

- **Dual-mode cross-platform parser**: Tree-sitter (CGO, full AST) + pure-Go
  regex fallback (!CGO, works everywhere). Build-tag-separated: `parser_ts.go`
  and `parser_re.go`. Enables cross-compilation to Linux/Windows/darwin-amd64
  from any platform.
- **Cross-platform binary builds**: `package.sh` now produces 4 platform binaries:
  darwin-arm64 (tree-sitter), darwin-amd64 (regex), linux-amd64 (regex),
  windows-amd64.exe (regex).
- **`SECURITY.md`**: Corporate AV whitelisting document explaining unsigned
  binaries, security detector documentation content, and SHA-256 verification.

### Fixed

- **Parser panic**: Fixed slice bounds out of range in `safeUtf8Text()` — static
  1024-byte buffer overflowed on large tree-sitter nodes (e.g., crypto.c at 1382
  bytes). Replaced with `safeText()` using direct content byte access.
- **Detector registry completeness**: `main.go` detector count 45→60. Added 15
  missing detectors across error (6), web (5), and crypto (5) namespaces.
- **`scheduler.MatchFilter`**: Added comma-separated filter support, removed
  `"critical"` wildcard bug, added `web` and `error` group definitions.
- **`context_builder.FunctionBody`**: Previously always empty — now populated
  from source file.
- **Release platform naming**: Zip files now include platform suffix
  (`-darwin-arm64`) so users know exactly which platform each zip supports.
- **Gitee release idempotency**: `gitee-release.sh` now checks existing assets
  before uploading, preventing duplicate uploads on re-run.

### Changed

- **Version bump**: 0.5.1→0.5.2

## [0.5.1] - 2026-06-02

### Added

- **Knowledge cheatsheets** (`knowledge/cheatsheets/`): Cross-skill quick-reference
  layer between skills and detectors. 4 files: `crypto-algorithms.md`,
  `injection-patterns.md`, `secrets-detection.md`, `tls-config.md`. Each
  provides cross-language comparison tables and decision matrices.
- **Skill description triggers**: All 27 skills now include "当用户请求...时使用"
  trigger phrases for more accurate AI skill activation.
- **`secguard-*` topic fields**: All 5 language-specific security skills now
  have `topic` frontmatter (was missing).
- **Secreview content**: 5 `secreview-*` skills expanded from ~45 to ~100 lines
  each with structured Phase 1-5 execution flow, detection tables, code examples.
- **Claude Code plugin `knowledge/` and `scripts/`**: Previously only had
  `commands/` + `skills/`. Now includes full knowledge base and indexer binary.

### Fixed

- **Dead `knowledge/concepts/` references**: Replaced across `ci-check.sh`,
  `.gitee-ci.yml`, `.github/workflows/ci.yml`, `tools/check.sh` —
  all now reference `knowledge/cheatsheets/`.
- **CI Go version mismatch**: `.github/ci.yml` `go-version: 1.22` → `1.25`
  (matching `go.mod` requirement of 1.25.3).
- **`build.ps1` binary name**: `secguardian.exe` → `secguardian-index.exe` (6 places).
- **`sync-version.sh`**: Now also updates `const version` in `main.go`.
- **`secguardian.sh` detector count**: "26" → "60".
- **`benchmark.sh`**: Added deprecation notice (requires AI execution).
- **Manifest detector count**: `web: 22` → `web: 21` (namespace sum now correctly = 60).
- **Duplicate `secguardian-index` binary**: Removed stale 8.4MB build artifact
  from `scripts/bin/`. Added auto-cleanup in `package.sh`.
- **Command isolation paths**: `skills/secguardian/` → `skills/` across 6 files.
- **Protocol version**: Unified duplicate v1.0/v2.0 references in commands.
- **Scan ID format**: Fixed `secaudit.md` example to include `sec-` prefix.

### Changed

- **Brand extension namespacing**: All 3 platforms now use consistent
  `<brand>/` namespace structure:
  - Claude Code: `.claude/plugins/secguardian/`
  - OpenCode: `.opencode/plugins/secguardian/` (was flat `.opencode/skills/`)
  - Gemini CLI: `.gemini/extensions/secguardian/`
- **OpenCode plugin format**: Creates `plugin.json` manifest. Top-level
  `.opencode/skills/` and `.opencode/commands/` preserved for user's own
  handwritten files — extensions go under `plugins/<brand>/`.
- **Canonical binary naming**: Inside release zips, binary is always
  `secguardian-index` (no platform suffix). Deploy step handles renaming.
- **Shell wrapper simplification**: Tries canonical `bin/secguardian-index`
  first, falls back to platform-specific name for multi-platform dev builds.
- **Skill frontmatter standardization**: `topic` unified as YAML arrays across
  all 27 skills. H1 titles converted to descriptive Chinese.
- **Phase naming consistency**: `secguard` `Step N` → `Phase N`, matching
  `secaudit` convention.
- **Version bump**: 0.5.0→0.5.1

### Removed

- **`safeUtf8Text()`**: Deleted unsafe fixed-buffer function from parser.
- **Stale `.claude/extensions/` directory**: All content migrated to `.claude/plugins/`.
- **Legacy flat `.opencode/` deployment**: Auto-detected and cleaned on redeploy.

### Architecture

- **Self-contained detectors**: Concepts and detectors merged. Each detector now
  contains threat definition + detection logic + fix guidance + FP exclusion +
  pattern summary in a single file. Deleted `knowledge/concepts/` (10 files).
  Replaced with `knowledge/threat-catalog.md` (60-entry index).

- **Output protocol v2.0**: Human/machine-readable separation.
  - `report.md`: Markdown audit report (engineer-facing, with fix code examples)
  - `results.sarif`: Always generated (no `--sarif` flag needed)
  - `summary.json`: Lightweight dashboard statistics
  - `status.json`: CI pass/fail gate
  - `manifest.json`: Entry point (metadata + finding index)
  - Removed `findings/*.json` (v1.x legacy)

### Added

- **Error handling namespace** (6 detectors): `error.stack-trace-leak`,
  `error.log-sensitive-data`, `error.exception-swallow`,
  `error.unified-error-format`, `error.debug-mode-production`,
  `error.panic-to-client`

- **Crypto namespace expansion** (4→9): `crypto.aes-ecb-mode`,
  `crypto.tls-version`, `crypto.custom-crypto`, `crypto.password-storage`,
  `crypto.hardcoded-iv`

- **Web namespace expansion** (17→22): `web.mass-assignment`,
  `web.excessive-data-exposure`, `web.nosql-injection`,
  `web.prototype-pollution`, `web.ssti`

- **JavaScript/Node.js language support**: Language profile, `secguard-js`
  skill, `secreview-js` skill, anti-pattern detection matrix

- **Industry standards mapping**: SEI CERT C (28 rules), SEI CERT C++ (22
  rules), SEI CERT Java (22 rules), OWASP Cheat Sheet (30/31 sheets, 97%)

- **Finding ID format**: Self-describing IDs (`C-BOF-parser_c-L36` instead of
  `C-001`) using `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>` schema

- **Fix guidance in scan output**: Every finding includes concrete remediation
  code examples from detector `## 修复指引` sections

- **JS vulnerability examples**: `examples/js-vuln-demo/src/webapp.js` (10
  patterns: NoSQL injection, prototype pollution, SSTI, XSS, etc.)

### Changed

- **Multi-language coverage**: 69% of detectors now cover 3+ languages (was 38%)
  - Crypto detectors: C/C++ only → all 6 languages
  - System detectors: C/C++ only → all 6 languages
  - Web detectors: added JS coverage

- **Anti-pattern matrices deepened**: All 5 languages upgraded from description
  tables to concrete detection patterns (pattern → regex/AST → severity)

- **Detector precision enhanced**: Key detectors (buffer-overflow, format-string,
  null-dereference, hardcoded-secrets, race-condition) now include "when to
  report vs when NOT to report" binary decision tables

### Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Total detectors | 45 | 60 | +33% |
| Namespaces | 5 | 6 | +error |
| Languages supported | 4 | 5 | +JavaScript |
| Multi-language detectors | 38% | 69% | +81% |
| CWE Top 25 coverage | 88% | 100% | +12% |
| OWASP API Top 10 coverage | partial | 100% | new |
| Knowledge files | concepts × 17 | threat-catalog × 1 | simplified |

### Fixed

- `buffer-overflow.md`: duplicated detection patterns section removed
- `format-string.md`: broken FP table row fixed
- `scan-output.md` v1.x individual JSON findings replaced with professional
  Markdown reports

## [0.4.0] - 2026-05-30

### Added

- **Mandatory indexer invocation:** All three commands (`/secguard`, `/secaudit`,
  `/secreview`) now require `secguardian-index` execution before scanning.
- **Unified deployment layout:** All three platforms share the same directory
  structure: `commands/`, `skills/`, `knowledge/`, `scripts/`.
- **Cross-platform installer:** `scripts/install.sh` (macOS/Linux) and
  `scripts/install.ps1` (Windows) automate release zip extraction.

### Changed

- **Command-Skill alignment:** Commands own the indexer invocation and
  pre-flight checklist. Skills reference `index.json` as a pre-condition.
- **Gemini CLI deployment** uses unified top-level `knowledge/` and `scripts/`.

### Fixed

- Go binary name detection for platform-specific variants
- Removed duplicate `web.open-redirect` entry from `detector-index.md`
- Version synchronized across all sources → 0.4.0

## [0.3.1] - 2026-05-27

### Added

- **Release pipeline:** `scripts/release.sh` with standardized naming
- Cross-platform support (Windows / macOS / Linux)
- Go CLI enhancements: `scan`, `audit`, `review`, `help` subcommands

## [0.3.0] - 2026-05-27

### Restructured

- **Namespace consolidation**: 9 → 5 unified topics (memory, concurrency,
  system, crypto, web)
- All 17 secaudit SKILL.md now carry `topic` labels
- All 4 secreview language profiles now carry `topic` labels
- Language information moved to knowledge file frontmatter

## [0.2.1] - 2026-05-27

### Added

- 7 new detectors closing CWE Top 25 gaps
- Standalone CLI binary: `scripts/secguardian`

### Changed

- `detector-index.md`: 38 → 45 active detectors
- `manifest.json`: v0.2.0, CWE Top 25: 25/25

## [0.1.0] - 2026-05-24

### Added

- Initial release: 18 active detectors, tree-sitter indexer, 17 audit skills
- Three-product architecture: `/secaudit`, `/secguard`, `/secreview`
- Claude Code + OpenCode + Gemini CLI extension support
- Scan Output Protocol 1.1 + SARIF 2.1.0 output
- CI/CD integration (GitHub Actions, GitLab CI)
