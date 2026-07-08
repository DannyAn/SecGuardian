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

## ⚙️ Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。
>
> **🔗 锚定+证据约束 (Rule A + Rule B):** 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表。MUST 提供 `--snippet`、`--code-context`、`--rationale`、`--attack-scenario`。调用 `record-finding.py` 时必须传 `--index-json` 进行锚定校验。无 index 锚点时 MUST 标记 `confidence: low`。

### 🧠 Finding Strategy: Assessment over Detection

secreview's value is NOT re-detecting what secguard already finds. The overlap in vulnerability **categories** is intentional — the differentiation is in **output and judgment**:

- **secguard** = "This IS a vulnerability" (fixed severity, deterministic check)
- **secreview** = "Is this EXPLOITABLE in this PR context?" (signal-based confidence, dynamic assessment)

**Decision rules to avoid redundant output:**

| If the code contains... | secreview does... |
|------------------------|-------------------|
| Vulnerable API on changed lines | Assess exploitability: trace data flow via `call_graph.edges`, assign confidence, estimate business impact → **surface finding** |
| Vulnerable API in unchanged context (adjacent function) | Regression check only → **P2/INFO**, no blocking |
| Vulnerable API not in `index.json` signals | No signal anchor → **skip** (not in diff scope) |
| Known vulnerability class but no exploit path | No tainted data flow → **downgrade severity**, may not block |

**Every finding MUST include all three:** `confidence` (from signal triage), `exploitability` (from data flow), `business_impact` (from PR context). A bare "uses dangerous API" without assessment is a secguard finding, not a secreview finding.

## Execution Phases

### Phase 1: Load Context

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`, `alloc_free.pairs`
2. Load `skills/secguard-cpp/references/language-features.md` for C/C++ language-specific features (custom allocators, compiler flags, SQL injection)
3. Load `references/cpp-anti-patterns.md` for C/C++ anti-pattern detection patterns
4. If git diff mode, load `delta.json` for changed file/function scope

### 🔬 Signal-Based Review Triage

Before scanning, triage the change set using `index.json` signals. This determines **review priority** and **finding confidence**.

| Priority | Signal Pattern | Implication |
|----------|---------------|-------------|
| P0 | `call_sites` hit + diff line + new `control_flow` path | New vulnerability path likely introduced |
| P1 | `call_sites` hit + diff line | New attack surface added |
| P2 | `call_sites` hit in adjacent (context) function | Regression risk |
| P3 | `string_literals` suspicious in diff | Credential/config leak risk |
| P4 | `control_flow` change in auth/security function | Logic flaw risk |

**Confidence assignment (must include in evidence rationale):**
| Level | Signal Basis | Output |
|-------|-------------|--------|
| HIGH | `call_sites` match + data flow path (via `call_graph.edges`) | Verifiable tainted path from input to sink |
| MEDIUM | `call_sites` match, no data flow path | Sink present but exploitability unconfirmed |
| LOW | pattern match only, no signal anchor | Indication only, manual validation needed |


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

## 🎯 Review Focus (Skill Layer)

> 以下内容定义了 review 的关注领域和规则，属于 Skill 层职责。

## Difference from secguard-cpp

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + 60 detectors | SEI CERT + OWASP + business logic + anti-patterns |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

## Reference Resources

- `references/cpp-anti-patterns.md` — C/C++ security anti-pattern detection matrix
- `knowledge/standards/sei-cert-c.md` — SEI CERT C coding standard mapping
- `knowledge/standards/sei-cert-cpp.md` — SEI CERT C++ coding standard mapping

## 📄 Output Protocol

> 以下输出格式遵循 `internal/output/output_contract.md`。

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
