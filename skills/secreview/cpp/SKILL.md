---
name: secreview-cpp
description: "AI Code Security Review for C/C++ — memory safety, undefined behavior, and system security during pull request review"
category: language-specific
language: cpp
topic: [memory, concurrency, system, crypto]
---

# AI Security Code Review — C/C++

AI-powered security code review for C/C++ code. Designed for pull request review and completed implementation analysis.

Focus areas: memory safety, undefined behavior, system security, and business logic vulnerabilities in C/C++ codebases.

> **Prerequisite**: Command layer has executed `secguardian-index` to generate `index.json`. Use symbol table for review target identification rather than file-by-file traversal.

## Execution Phases

### Phase 1: Load Context

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`, `alloc_free.pairs`
2. Load `knowledge/languages/cpp.md` for C/C++ security pitfalls
3. Load `references/cpp-security-cheatsheet.md` for SEI CERT C/C++ mapping
4. If git diff mode, load `delta.json` for changed file/function scope

### Phase 2: Vulnerability Detection by Code Review

For each function (focusing on git-diff changed functions in PR mode):

| # | Check | Detection Method | Example: Non-compliant |
|---|-------|-----------------|------------------------|
| 1 | Memory operations | Search `strcpy`/`strcat`/`sprintf`/`gets` — safe alternative available? | `strcpy(buf, src);` -> use `strncpy` or `strlcpy` |
| 2 | Format string | Search `printf(`/`fprintf(` — is first arg a literal? | `printf(userInput);` -> `printf("%s", userInput);` |
| 3 | Integer overflow | Search `malloc(`/`calloc(` — multiplication checked for overflow? | `malloc(n * sizeof(T))` -> check `n > SIZE_MAX / sizeof(T)` |
| 4 | Buffer bounds | Search `arr[`/`ptr[` — index range validated? | `buf[i]` where `i >= sizeof(buf)` |
| 5 | Use-after-free | Trace `free()` calls — is pointer used after? | Cross-reference `alloc_free.pairs` for unmatched frees |
| 6 | Null dereference | Search `malloc()`/`calloc()` return — null check present? | `T* p = malloc(n); p->field = x;` without `if (!p) return;` |

**Pass output**: Each finding includes CWE mapping, exploit scenario, CVSS score, and fix recommendation.

### Phase 3: Business Logic & Framework Security

| # | Check | Detection Method | Fix Guidance |
|---|-------|-----------------|-------------|
| 1 | Compiler security flags | Check Makefile/CMakeLists.txt build options | Add `-fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie` |
| 2 | Signal safety | Search `signal(` — handler only async-signal-safe functions? | Handler only sets `volatile sig_atomic_t` flag |
| 3 | setuid privilege | Search `setuid(`/`setgid(` — privilege dropped early? | `setuid()` after fork, minimize before exec |
| 4 | Temporary files | Search `tmpfile(`/`tmpnam(`/`mktemp(` — safe creation? | Use `mkstemp()` with `umask(077)` |

### Phase 4: Anti-pattern Recognition

| # | Anti-pattern | Detection Signature | Fix |
|---|-------------|-------------------|-----|
| 1 | C-style cast | `(Type)expr` in C++ code | Replace with `static_cast<>`/`dynamic_cast<>`/`const_cast<>` |
| 2 | Raw pointer ownership | Function returns/passes `T*` with ownership semantics | Use `std::unique_ptr<T>` or `std::shared_ptr<T>` |
| 3 | reinterpret_cast misuse | Non-I/O use of `reinterpret_cast` | Prefer typed casts, document non-trivial cases |
| 4 | Virtual in ctor/dtor | Calling virtual functions in constructors/destructors | Extract to `Init()` or use factory pattern |
| 5 | Throwing destructor | `throw` or no `noexcept` in destructors | Destructor must be `noexcept`, catch-and-swallow exceptions |
| 6 | Mixed allocators | `new`/`delete` mixed with `malloc`/`free` on same object | Unify allocation style, pair correctly |

### Phase 5: Output

Follows `knowledge/protocols/scan-output.md` (v5.0). Each finding:

- File path + line number + function name (from index.json)
- CWE ID + exploit scenario
- CVSS severity assessment
- Fix recommendation (before/after code)

## Difference from secguard-cpp

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + 60 detectors | SEI CERT + OWASP + business logic + anti-patterns |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

## Reference Resources

- `references/cpp-security-cheatsheet.md` — C/C++ security cheat sheet
- `knowledge/standards/sei-cert-c.md` — SEI CERT C coding standard mapping
- `knowledge/standards/sei-cert-cpp.md` — SEI CERT C++ coding standard mapping

## Output Completeness Requirements

> **Output protocol**: Follow `knowledge/protocols/scan-output.md` (v5.0).
>
> Command layer Step 4b quality gate enforces four-segment completeness for each finding:
> 1. **Location** — File path + line + function + vulnerable code
> 2. **Evidence** — Code context (3 lines around) + judgment rationale citing security standards
> 3. **Impact** — Security risk + attack scenario (required)
> 4. **Fix** — Before/After code + verification method + SEI CERT/OWASP reference
>
> SARIF output: `message.markdown` with full four-segment content, `relatedLocations` for associated code, `fixes` with before/after replacements.
