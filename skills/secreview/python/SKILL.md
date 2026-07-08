---
name: secreview-python
description: "AI Code Security Review for Python — dangerous API usage, framework vulnerabilities, and Python-specific security issues during pull request review"
category: language-specific
language: python
topic: [web, crypto, system]
---

# AI Security Code Review — Python

AI-powered security code review for Python code. Designed for pull request review and completed implementation analysis.

Focus areas: dangerous function usage, framework security (Django/Flask), deserialization safety, and business logic vulnerabilities.

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

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`
2. Load `skills/secguard-python/references/language-features.md` for Python dangerous function list
3. If git diff mode, load `delta.json` for changed function scope

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
| 1 | SQL injection | Search `cursor.execute`/`.raw()` — f-string/%/.format in SQL? | `cursor.execute(f"SELECT * FROM users WHERE id={uid}")` -> parameterized query |
| 2 | Unsafe deserialization | Search `pickle.load`/`yaml.load`/`dill.load` — is data source untrusted? | `pickle.loads(request.data)` -> use `json.loads()` |
| 3 | Weak cryptography | Search `random.randint`/`random.choice` for security contexts | `random.randint(0, 999999)` for code -> use `secrets.randbelow()` |
| 4 | Command injection | Search `os.system`/`subprocess.call` — `shell=True` with user input? | `subprocess.call(f"ping {host}", shell=True)` -> use arg array |
| 5 | SSTI | Search `render_template_string`/`Jinja2.from_string` — user input in template? | `render_template_string(user_input)` -> use static templates |
| 6 | Path traversal | Search `open()`/`os.path.join()` — user-controlled path? | `open(os.path.join(upload_dir, filename))` -> validate resolved path |

**Pass output**: Each finding includes CWE mapping, exploit scenario, CVSS score, and fix recommendation.

### Phase 3: Business Logic & Framework Security

| # | Check | Detection Method | Fix Guidance |
|---|-------|-----------------|-------------|
| 1 | DEBUG mode | Search `DEBUG = True` — production config? | Production `DEBUG = False`, use env variables |
| 2 | Template safety | Search `render_template_string`/`render` — auto-encoding? | Use `render_template` (auto-escape), avoid `render_template_string(user_input)` |
| 3 | CORS config | Search `CORS_ORIGIN_ALLOW_ALL`/`allow_origins` — too permissive? | Whitelist specific origins, disable `allow_origins=['*']` |
| 4 | JSON response | Search `HttpResponse(json.dumps(data))` — manual JSON? | Use `JsonResponse(data)` for correct Content-Type + encoding |
| 5 | Auth check consistency | Search views — is authentication consistent on all endpoints? | Ensure `@login_required`/equivalent on every authenticated endpoint |

### Phase 4: Anti-pattern Recognition

| # | Anti-pattern | Detection Signature | Fix |
|---|-------------|-------------------|-----|
| 1 | Bare except swallowing | `except Exception: pass` or `except: pass` | Log `logger.exception()`, name specific exception types |
| 2 | hasattr auth bypass | `if hasattr(obj, 'is_admin')` for auth checks | Use explicit attribute dict or ACL, not attribute existence |
| 3 | __getattr__ hijacking | Custom `__getattr__` returning uncontrolled dynamic attributes | Limit return scope, validate sensitive attribute access |
| 4 | Dynamic import abuse | `importlib.import_module(user_input)` / `__import__(user_input)` | Use registry/mapping table, ban user-based dynamic imports |
| 5 | Monkey-patch safety | Runtime module replacement bypassing security logic | Mark critical security functions as non-patchable using `wrapt.decorator` |

### Phase 5: Output

Follows `knowledge/protocols/scan-output.md` (v5.0). Each finding:

- File path + line number + function name (from index.json)
- CWE ID + exploit scenario
- CVSS severity assessment
- Fix recommendation (before/after code)

## 🎯 Review Focus (Skill Layer)

> 以下内容定义了 review 的关注领域和规则，属于 Skill 层职责。

## Difference from secguard-python

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + detectors | OWASP + Django/Flask security + concurrency + anti-patterns |
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
> 4. **Fix** — Before/After code + verification method + OWASP reference
>
> SARIF output: `message.markdown` with full four-segment content, `relatedLocations` for associated code, `fixes` with before/after replacements.
