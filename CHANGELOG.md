# Changelog

All notable changes to SecGuardian will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-05-30

### Added

- **Mandatory indexer invocation:** All three commands (`/secguard`, `/secaudit`,
  `/secreview`) now require `secguardian-index` execution before scanning. A
  pre-flight checklist validates the indexer binary, runs `--health`, and
  verifies `index.json` integrity. Scanning must abort if indexer is unavailable.
- **Unified deployment layout:** All three platforms (Claude Code, OpenCode,
  Gemini CLI) now share the same directory structure: `commands/`, `skills/`,
  `knowledge/`, `scripts/`. Relative path references (`../knowledge/`) resolve
  consistently across all platforms.
- **Cross-platform installer:** `scripts/install.sh` (macOS/Linux) and
  `scripts/install.ps1` (Windows) automate release zip extraction into target
  project directories with backup and health-check support.
- **Help support:** `scripts/build.sh -h` and `scripts/dev-deploy.sh -h` now
  display usage documentation.

### Changed

- **Command-Skill alignment:** Commands now own the indexer invocation and
  pre-flight checklist. Skills reference `index.json` as a pre-condition
  (symbols, call graph, alloc/free pairs) rather than scanning filesystem
  directly.
- **Gemini CLI deployment** uses unified top-level `knowledge/` and `scripts/`
  directories instead of nested `.knowledge-<ext>/` under `skills/`.
- **Release zips** for OpenCode and Gemini CLI now bundle complete content:
  `commands/` + `skills/` + `knowledge/` + `scripts/`.
- **Skill files** (all 25) now reference `index.json` context as their
  structural input, with `secguard-*` skills explicitly naming
  `symbols.functions`, `call_graph.edges`, and `alloc_free.pairs`.

### Fixed

- Go binary name detection now matches platform-specific variants
  (`secguardian-index-darwin-arm64`, etc.)
- Removed duplicate `web.open-redirect` entry and stream-of-consciousness
  notes from `detector-index.md`
- Cleaned up stale Go build artifacts from `internal/` directory
- Version synchronized across all sources: manifest.json, 3× extension.json,
  internal/main.go → 0.4.0

## [0.3.1] - 2026-05-27

### Added

- **Release pipeline:** `scripts/release.sh` builds all artifacts with
  standardized naming: `secguardian-<version>-<os>-<arch>`
- **Cross-platform support (Windows / macOS / Linux):**
  - `scripts/build.ps1`: PowerShell build script for Windows
  - `scripts/secguardian.ps1`: Windows CLI entry point delegating to Go binary
  - `.github/workflows/ci.yml`: CI pipeline with OS matrix (ubuntu/macos/windows)
  - `examples/cpp-vuln-demo/src/windows.c`: Windows-specific vulnerability examples
  - README: platform badges, cross-platform install instructions
- **Go CLI enhancements:**
  - `secguardian scan` — matches detectors to namespace filters
  - `secguardian audit` — lists 17 audit skills with topic labels
  - `secguardian review` — per-language review invocation
  - `secguardian help` — unified help with platform info

### Changed

- Go CLI is now the primary cross-platform entry point; bash scripts are
  complementary for extension deployment on macOS/Linux

## [0.3.0] - 2026-05-27

### Restructured

- **Namespace consolidation: 9 → 5 unified topics.** All three products
  (`/secguard`, `/secaudit`, `/secreview`) now share the same 5-category
  classification: `memory`, `concurrency`, `system`, `crypto`, `web`.
  Removed `general`, `java`, `python`, `go` namespaces. Language information
  is now carried in knowledge file frontmatter, not in the namespace path.

- **secaudit: all 17 SKILL.md now carry `topic` labels** in frontmatter,
  mapping each audit skill to one of the 5 unified topics.

- **secreview: all 4 language profiles now carry `topic` labels** in
  frontmatter, mapping each language to its applicable security topics.

- **detector-index.md: rewritten** as a cross-product reference. Now includes
  a "5-topic shared system" table mapping all three products to the same
  categories.

### Changed

- Merged `java.sql-injection` + `go.sql-injection` → `web.sql-injection`
  (single CWE-89 detector covering both Java and Go). Knowledge files
  consolidated.
- `java.deserialization` → `web.deserialization` (CWE-502)
- `python.code-injection` → `web.code-injection` (CWE-94)
- `general.input-validation` → `web.input-validation` (CWE-20)
- `general.resource-exhaustion` → `web.resource-exhaustion` (CWE-400)
- `general.insecure-permissions` → `system.insecure-permissions` (CWE-276)
- `internal/main.go` detector registry: renamed entries, unified categories
- `extension.json`: updated detector list with merged names
- `manifest.json`: namespace counts updated to 5 categories

### Fixed

- OpenCode extension format: now uses official `.md` file commands in
  `.opencode/commands/` (no fake `extension.json`)
- Gemini CLI extension format: verified against official
  `google-gemini/gemini-cli` docs — TOML files with `description` + `prompt`,
  skills in `.gemini/skills/`, GEMINI.md for context

### Added

- `CHANGELOG.md` — version tracking

## [0.2.1] - 2026-05-27

### Added

- 7 new detectors closing CWE Top 25 gaps:
  `input-validation` (CWE-20), `oob-read` (CWE-125),
  `insecure-permissions` (CWE-276), `resource-exhaustion` (CWE-400),
  `missing-authentication` (CWE-306), `unrestricted-upload` (CWE-434),
  `missing-authorization` (CWE-862)
- Standalone CLI binary: `scripts/secguardian` with `detectors` subcommand

### Changed

- `detector-index.md`: updated from 38 to 45 active detectors
- `manifest.json`: v0.2.0, active_count: 45, CWE Top 25: 25/25

### Removed

- `commands/opencode/extension.json` — not in OpenCode official format

## [0.1.0] - 2026-05-24

### Added

- Initial release: 18 active detectors, tree-sitter indexer, 17 audit skills
- Three-product architecture: `/secaudit`, `/secguard`, `/secreview`
- Claude Code + OpenCode + Gemini CLI extension support
- Scan Output Protocol 1.1 + SARIF 2.1.0 output
- CI/CD integration (GitHub Actions, GitLab CI)
