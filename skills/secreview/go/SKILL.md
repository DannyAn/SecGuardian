---
name: secreview-go
description: "AI Code Security Review for Go — standard library security, concurrency safety, and Go-specific vulnerabilities during pull request review"
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---

# AI Security Code Review — Go

AI-powered security code review for Go code. Designed for pull request review and completed implementation analysis.

Focus areas: standard library pitfalls, concurrency safety, Go-specific security patterns, and business logic vulnerabilities.

> **Prerequisite**: Command layer has executed `secguardian-index` to generate `index.json`. Use symbol table for review target identification rather than file-by-file traversal.

## ⚙️ Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。
>
> **🔗 锚定+证据约束 (Rule A + Rule B):** 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表。MUST 提供 `--snippet`、`--code-context`、`--rationale`、`--attack-scenario`。调用 `record-finding.py` 时必须传 `--index-json` 进行锚定校验。无 index 锚点时 MUST 标记 `confidence: low`。

## Execution Phases

### Phase 1: Load Context

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`, `lock_graph.mutexes`
2. Load `knowledge/languages/go.md` for Go dangerous API list
3. If git diff mode, load `delta.json` for changed function scope

### Phase 2: Vulnerability Detection by Code Review

For each function (focusing on git-diff changed functions in PR mode):

| # | Check | Detection Method | Example: Non-compliant |
|---|-------|-----------------|------------------------|
| 1 | SQL injection | Search `fmt.Sprintf` + `db.Query`/`db.Exec` combo | `db.Query(fmt.Sprintf("SELECT * FROM users WHERE id=%s", id))` -> use parameterized query |
| 2 | Template engine | Search `text/template` import + HTML output | `import "text/template"` for HTML -> use `html/template` |
| 3 | Crypto random | Search `math/rand` for security contexts (token/key/session) | `rand.Intn(999999)` for verification code -> use `crypto/rand` |
| 4 | HTTP URL safety | Search `http.Get`/`http.Post` — user input in URL unvalidated? | `http.Get(userProvidedURL)` -> validate scheme/host |
| 5 | Command injection | Search `os/exec` — user input in command args? | `exec.Command("bash", "-c", userInput)` -> use arg array |
| 6 | Path traversal | Search `os.Open`/`ioutil.ReadFile` — path sanitized? | `os.Open(filepath.Join(base, userInput))` -> validate `Clean()` path starts with base |

**Pass output**: Each finding includes CWE mapping, exploit scenario, CVSS score, and fix recommendation.

### Phase 3: Business Logic & Framework Security

| # | Check | Detection Method | Fix Guidance |
|---|-------|-----------------|-------------|
| 1 | defer in loop | Search `for` + inner `defer` — resources released at loop end? | Extract loop body to function or manually close |
| 2 | Error info leak | Search `log.Print(err)`/`fmt.Println(err)` in HTTP responses | Generic client error, detailed internal log |
| 3 | Goroutine lifecycle | Search `go func` — context cancel/done channel present? | Each goroutine must `select` on `ctx.Done()` or done channel |
| 4 | Channel close | Search `close(` — is sender the only closer? | Only sender closes channel, receiver never closes |
| 5 | Mutex value copy | Search `sync.Mutex` — struct passed by value? | `sync.Mutex` must be pointer, never value-copied |

### Phase 4: Anti-pattern Recognition

| # | Anti-pattern | Detection Signature | Fix |
|---|-------------|-------------------|-----|
| 1 | interface{} overuse | Frequent `interface{}` parameters in function signatures | Define concrete interface type or use generics (Go 1.18+) |
| 2 | init() panic | `func init()` containing `panic()` or `log.Fatal()` | Move risky init to `main()` with explicit error handling |
| 3 | cgo misuse | C code without pointer validation / Go-C boundary memory issues | Follow cgo pointer passing rules, Go-side bounds check |
| 4 | reflect/unsafe overuse | Non-serialization `reflect`, non-necessary `unsafe` | Prefer type-safe alternatives, document `unsafe` necessity |
| 5 | iota bitmask overlap | `iota` for permission constants without `1 << iota` | Use `1 << iota` for unique permission bits |

### Phase 5: Output

Follows `knowledge/protocols/scan-output.md` (v5.0). Each finding:

- File path + line number + function name (from index.json)
- CWE ID + exploit scenario
- CVSS severity assessment
- Fix recommendation (before/after code)

## 🎯 Review Focus (Skill Layer)

> 以下内容定义了 review 的关注领域和规则，属于 Skill 层职责。

## Difference from secguard-go

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + detectors | Go Security Guide + OWASP + concurrency + anti-patterns |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

## 📄 Output Protocol

> 以下输出格式遵循 `internal/output/output_contract.md`。

## Output Completeness Requirements

> **Output protocol**: Follow `knowledge/protocols/scan-output.md` (v5.0).
>
> Command layer Step 4b quality gate enforces four-segment completeness for each finding:
> 1. **Location** — File path + line + function + vulnerable code
> 2. **Evidence** — Code context (3 lines around) + judgment rationale citing security standards
> 3. **Impact** — Security risk + attack scenario (required)
> 4. **Fix** — Before/After code + verification method + OWASP/SEI CERT reference
>
> SARIF output: `message.markdown` with full four-segment content, `relatedLocations` for associated code, `fixes` with before/after replacements.
