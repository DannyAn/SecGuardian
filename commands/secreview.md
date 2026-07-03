---
name: secreview
description: "AI Security Code Review — 5-language PR security review with exploit scenario analysis"
---

# /secreview - AI Security Code Review for Pull Requests

AI-powered security code review designed for pull requests, repositories and completed implementations.

Unlike traditional linters, SecReview reasons about code behavior, business logic and exploitability.

## Usage

```
# ★ 零参数缺省调用（推荐）
/secreview                                           # 检测当前目录，自动识别语言，git diff 模式

# 全量代码库检视
/secreview ./src                                     # 语言自动检测
/secreview ./src java                                # Java code review

# Git diff / PR review 模式
/secreview git diff                                  # 当前目录的变更
/secreview ./src cpp git diff main                   # Current branch vs main

# SARIF 输出
/secreview ./src java --sarif                        # Append SARIF 2.1.0 output
```

## Output Path Convention

> ⚠️ The `.codeagent/` output directory must be placed in the **user's project root**, not in SecGuardian's project root.
>
> Determine the user project root from the `<path>` argument:
> - Resolve `<path>` to an absolute path, use its **parent** as the user project root
> - All output paths must use `<user-project>/.codeagent/` prefix
> - Do NOT use bare `.codeagent/` (it resolves to SecGuardian's root)

## Output

Follows [Scan Output Protocol 5.0](../knowledge/protocols/scan-output.md). Human-readable and machine-readable separation.

```
<user-project>/.codeagent/secreview-secguardian/scans/<scan-id>/
├── human/                    # ★ v7.0: Unified entry point
│   └── executive-summary.md    One-page dashboard + finding distribution + navigation
├── findings/                 # Per-detector organized finding directory tree
├── ai/                       # ★ v7.0: AI-consumable
│   └── remediation-pack.json   AI remediation pack (with cross-references)
├── report.md                 # ★ Human-readable review report (concise 5 sections)
├── dashboard.html            # ★ v7.0: Management dashboard
├── results.sarif             # Machine: SARIF 2.1.0 (CI/CD)
├── summary.json              # Dashboard statistics
├── manifest.json             # Review metadata + finding index
├── status.json               # CI gate status
└── delta.json                # Delta vs previous scan
```

**Execution summary (must output after each run):**

```
## secreview review complete

Scan ID: pr-20260531-143000-a1b2
Path: ./src
Language: Java (auto-detected)
Mode: git diff main

### Results
- Files reviewed: 12 (8 changed + 4 context)
- Review dimensions: 6 checked
- Findings: 5 (Critical: 0, High: 2, Medium: 3, Info: 0)

### Findings
| # | Severity | CWE | File | Summary |
|---|----------|-----|------|---------|
| #1 | 🟠 High | CWE-089 | src/service/UserService.java:89 | SQL injection via string concatenation |
| #2 | 🟠 High | CWE-807 | src/controller/AdminController.java:23 | Trust boundary violation in auth bypass |
| #3 | 🟡 Medium | CWE-532 | src/handler/AuthHandler.java:156 | Sensitive data in log output |
| #4 | 🟡 Medium | CWE-200 | src/filter/RequestFilter.java:42 | ThreadLocal data leak across requests |
| #5 | 🟡 Medium | CWE-829 | src/service/OrderService.java:203 | Unsafe deserialization from user input |

> Each finding includes exploit scenario, CWE mapping, severity assessment, CVE-like CVSS scoring, and fix recommendation.

Output directory: <user-project>/.codeagent/secreview-secguardian/scans/pr-20260531-143000-a1b2/

💡 **How to use review results?**
- **Quick summary** -> `manifest.json`
- **★ Unified entry** -> `human/executive-summary.md`
- **Engineer remediation** -> Per-finding in `findings/` directory
- **Management dashboard** -> Open `dashboard.html` in browser
- **Full review report** -> `report.md` (5-section concise report)
- **🤖 AI Agent fix** -> Read `ai/remediation-pack.json`
- **CI/CD integration** -> Consume `results.sarif`
```

## Difference from /secguard

| Dimension | secguard | secreview |
|-----------|----------|-----------|
| SDLC Stage | During coding | During pull request / code review |
| Primary Users | Individual developers | Developers + Reviewers + PR approvers |
| Granularity | API-level + detector filtered | Function/module-level semantic + business logic |
| Focus | Does this API call introduce a vulnerability? | Is the change safe to merge? |
| Output | CWE + CVSS + detection detail | CWE + exploit scenario + business logic impact |
| Severity | Critical -> Info | High -> Info (PR-blocking semantics) |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

## Dispatch Rules & Execution Steps

You (the AI Agent) must follow these steps when executing `/secreview` to perform the security code review.

### Pre-flight Checklist
> ⛔ **DO NOT use Glob or Read tools to discover file paths**. All path checks must use bash commands (`[ -f ]`, `ls`, etc.). Always run `find_indexer` before `--health`.

Before starting any review, verify each condition below. **If any check fails, report the specific error and abort.**

- [ ] Locate indexer wrapper: `.opencode/extensions/secguardian/` (project) -> `~/.config/opencode/extensions/secguardian/` (user) -> `.gemini/` -> `.claude/` -> `scripts/` fallback (at least one exists and is executable)
- [ ] Run `{indexer} --health` passes (output must contain `HEALTH:OK` or `HEALTH:WARN`; `HEALTH:FAIL` is not accepted)
- [ ] Target `<path>` exists and contains at least one source file
- [ ] **Language detection (only when user omits `language` parameter)** check source extensions in `<path>`: `*.c/*.cpp/*.h` -> `cpp`, `*.py` -> `python`, `*.java` -> `java`, `*.go` -> `go`. No need to ask the user.
- [ ] Confirm no external tools (clangd/LSP/compile_commands.json/bear) will be started. The indexer (tree-sitter) already provides symbol table + call graph + file manifest.

> If any check fails, report which one and abort. Do not degrade to manual file-by-file review.

---

### Step 1: Create Output Directory

- **⏳ Generate scan_id FIRST** (format: `pr-YYYYMMDD-HHMMSS-xxxx`, `xxxx` is 4 random chars).
- Create output directory: `<user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/`.
- **Once scan_id is generated, ALL subsequent paths must use this scan_id.**
- Record review start timestamp for Step 4 `duration_ms` calculation.

### Step 2: Build Semantic Index (Required)

> ⚠️ This is the **core prerequisite** for review. The indexer provides symbol table and call graph needed for structured security analysis. **Skipping this step will severely degrade review quality.**

**2a. Execute indexer (blocking):**

```bash
find_indexer() {
    INDEXER=""
    for base in "." "$HOME"; do
        for path in \
            ".opencode/extensions/secguardian/scripts/secguardian-index" \
            ".config/opencode/extensions/secguardian/scripts/secguardian-index" \
            ".gemini/extensions/secguardian/scripts/secguardian-index" \
            ".claude/plugins/secguardian/scripts/secguardian-index"; do
            candidate="$base/$path"
            [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break 3
        done
    done
    for candidate in scripts/secguardian-index internal/secguardian-index; do
        [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break
    done
    [ -z "$INDEXER" ] && echo "FATAL: secguardian-index not found (checked project + user paths)" && exit 1
    echo "Using: $INDEXER"
}
find_indexer
# 索引复用: 同路径扫描共享缓存，跳过重复构建
cache_dir="<user-project>/.codeagent/secreview-secguardian/cache"
mkdir -p "$cache_dir"
cache_key=$(echo "$(realpath "<path>" 2>/dev/null || echo "<path>")" | md5sum 2>/dev/null | head -c 8 || echo "<path>")
if [ -f "$cache_dir/$cache_key.json" ]; then
    cp "$cache_dir/$cache_key.json" "<user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json"
else
    $INDEXER --path <path> --output <user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json
    if [ $? -eq 0 ]; then
        cp "<user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json" "$cache_dir/$cache_key.json"
    fi
fi
if [ ! -f "<user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

**2b. Validate index integrity (required):**

```bash
python3 scripts/validate-index.py \
    --index <user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json \
    --scan-id <scan_id>
```

> If return code is non-zero, **abort immediately** and report index error.

### Step 3: Language Detection & Skill Routing

- Extract `primary_language` from the summary.
- Load the corresponding skill: `../skills/secreview/{language}/SKILL.md`.
- Reference `../knowledge/languages/{language}.md` for dangerous API lists and framework security notes.
- **Use index.json symbol table to locate review targets**, rather than traversing files.

### Step 4: AI Security Code Review — Three Reasoning Dimensions

> The AI Agent performs three complementary reasoning passes. Each pass uses the index.json for structural context (symbols, call graph, alloc/free pairs, lock graph) and the skill file for language-specific review criteria.

**Pass A — Vulnerability Detection by Code Review**

For each function/symbol in the changeset (or full codebase), evaluate:

1. **Input trust boundaries** — Does user input cross into dangerous sinks (SQL, shell, file system, eval)?
2. **Authentication / authorization** — Are access control checks present and correct?
3. **Data flow analysis** — Does untrusted data reach sensitive operations without sanitization?
4. **Cryptography usage** — Are algorithms, key lengths, and RNGs appropriate?
5. **Error handling** — Do errors leak sensitive information? Are exceptional paths handled safely?
6. **Dependency / serialization** — Are third-party deserialization sources trusted?

Cite specific CWE IDs for each finding. Include an exploit scenario that explains how an attacker could leverage the defect.

**Pass B — Business Logic Security**

Evaluate the changes for business logic vulnerabilities:

1. **State manipulation** — Can an attacker transition the application to an invalid state?
2. **Privilege escalation** — Does the change allow accessing resources without proper authorization?
3. **Race conditions** — Are shared resources protected consistently (TOCTOU, async race)?
4. **Rate limiting / abuse** — Can the change be abused for denial of service?

**Pass C — Anti-pattern & Code Quality Review**

Evaluate against language-specific anti-patterns (from the skill file):

1. **Coding standard violations** — SEI CERT, OWASP, Go Security Guidelines, etc.
2. **Framework-specific anti-patterns** — Spring, Django, Express, React, etc.
3. **Common language pitfalls** — Type confusion, unsafe reflection, prototype pollution, etc.

> Findings from all three passes are consolidated into a single output. Each finding should reference which pass(es) identified it.

### Step 5: Output Structured Findings (Findings Protocol v5.0)

> **v5.0**: Each finding is written as an individual file in the `findings/` directory tree. A lightweight `findings.json` (index only, no full content) serves as the manifest. The renderer aggregates via `--findings-dir`.

**5a. Output individual finding files:**

Each finding written to `<scan_dir>/findings/<detector>/<sha12>_<file_slug>-<line>.json`:

```json
{
  "schema_version": "1.0",
  "finding": {
    "severity": "High",
    "cwe": "CWE-089",
    "detector": "web.sql-injection",
    "file": "src/service/UserService.java",
    "line": 89,
    "location": {
      "file_path": "src/service/UserService.java",
      "start_line": 89,
      "end_line": 92,
      "function_name": "findUser",
      "snippet": "String qry = \"SELECT * FROM users WHERE id=\" + userId;"
    },
    "evidence": {
      "judgment_rationale": "String concatenation in SQL query with direct user input — violates OWASP Top 10 A03:2021 Injection"
    },
    "impact": {
      "attack_scenario": "Attacker provides userId=1 OR 1=1 to bypass authentication and retrieve all users",
      "cvss_score": 8.2
    },
    "fix": {
      "description": "Use PreparedStatement for parameterized query",
      "before_code": "String qry = \"SELECT * FROM users WHERE id=\" + userId;",
      "after_code": "PreparedStatement ps = conn.prepareStatement(\"SELECT * FROM users WHERE id=?\"); ps.setInt(1, userId);"
    },
    "secreview_specific": {
      "review_pass": "vulnerability_detection",
      "review_focus": ["input-validation", "injection-prevention"]
    }
  }
}
```

Key requirements (secreview-specific):
- `detector` must use `namespace.name` format (e.g., `web.sql-injection`), matching guard-rules naming
- `evidence.judgment_rationale` must cite relevant security standards (SEI CERT / OWASP / Go Security Guidelines)
- `impact.attack_scenario` is **required** — describe a concrete way an attacker could exploit this
- `secreview_specific.review_pass` indicates which reasoning pass identified the finding
- **Must include** `file`, `line`, `location`, `impact`, `fix` fields

**5b. Output lightweight `findings.json` + self-check:**

Same as secguard Step 4b-4c (see `commands/secguard.md`). Use `secreview-secguardian` paths.

**5c. Invoke renderer:**

```bash
python3 "$RENDERER" \
    --command secreview \
    --findings-dir <user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/findings/ \
    --index <user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/index.json \
    --output <user-project>/.codeagent/secreview-secguardian/scans/<scan_id>/
```

> ⚠️ If renderer unavailable: `"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 6: Output Review Summary

- After renderer completes, read `manifest.json` for review statistics.
- Output a Markdown review summary to the user, containing: scan_id, language, mode (full vs git diff), total findings by severity/type, and top findings with exploit scenarios.
- **Demo code detection**: If `<path>` contains `examples/` (demo/test code directory), append a note at the end:
  "Path contains demo/test code (examples/). The detected vulnerabilities are intentionally placed for testing purposes.
  CI gate zero-tolerance thresholds (Critical=0, High=0) are designed for production code
  and do not affect demo code used in test environments."
- **Demo code detection**: If `<path>` contains `examples/` (demo/test code directory), append a note at the end:
  "Path contains demo/test code (examples/). The detected vulnerabilities are intentionally placed for testing purposes.
  CI gate zero-tolerance thresholds (Critical=0, High=0) are designed for production code
  and do not affect demo code used in test environments."
