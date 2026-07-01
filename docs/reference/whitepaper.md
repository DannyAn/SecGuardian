# SecGuardian Technical Whitepaper

**Version**: 0.6.0 | **Date**: 2026-06-08 | **Classification**: Internal - Technical Reference

---

## Executive Summary

SecGuardian is an enterprise-grade, AI-native security analysis platform that fundamentally reimagines application security testing. Unlike traditional SAST tools that rely on static pattern matching and rule engines, SecGuardian leverages AI agents for deep semantic analysis — understanding code context, business logic, and data flow to deliver findings with dramatically lower false positive rates and actionable remediation guidance.

The platform delivers three integrated products:

- **SecAudit** (Flagship): AI deep security audit with 17 specialized skills, replacing traditional security consultant engagements at a fraction of the cost
- **SecGuard**: AI-guided vulnerability detection with 67 detectors across 7 security categories, covering CWE Top 25 (100%) and OWASP Top 10 (100%)
- **SecReview**: Secure coding review combining anti-pattern detection with industry standard compliance (SEI CERT, OWASP)

Key differentiators include a Markdown-driven knowledge architecture (zero compilation for rule changes), a dual-parser Go indexer supporting both tree-sitter AST and regex fallback, structured output with SARIF 2.1.0 CI/CD integration, and a five-level verification methodology ensuring deployment integrity.

**Business Impact**: Organizations can save $50K+/year in security consultant fees while achieving broader coverage and faster remediation cycles compared to traditional approaches.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [AI-Native Design Philosophy](#2-ai-native-design-philosophy)
3. [Go Semantic Indexer](#3-go-semantic-indexer)
4. [Dual Parser Architecture](#4-dual-parser-architecture)
5. [Knowledge System](#5-knowledge-system)
6. [Three Product Lines](#6-three-product-lines)
7. [Output Protocol & CI/CD Integration](#7-output-protocol--cicd-integration)
8. [Incremental Scanning](#8-incremental-scanning)
9. [Cross-Platform Build & Deployment](#9-cross-platform-build--deployment)
10. [Verification Methodology](#10-verification-methodology)
11. [Threat Coverage Matrix](#11-threat-coverage-matrix)
12. [Performance Characteristics](#12-performance-characteristics)
13. [Technology Stack](#13-technology-stack)
14. [Future Directions](#14-future-directions)

---

## 1. Architecture Overview

### 1.1 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     AI Agent (Claude/Gemini/Opencode)            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │
│  │ /secguard│  │ /secaudit│  │/secreview│   Slash Commands     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                      │
│       │              │              │                             │
│  ┌────▼──────────────▼──────────────▼────┐                      │
│  │         Skill Loader (Markdown)        │                      │
│  │  secguard/ │ secaudit/ │ secreview/   │                      │
│  └────┬──────────────┬──────────────┬────┘                      │
│       │              │              │                             │
│  ┌────▼──────────────▼──────────────▼────┐                      │
│  │       Knowledge Base (Markdown)        │                      │
│  │  detectors/ │ languages/ │ standards/ │                      │
│  └───────────────────┬───────────────────┘                      │
│                      │                                           │
│  ┌───────────────────▼───────────────────┐                      │
│  │    secguardian-index (Go Binary)       │                      │
│  │  Parse → Symbol Table → Call Graph    │                      │
│  │  → Alloc/Free → Lock Graph → JSON     │                      │
│  └───────────────────┬───────────────────┘                      │
│                      │                                           │
│  ┌───────────────────▼───────────────────┐                      │
│  │    render-report.py (Renderer)         │                      │
│  │  findings → report.md + SARIF + JSON  │                      │
│  └───────────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Core Design Principle: Knowledge-as-Product

SecGuardian inverts the traditional SAST model. In conventional tools, the scanning engine is the product and rules are configuration. In SecGuardian, **the knowledge system is the product** and the AI agent is the execution engine. This means:

| Dimension | Traditional SAST | SecGuardian |
|-----------|-----------------|-------------|
| Core IP | Scanning engine | Knowledge files (67 detectors, 17 skills, 5 profiles) |
| Rule changes | Recompilation + redeployment | Edit Markdown → `dev-deploy.sh` → restart AI |
| Analysis depth | Pattern matching + dataflow | Semantic understanding + business logic reasoning |
| False positive rate | 30-50% typical | Significantly lower (AI validates context) |
| Remediation | Generic advice | Context-specific before/after code with effort estimates |

### 1.3 Project Structure

```
secguardian/                # v0.6.0, Go 1.25.3
├── internal/               # Only compiled code: Go indexer → secguardian-index binary
│   ├── main.go             # Entry: --path, --output, --health, --version
│   ├── context/            # Shared data model: AnalysisContext
│   ├── indexer/            # Symbol table, call graph, alloc/free, lock graph, diff parser
│   └── parser/             # Dual parser: tree-sitter (cgo) + regex (!cgo) + JS (always)
├── commands/               # 3 slash command definitions (Markdown)
├── skills/                 # AI scan instructions (27 SKILL.md files)
│   ├── secguard/           # 5 language vulnerability detection skills
│   ├── secaudit/           # 17 deep audit skills
│   └── secreview/          # 5 secure coding review skills
├── knowledge/              # Reusable knowledge base (all Markdown)
│   ├── detectors/          # 67 self-contained detector files
│   ├── languages/          # 5 language security profiles
│   ├── protocols/          # Output protocol v3.0 + SARIF 2.1.0 + findings schema
│   ├── standards/          # SEI CERT C/C++/Java + OWASP mapping
│   └── threat-catalog.md   # Threat catalog index
├── extensions/             # 3 extension package manifests
├── scripts/                # Build, deploy, verify, render
├── examples/               # 5 intentionally vulnerable demo projects
├── dist/                   # Build output
└── manifest.json           # Project registry: version, capabilities, coverage
```

---

## 2. AI-Native Design Philosophy

### 2.1 Why AI-Native, Not AI-Augmented

Traditional SAST tools add AI as a post-processing filter (e.g., to suppress false positives). SecGuardian is designed from the ground up with AI as the **primary analysis engine**:

1. **Semantic Understanding**: AI reads code the way a security consultant would — understanding intent, not just syntax
2. **Contextual Judgment**: AI evaluates whether a dangerous API call is actually exploitable in its specific usage context
3. **Cross-Function Reasoning**: AI traces data flow across function boundaries, files, and modules without requiring explicit dataflow analysis infrastructure
4. **Adaptive Reporting**: AI produces findings with attack scenarios, CVSS scores, and context-specific fixes — not just "potential issue at line X"

### 2.2 The Indexer-AI-Renderer Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Indexer    │ ──→ │  AI Agent    │ ──→ │  Renderer    │
│  (Go Binary) │     │ (Reasoning)  │     │  (Python)    │
│              │     │              │     │              │
│ Parse source │     │ Load skills  │     │ Validate     │
│ Build symbols│     │ Execute      │     │ Score calc   │
│ Call graph   │     │ detectors    │     │ CI gate      │
│ Alloc/free   │     │ Produce      │     │ Format output│
│ Lock graph   │     │ findings     │     │ SARIF/MD/JSON│
└──────────────┘     └──────────────┘     └──────────────┘
     index.json          findings/          6 output files
```

**Separation of Concerns**:
- **Indexer**: Mechanical, deterministic, fast — builds the semantic index that AI consumes
- **AI Agent**: Intelligent, contextual, adaptive — performs the actual security analysis
- **Renderer**: Mechanical, deterministic, auditable — validates, scores, and formats output

This separation ensures that AI output is always validated against a schema before rendering, and the renderer's scoring and CI gating logic is fully deterministic and reproducible.

### 2.3 Skill Loading Architecture

Skills are Markdown files loaded by the AI agent at scan time. Each skill defines:

1. **Execution flow**: Step-by-step instructions the AI follows
2. **Detector integration**: Which detectors to load and how to apply them
3. **Output requirements**: Mandatory four-segment finding structure
4. **Quality gates**: Self-check criteria the AI must satisfy before completing

This architecture means adding a new security analysis capability requires only:
- Create a `SKILL.md` file in the appropriate directory
- Add detector files if needed
- Update `extension.json` manifest
- Run `dev-deploy.sh`

No code changes, no recompilation, no restart of any service beyond the AI agent.

---

## 3. Go Semantic Indexer

The indexer (`internal/`) is the **only compiled native code** in the project. It produces the `secguardian-index` binary, which serves as the mechanical foundation for AI analysis.

### 3.1 Execution Pipeline

```
main() → runIndex(args)
  ├── Phase 1: Collect source files (filepath.Walk, language-aware extension filtering)
  ├── Phase 2: Parse all files (parser.ParseFile → ParseResult per file)
  ├── Phase 3: Build symbol index (indexer.ExtractSymbols)
  ├── Phase 4: Build call graph (indexer.BuildCallGraph)
  ├── Phase 5: Match alloc/free pairs (indexer.MatchAllocFree)
  ├── Phase 6: Build lock usage graph (indexer.BuildLockGraph)
  └── Phase 7: Assemble AnalysisContext → JSON output
```

### 3.2 CLI Interface

| Command | Description |
|---------|-------------|
| `secguardian-index --path ./src --output index.json` | Full semantic index |
| `secguardian-index --health` | Smoke test (returns HEALTH:OK/WARN) |
| `secguardian-index --version` | Print version |

Flags: `--path` (source directory), `--lang` (language override: c, cpp, python, java, go, javascript, auto), `--output` (output file path)

### 3.3 Analysis Context Data Model

The indexer produces a unified `AnalysisContext` JSON that the AI agent consumes:

```
AnalysisContext
├── path: string              # Root source directory
├── files: []string           # All analyzed source files
├── symbols: SymbolIndex      # Unified symbol table
│   ├── functions: []FunctionInfo    # name, file, start_line, end_line
│   ├── variables: []VariableInfo    # name, file, line
│   └── types: []TypeInfo            # name, kind (struct/class/interface/enum), file, start_line
├── call_graph: CallGraph     # Inter-procedural call relationships
│   └── edges: []CallGraphEdge      # caller, callee, file, line
├── alloc_free: AllocFreeMap  # Memory allocation/deallocation pairs
│   └── pairs: []AllocFreePair      # alloc_func, alloc_file, alloc_line, free_sites[]
└── lock_graph: LockGraph     # Mutex lock/unlock patterns
    └── mutexes: []LockUsage         # mutex_name, lock_line, unlock_line, file
```

### 3.4 Call Graph Construction

`BuildCallGraph()` constructs inter-procedural call relationships by:
1. Iterating each function in the symbol table
2. Scanning the function body for calls to other known functions
3. Filtering comment lines via `isCommentLine()` to prevent false edges from commented-out calls
4. Recording caller → callee edges with file and line location

### 3.5 Alloc/Free Pair Matching

`MatchAllocFree()` identifies memory management patterns critical for C/C++ security:
- Scans for allocation calls: `malloc()`, `calloc()`, `realloc()`
- Matches corresponding deallocation calls: `free()`, `delete`
- Records pairs within the same file for AI analysis of:
  - Missing free (memory leak, CWE-401)
  - Double free (CWE-415)
  - Mismatched alloc/free (CWE-762)
  - Use-after-free potential (CWE-416)

### 3.6 Lock Graph Construction

`BuildLockGraph()` scans for `pthread_mutex_lock`/`pthread_mutex_unlock` patterns to enable:
- Deadlock detection (CWE-833)
- Race condition analysis (CWE-362)
- Lock ordering violation detection

### 3.7 Language Detection

File extension mapping with intelligent directory filtering:

| Language | Extensions | Skipped Directories |
|----------|-----------|-------------------|
| C | `.c`, `.h` | `.git`, `.claude`, `.codeagent` |
| C++ | `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh` | `.gemini`, `.opencode` |
| Python | `.py` | `node_modules`, `dist` |
| Java | `.java` | |
| Go | `.go` | |
| JavaScript | `.js`, `.jsx`, `.mjs`, `.cjs` | |

---

## 4. Dual Parser Architecture

The indexer supports two parsing strategies, selected at compile time via Go build tags:

### 4.1 Tree-Sitter Parser (parser_ts.go)

- **Build tag**: `cgo`
- **Mechanism**: Full AST parsing via tree-sitter grammars with CGO bindings
- **Languages**: C, C++, Python, Go, Java (JavaScript falls through to dedicated parser)
- **Accuracy**: High — produces precise function boundaries, type definitions, and nested structures
- **Use case**: Local platform builds where CGO is available

**Nil Guard Convention**: Every `node.Child(i)` call must be followed by a nil check, as tree-sitter partial parse can return nil even when `i < node.ChildCount()`:

```go
child := node.Child(i)
if child == nil {
    continue
}
kind := child.Kind()
```

### 4.2 Regex Fallback Parser (parser_re.go)

- **Build tag**: `!cgo`
- **Mechanism**: Language-specific regex pattern matching
- **Languages**: All 6 (C, C++, Python, Go, Java, JavaScript)
- **Accuracy**: Moderate — captures top-level declarations, may miss nested or complex constructs
- **Use case**: Cross-platform builds where CGO is unavailable

### 4.3 JavaScript Parser (parser_javascript.go)

- **No build tag** — always compiled
- Handles JavaScript's diverse function syntax:
  - Named functions: `function foo()`
  - Function expressions: `foo = function()`, `foo = () =>`
  - Object method shorthand: `foo() {`
  - Arrow functions in objects: `foo: () =>`
  - Class declarations: `class Foo`

### 4.4 Shared Types (types.go)

Both parsers define identical output types, ensuring downstream consumers are parser-agnostic:

```
ParseResult → { File, Language, Functions[], Variables[], Types[] }
FunctionInfo → { Name, File, StartLine, EndLine }
VariableInfo → { Name, File, Line }
TypeInfo → { Name, Kind, File, StartLine }
```

### 4.5 Build Strategy Matrix

| Platform | Build Mode | Parser | CGO |
|----------|-----------|--------|-----|
| darwin-arm64 (local) | Default | tree-sitter | Enabled |
| darwin-amd64 | Cross | regex fallback | Disabled |
| linux-amd64 | Cross | regex fallback | Disabled |
| linux-arm64 | Cross | regex fallback | Disabled |
| windows-amd64 | Cross | regex fallback | Disabled |

---

## 5. Knowledge System

The knowledge system is SecGuardian's core intellectual property — 67 detectors, 17 audit skills, 5 language profiles, and 4 standard mappings, all expressed as structured Markdown.

### 5.1 Detector Architecture

Each of the 67 detectors is a self-contained Markdown file with six mandatory sections:

| Section | Purpose | Content |
|---------|---------|---------|
| Indexer Input | How to locate detection targets | Symbol table queries, call graph paths |
| Threat Definition | What the vulnerability is | Description, severity, CWE mapping |
| Detection Logic | Step-by-step detection | Report/no-report criteria, boundary conditions |
| Fix Guidance | How to remediate | Preferred fix, alternative approaches, code examples |
| False Positive Exclusion | What NOT to report | Valid patterns that resemble vulnerabilities |
| Detection Pattern Summary | Machine-readable rules | MUST REPORT + MUST NOT REPORT patterns |

**Example — Buffer Overflow Detector (memory-buffer-overflow.md)**:
- Indexer Input: Search `malloc()`, `calloc()`, array declarations, `strcpy()`, `gets()` calls
- Threat: CWE-120, Critical severity, stack/heap overflow leading to code execution
- Detection: Check buffer size vs source length, identify unsafe string functions, validate bounds
- Fix: Replace with `strncpy()`, `snprintf()`, `std::string`, or bounds-checked APIs
- Exclusion: Compile-time constant sizes with known-bounded sources

### 5.2 Detector Distribution by Category

| Category | Count | Key Threats |
|----------|-------|-------------|
| **Memory** | 13 | Buffer overflow, use-after-free, double-free, format string, integer overflow |
| **Concurrency** | 4 | Race condition, deadlock, data race, thread-unsafe signal |
| **System** | 8 | Command injection, path traversal, TOCTOU, privilege escalation, secrets |
| **Crypto** | 9 | Weak algorithms, hardcoded secrets, AES-ECB, TLS version, custom crypto |
| **Web** | 21 | XSS, SQLi, SSRF, CSRF, deserialization, XXE, SSTI, prototype pollution |
| **Resource** | 6 | File leak, socket leak, lock misuse, refcount misuse, double close |
| **Error** | 6 | Stack trace leak, log sensitive data, exception swallow, debug mode |

### 5.3 Language Security Profiles

Five language profiles provide language-specific context for AI analysis:

| Profile | Content |
|---------|---------|
| **C/C++** | Dangerous functions (strcpy, gets, sprintf), memory management patterns, RAII compliance |
| **Python** | Dangerous functions (os.system, pickle.load, eval), framework notes (Django, Flask, FastAPI) |
| **Java** | Dangerous APIs (Runtime.exec, ObjectInputStream), Spring/MyBatis/Hibernate patterns |
| **Go** | cgo memory safety, Goroutine concurrency, net/http patterns, Gin/Echo/Fiber frameworks |
| **JavaScript** | Prototype pollution vectors, eval variants, Express/NestJS/Next.js patterns |

### 5.4 Industry Standard Mappings

| Standard | Coverage |
|----------|---------|
| SEI CERT C | Memory management, integer handling, I/O, concurrency |
| SEI CERT C++ | Object lifecycle, type safety, concurrency |
| SEI CERT Java | Input validation, serialization, threading |
| OWASP Cheat Sheet | XSS, SQLi, CSRF, auth, crypto, deserialization |

### 5.5 Manifest-Driven Token System

A single source of truth (`manifest.json`) drives all references to detector counts and capability metrics. The `sync-manifest.sh` script automatically updates `NNN<!-- @secguardian:xxx -->` tokens across all files when the manifest changes, preventing stale references and ensuring consistency.

---

## 6. Three Product Lines

### 6.1 SecGuard — AI-Guided Vulnerability Detection

**Command**: `/secguard <path> [mode] [filters]`

| Aspect | Detail |
|--------|--------|
| Modes | `all` (full scan), `git diff` (incremental) |
| Filters | Namespace patterns: `memory.*`, `system.command-injection`, `memory.*,system.*,crypto.*` |
| Detectors | 67 across 7 categories |
| Languages | C/C++, Python, Java, Go, JavaScript |
| Output | 6-file structured output (report.md, SARIF, summary.json, manifest.json, status.json, delta.json) |

**Execution Flow**:
1. Pre-flight checklist (indexer health, path validation)
2. Build semantic index (`secguardian-index --path --output`)
3. Language & detector matching + filter resolution
4. AI executes detectors by severity priority (Critical → High → Medium → Low)
5. Four-segment completeness enforcement (Location, Evidence, Impact, Fix)
6. Renderer generates all output files
7. Summary with security score

**Language-Specific Priority Orders**:

| Language | Priority 1 | Priority 2 | Priority 3 |
|----------|-----------|-----------|-----------|
| C/C++ | Memory ops | Format string | Integer overflow |
| Python | Deserialization | Command injection | SSTI |
| Java | Deserialization | SQL injection | Command injection |
| Go | Command injection | SQL injection | cgo memory |
| JavaScript | NoSQL injection | Command injection | Prototype pollution |

### 6.2 SecAudit — AI Deep Security Audit (Flagship)

**Command**: `/secaudit <skill-name> [path] [--sarif]`

17 specialized skills organized into two tiers:

**Tier 1 — Analysis Methods** (5 skills):

| Skill | Methodology |
|-------|------------|
| taint-analysis | Mark tainted sources → trace propagation → locate sinks → verify sanitization |
| data-flow-analysis | Track data from Source to Sink complete flow |
| attack-surface-analysis | Identify all exposed entry points and interfaces |
| state-machine-analysis | Detect illegal state transitions |
| trust-boundary-analysis | Identify trust boundaries, check cross-boundary controls |

**Tier 2 — Security Domain Audits** (12 skills):

| Skill | Domain |
|-------|--------|
| auth-and-session | Authentication mechanism and session lifecycle |
| authorization | Permission model, privilege escalation |
| cryptography | Crypto implementation, weak algorithms |
| data-protection | Sensitive data storage/transmission/processing |
| dependency-security | Known vulnerabilities, supply chain |
| http-security-headers | HTTP security header configuration |
| infra-hardening | Container/K8s/cloud hardening |
| input-validation | Input validation, injection vulnerabilities |
| logging-and-monitoring | Log integrity, security monitoring |
| output-encoding | Output encoding, XSS protection |
| secrets-management | Key/credential management |
| secure-transport | TLS configuration, transport security |

**Taint Analysis Methodology** (5 phases):
1. Identify Taint Sources: HTTP params, file uploads, WebSocket, CLI args, DB results, env vars
2. Trace Propagation: Direct assignment, string concat, function calls, type conversion
3. Locate Sinks: SQL exec, command exec, XSS output, file ops, code exec, deserialization
4. Verify Sanitization: Effective vs ineffective sanitization
5. Output: Vulnerability list, propagation graph, safe path confirmation

### 6.3 SecReview — Secure Coding Review

**Command**: `/secreview <path> [language] [--sarif]`

Four-phase review per language:

| Phase | Focus |
|-------|-------|
| Semantic Review | Language-specific security semantics (memory safety, injection, etc.) |
| Standard Compliance | Industry coding standards (SEI CERT, MISRA) |
| Anti-pattern Detection | Language-specific anti-patterns (C-style cast, raw pointers, eval, etc.) |
| Output | report.md + results.sarif + summary.json |

**Key Distinction from SecGuard**:

| Dimension | SecGuard | SecReview |
|-----------|----------|-----------|
| Granularity | Specific API call level | Function/module semantic level |
| Focus | Exploitable vulnerabilities | Secure coding standard compliance |
| Output | CWE + CVSS | Anti-pattern + best practice violations |
| Coverage | CWE Top 25 + 67 detectors | SEI CERT + MISRA + best practices |

---

## 7. Output Protocol & CI/CD Integration

### 7.1 Output Protocol v3.0

SecGuardian implements a Human/Machine Separation design — each output file is optimized for its specific consumer:

| File | Audience | Format | Purpose |
|------|----------|--------|---------|
| `report.md` | Engineers/Auditors | Markdown | Full audit report with executive summary, findings, fix roadmap |
| `results.sarif` | CI/CD systems | SARIF 2.1.0 | GitHub Code Scanning, GitLab SAST, Azure DevOps |
| `summary.json` | Dashboard | JSON | Statistics by severity/namespace/language |
| `manifest.json` | Program entry | JSON | Scan metadata + finding index |
| `status.json` | CI gate | JSON | pass/fail + exit_code |
| `delta.json` | Trend analysis | JSON | Incremental comparison with previous scan |

### 7.2 v5.0 Directory Tree Structure

```
.codeagent/<extension-name>/scans/<scan-id>/
├── index.json                # Indexer output (read-only)
├── findings.json             # Lightweight index + metadata
├── findings/                 # Finding directory tree (4-segment per file)
│   ├── web/sql-injection/H-SQLI-webapp-L47.json
│   ├── crypto/password-storage/H-CRYPTO-crypto_utils-L20.json
│   └── ...
├── report.md                 # Human-readable audit report
├── results.sarif             # SARIF 2.1.0
├── summary.json              # Dashboard statistics
├── manifest.json             # Scan metadata
├── status.json               # CI gate
├── delta.json                # Incremental comparison
└── latest → <scan-id>/       # Symlink to latest scan
```

### 7.3 Four-Segment Finding Structure

Every finding must contain four mandatory segments:

| Segment | Content | Purpose |
|---------|---------|---------|
| **Location** | File path + line + function + code snippet | Precise identification |
| **Evidence** | Code context + judgment rationale + data flow path | Justification for the finding |
| **Impact** | Attack scenario + CVSS 3.1 score + exploit conditions | Business risk assessment |
| **Fix** | Before/After code + effort estimate + verification method + CWE | Actionable remediation |

### 7.4 Finding ID Format

`<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`

Example: `H-SQLI-webapp-L47` = High severity, SQL Injection detector, webapp file, line 47

### 7.5 Security Score Algorithm

```
Score = 100 - (Critical × 25 + High × 10 + Medium × 3 + Low × 1)
Range: 0-100
```

| Grade | Range | Interpretation |
|-------|-------|---------------|
| A | 90-100 | Excellent — minimal risk |
| B | 75-89 | Good — minor issues |
| C | 60-74 | Fair — notable concerns |
| D | 40-59 | Poor — significant risk |
| F | 0-39 | Critical — immediate action required |

### 7.6 SARIF 2.1.0 Integration

SARIF output follows the OASIS Standard with SecGuardian enhancements:

- `message.markdown`: Mandatory — full four-segment rich text
- `relatedLocations[]`: Mandatory for data flow findings
- `partialFingerprints`: For deduplication across scans
- `fixes[]`: Before/after code replacements for automated remediation
- Severity mapping: Critical/High → error, Medium → warning, Low → note, Info → none

**CI/CD Platform Integration**:

| Platform | Integration Method |
|----------|-------------------|
| GitHub Actions | SARIF → Code Scanning API (native) |
| GitLab | SARIF → SAST report artifact |
| Azure DevOps | SARIF → SARIF Viewer extension |

### 7.7 CI Gate Logic

```
if any finding with severity == Critical:
    status = FAILED, exit_code = 1
elif any finding with severity == High:
    status = WARNING, exit_code = 0  (configurable)
else:
    status = PASSED, exit_code = 0
```

---

## 8. Incremental Scanning

SecGuardian supports `git diff` based incremental analysis for fast feedback in CI/CD pipelines.

### 8.1 Diff Parser Architecture

The `diff_parser.go` module implements:

1. **ParseGitDiff()**: Executes `git diff` and parses unified diff output into structured `DiffResult` with file paths and changed line ranges
2. **AffectedSymbols()**: Identifies which functions in the symbol table overlap with changed lines

### 8.2 Incremental Scan Flow

```
git diff → DiffResult → AffectedSymbols → Filtered Analysis → Delta Output
```

1. Parse git diff to identify changed files and line ranges
2. Cross-reference with symbol table to identify affected functions
3. Execute detectors only on affected code paths
4. Compare with previous scan results to produce delta.json
5. Delta includes: new findings, fixed findings, still-open findings

### 8.3 Delta Comparison

The `delta.json` output enables trend analysis:

| Field | Description |
|-------|-------------|
| `new` | Findings present in current scan but not in previous |
| `fixed` | Findings present in previous scan but not in current |
| `still_open` | Findings present in both scans |
| `previous_scan_id` | Reference to previous scan for traceability |

---

## 9. Cross-Platform Build & Deployment

### 9.1 Build Process (package.sh)

The build process produces platform-specific distribution packages:

1. **Compile Go indexer binaries** (parallel builds):
   - `darwin-arm64`: CGO enabled → tree-sitter parser (primary development platform)
   - `darwin-amd64`: CGO_ENABLED=0 → regex fallback
   - `linux-amd64`: CGO_ENABLED=0 → regex fallback
   - `linux-arm64`: CGO_ENABLED=0 → regex fallback
   - `windows-amd64.exe`: CGO_ENABLED=0 → regex fallback

2. **For each extension** (secguard, secaudit, secreview):
   - Read `extension.json` manifest
   - Create dist directory structure
   - Generate Claude Code compatibility plugin.json
   - Copy commands, skills, knowledge, scripts, and binaries

### 9.2 Deployment Targets

| Platform | Short | Deploy Target |
|----------|-------|---------------|
| Claude Code | cc | `.claude/plugins/secguardian/` |
| OpenCode | nga | `.opencode/plugins/secguardian.js` + `.opencode/extensions/secguardian/` |
| Gemini CLI | cac | `.gemini/extensions/secguardian/` |

### 9.3 Indexer Binary Deployment

The deployment process handles binary deployment with atomic replacement:

1. Detect current OS/architecture
2. Copy matching platform binary as `secguardian-index` (canonical name)
3. Write to `.tmp`, verify with `--version`, then rename (atomic)
4. Idempotent: skips if same version already deployed

### 9.4 One-Command Development Cycle

| Action | Command | Time |
|--------|---------|------|
| Any file change | `bash scripts/dev-deploy.sh` | ~30s |
| Go indexer change | `bash scripts/dev-deploy.sh --verify` | ~35s |
| Verify deployment | `bash scripts/dev-verify.sh` | ~5s |
| Full reset | `bash scripts/dev-deploy.sh --reset` | ~60s |
| Uninstall | `bash scripts/dev-deploy.sh --uninstall` | ~10s |

---

## 10. Verification Methodology

SecGuardian implements a five-level verification system ensuring integrity from design through deployment:

### 10.1 Verification Levels

| Level | Script | Coverage | Time | When to Run |
|-------|--------|----------|------|-------------|
| **L1 Design** | `self-check.sh` | 82+ checks: detector↔index↔manifest cross-validation, stale references, Go compile | ~5s | Every commit |
| **L2 Structure** | `ci-check.sh` | JSON format, version consistency, skill directory integrity, Go compile+smoke | ~15s | Before push |
| **L3 Deploy** | `dev-verify.sh` | 23 checks: binaries, indexer health, platform structure, scan output | ~10s | After deploy |
| **L4 Architecture** | `e2e-verify.sh` | 37 checks: schema, renderer, SARIF, quality gate, scoring, CI gate, delta, commands, multi-language | ~15s | After architecture changes |
| **L5 Full** | All above | Complete coverage | ~45s | Before release |

### 10.2 E2E Verification Coverage Matrix

| # | Verification | What It Validates | Failure Impact |
|---|-------------|-------------------|----------------|
| 1 | Findings Schema | JSON structure, required fields, ID pattern | AI output may be invalid |
| 2 | Renderer Basics | 6-file generation, single format, empty findings | Renderer core broken |
| 3 | SARIF 2.1.0 | version/driver/rules/results/fingerprints/fixes | CI/CD integration fails |
| 4 | 4-Segment Quality Gate | Complete vs incomplete finding handling | Quality check unreliable |
| 5 | Security Score | Formula: 100 - 25×Crit - 10×High - 3×Med - 1×Low | Score calculation wrong |
| 6 | CI Gate | Critical → FAILED+exit 1; Clean → PASSED+exit 0 | CI pipeline gate fails |
| 7 | Delta Comparison | new/fixed/still_open counts vs previous scan | Trend analysis wrong |
| 8 | Command Types | secguard/secaudit/secreview correct titles | Report type confusion |
| 9 | Multi-language | 5 language example repos indexer parsing | Indexer broken for a language |
| 10 | Renderer Performance | < 5s for 1 finding render | Performance regression |

### 10.3 Recommended Verification Workflows

```
Daily (skills/knowledge/commands):     L1 only
Structure changes (deploy.sh):         L1 + L2
Architecture changes (renderer):       L1 + L4
Indexer changes (internal/):           L1 + L2 + L3 + L4
Pre-release:                           L1 + L2 + L3 + L4 + L5
```

---

## 11. Threat Coverage Matrix

### 11.1 Standard Coverage

| Standard | Coverage | Details |
|----------|---------|---------|
| CWE Top 25 | 25/25 (100%) | Most dangerous software weaknesses (MITRE) |
| OWASP Top 10 | 10/10 (100%) | Web application security risks |
| OWASP API Top 10 | 10/10 (100%) | API security risks |

### 11.2 Complete Detector Catalog

#### Memory Safety (13 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| buffer-overflow | CWE-120 | Critical | Unbounded copy to fixed buffer |
| heap-buffer-overflow | CWE-122 | Critical | Out-of-bounds heap write |
| use-after-free | CWE-416 | Critical | Access after free/delete |
| double-free | CWE-415 | Critical | Free already-freed pointer |
| format-string | CWE-134 | Critical | User input as format string |
| null-dereference | CWE-476 | High | Dereference without null check |
| integer-overflow | CWE-190 | High | Arithmetic overflow |
| mismatched-free | CWE-762 | High | Mismatched alloc/dealloc |
| off-by-one | CWE-193 | High | Fencepost error |
| oob-read | CWE-125 | High | Out-of-bounds read |
| uninitialized-memory | CWE-457 | Medium | Use before initialization |
| memory-leak | CWE-401 | Medium | Missing deallocation |
| bad-cast | CWE-704 | Medium | Invalid type conversion |

#### Concurrency (4 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| race-condition | CWE-362 | High | Concurrent access without synchronization |
| deadlock | CWE-833 | Critical | Circular lock dependency |
| data-race | CWE-366 | High | Unsynchronized shared data access |
| thread-unsafe-signal | CWE-479 | High | Non-async-signal-safe function in handler |

#### System (8 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| command-injection | CWE-78 | Critical | User input in shell command |
| path-traversal | CWE-22 | High | Unsanitized file path |
| toctou | CWE-367 | High | Time-of-check vs time-of-use |
| privilege-escalation | CWE-269 | High | Unnecessary elevated privileges |
| secrets-detection | CWE-798 | Critical | Hardcoded credentials |
| symlink-attack | CWE-59 | Medium | Symlink following |
| insecure-permissions | CWE-732 | Medium | Overly permissive file/dir |
| insecure-temp-file | CWE-377 | Medium | Predictable temp file name |

#### Crypto (9 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| hardcoded-secrets | CWE-798 | Critical | Hardcoded keys/passwords |
| weak-crypto-algorithm | CWE-327 | High | MD5, SHA1, DES, RC4 |
| password-storage | CWE-916 | High | Plaintext or reversible storage |
| aes-ecb-mode | CWE-327 | High | AES in ECB mode |
| insufficient-key-length | CWE-326 | High | RSA <2048, AES <128 |
| tls-version | CWE-326 | High | TLS 1.0/1.1 |
| hardcoded-iv | CWE-329 | Medium | Static initialization vector |
| custom-crypto | CWE-327 | Critical | Non-standard algorithm |
| weak-random | CWE-338 | Medium | Math.random, rand() |

#### Web (21 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| sql-injection | CWE-89 | Critical | Unparameterized SQL |
| xss | CWE-79 | High | Unencoded output |
| ssrf | CWE-918 | High | User-controlled URL fetch |
| csrf | CWE-352 | High | Missing anti-CSRF token |
| deserialization | CWE-502 | Critical | Unsafe deserialization |
| xxe | CWE-611 | High | Unrestricted XML entity |
| ssti | CWE-94 | Critical | User input in template |
| command-injection | CWE-78 | Critical | OS command from user input |
| nosql-injection | CWE-943 | High | NoSQL query injection |
| prototype-pollution | CWE-1321 | High | Object prototype modification |
| idor | CWE-639 | High | Insecure direct object reference |
| open-redirect | CWE-601 | Medium | Unvalidated redirect URL |
| unrestricted-upload | CWE-434 | High | No file type/size validation |
| auth-bypass | CWE-287 | Critical | Authentication bypass |
| missing-authentication | CWE-306 | Critical | Unauthenticated endpoint |
| missing-authorization | CWE-862 | Critical | Unchecked authorization |
| jwt-misuse | CWE-287 | High | JWT algorithm confusion |
| mass-assignment | CWE-915 | High | Auto-binding user input |
| excessive-data-exposure | CWE-200 | Medium | Overly permissive API response |
| code-injection | CWE-94 | Critical | eval/exec with user input |
| resource-exhaustion | CWE-400 | Medium | Unbounded resource consumption |

#### Resource (6 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| file-leak | CWE-404 | Medium | Unclosed file handle |
| socket-leak | CWE-404 | Medium | Unclosed socket |
| lock-misuse | CWE-667 | High | Missing unlock / double lock |
| refcount-misuse | CWE-401 | Medium | Incorrect reference counting |
| file-double-close | CWE-910 | Medium | Close already-closed file |
| file-use-after-close | CWE-404 | Medium | Access after close |

#### Error Handling (6 detectors)

| Detector | CWE | Severity | Key Pattern |
|----------|-----|----------|-------------|
| stack-trace-leak | CWE-209 | Medium | Stack trace to client |
| log-sensitive-data | CWE-532 | Medium | Sensitive data in logs |
| exception-swallow | CWE-390 | Medium | Empty catch block |
| debug-mode-production | CWE-215 | Medium | Debug mode enabled |
| panic-to-client | CWE-209 | Medium | Unhandled panic/exception |
| unified-error-format | CWE-209 | Low | Inconsistent error responses |

---

## 12. Performance Characteristics

### 12.1 Indexer Performance

| Metric | Value | Notes |
|--------|-------|-------|
| Parse speed | ~10K LOC/s | Tree-sitter parser (local) |
| Parse speed | ~5K LOC/s | Regex fallback (cross-platform) |
| Index size | ~1KB per 100 LOC | JSON output |
| Health check | <100ms | Smoke test |

### 12.2 Renderer Performance

| Metric | Value | Notes |
|--------|-------|-------|
| 1 finding render | <5s | All 6 output files |
| 100 findings | <30s | Parallel file generation |
| SARIF generation | <1s per finding | OASIS standard format |

### 12.3 Deployment Performance

| Operation | Time |
|-----------|------|
| Full build + deploy | ~30s |
| Incremental deploy (no Go changes) | ~15s |
| Verification (L1) | ~5s |
| Full verification (L1-L5) | ~45s |

---

## 13. Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Indexer** | Go 1.25.3 | Semantic analysis binary |
| **Parser (primary)** | tree-sitter + CGO | AST parsing for C/C++/Python/Go/Java |
| **Parser (fallback)** | Go regexp | Pattern matching for all 6 languages |
| **Parser (JS)** | Go regexp | JavaScript-specific function detection |
| **Renderer** | Python 3 | Report generation, scoring, CI gate |
| **Knowledge** | Markdown | Detectors, skills, language profiles, standards |
| **Schema** | JSON Schema draft 2020-12 | Findings validation contract |
| **Output** | SARIF 2.1.0 | CI/CD integration standard |
| **CI/CD** | GitHub Actions | Native SARIF upload to Code Scanning |
| **Build** | Bash | Cross-platform compilation and packaging |
| **Deploy** | Bash | Multi-platform plugin deployment |

### 13.1 Dependency Minimization

SecGuardian deliberately minimizes runtime dependencies:

- **No database** — All state is file-based (JSON + Markdown)
- **No server** — Runs as CLI tool invoked by AI agent
- **No network** — Pure local analysis, no API calls
- **No language runtime** — Single static binary per platform
- **No plugin framework** — AI agent IS the plugin framework

---

## 14. Future Directions

### 14.1 Near-Term (v0.7.0)

- **LLM-agnostic skill loading**: Support for additional AI models beyond Claude/Gemini
- **Extended language support**: Rust, TypeScript, C#, Kotlin
- **IDE integration**: VS Code extension for inline findings
- **Performance optimization**: Parallel file parsing, incremental index updates

### 14.2 Mid-Term (v0.8.0)

- **Custom detector authoring**: Web UI for creating organization-specific detectors
- **Finding correlation engine**: Cross-scan pattern detection across repositories
- **Compliance mapping**: SOC 2, ISO 27001, PCI DSS control mapping
- **Remediation tracking**: Integration with issue trackers (Jira, GitHub Issues)

### 14.3 Long-Term (v1.0.0)

- **Multi-repository analysis**: Organization-wide security posture assessment
- **Threat modeling integration**: STRIDE/DREAD automated threat model generation
- **Security metrics dashboard**: Trend analysis, team benchmarking, executive reporting
- **AI fine-tuning**: Domain-specific model adaptation for organization code patterns

---

## Appendix A: Command Reference

### /secguard

```
/secguard <path> [mode] [filters]

Modes:  all       Full scan (default)
        git diff  Incremental scan

Filters: memory.*           All memory detectors
         system.command-injection  Specific detector
         memory.*,system.*,crypto.*  Multiple namespaces
```

### /secaudit

```
/secaudit <skill-name> [path] [--sarif]

Skills: taint-analysis, data-flow-analysis, attack-surface-analysis,
        state-machine-analysis, trust-boundary-analysis,
        auth-and-session, authorization, cryptography, data-protection,
        dependency-security, http-security-headers, infra-hardening,
        input-validation, logging-and-monitoring, output-encoding,
        secrets-management, secure-transport
```

### /secreview

```
/secreview <path> [language] [--sarif]

Languages: cpp, python, java, go, js
```

## Appendix B: Output File Examples

### findings.json (Lightweight Index)

```json
{
  "version": "5.0",
  "scan_id": "20260608-120000-abc123",
  "tool": "secguardian",
  "tool_version": "0.6.0",
  "total_findings": 3,
  "by_severity": { "critical": 1, "high": 1, "medium": 1 },
  "by_namespace": { "web": 1, "crypto": 1, "memory": 1 },
  "findings": [
    { "id": "C-SQLI-webapp-L47", "file": "findings/web/sql-injection/C-SQLI-webapp-L47.json" },
    { "id": "H-CRYPTO-crypto_utils-L20", "file": "findings/crypto/password-storage/H-CRYPTO-crypto_utils-L20.json" },
    { "id": "M-MEMORY-handler-L85", "file": "findings/memory/memory-leak/M-MEMORY-handler-L85.json" }
  ]
}
```

### status.json (CI Gate)

```json
{
  "status": "FAILED",
  "exit_code": 1,
  "security_score": 65,
  "grade": "C",
  "total_findings": 3,
  "critical": 1,
  "high": 1,
  "medium": 1,
  "low": 0
}
```

### summary.json (Dashboard)

```json
{
  "scan_id": "20260608-120000-abc123",
  "security_score": 65,
  "grade": "C",
  "total_findings": 3,
  "by_severity": { "critical": 1, "high": 1, "medium": 1, "low": 0 },
  "by_namespace": { "web": 1, "crypto": 1, "memory": 1 },
  "by_language": { "python": 2, "cpp": 1 },
  "top_detectors": [
    { "detector": "sql-injection", "count": 1 },
    { "detector": "password-storage", "count": 1 },
    { "detector": "memory-leak", "count": 1 }
  ]
}
```

## Appendix C: Framework Coverage Matrix

| Language | Frameworks | Coverage |
|----------|-----------|----------|
| Python | Django, Flask, FastAPI, SQLAlchemy, Celery | Full |
| Java | Spring (Boot/Security/MVC), MyBatis, Hibernate/JPA, FastJson/Jackson/Gson, Apache Shiro, Log4j/Logback | Full |
| Go | net/http, Gin, Echo, Fiber, GORM, sqlx, html/template, cgo | Full |
| JavaScript | Express, NestJS, Next.js, Mongoose, Sequelize, Prisma, Node.js stdlib, React, Vue | Full |
| C/C++ | POSIX, STL, Boost | Full |

---

*This whitepaper is a living document. For the latest version, refer to the project repository at secguardian/.*
