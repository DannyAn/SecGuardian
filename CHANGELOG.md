# Changelog

All notable changes to SecGuardian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-05-31

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
