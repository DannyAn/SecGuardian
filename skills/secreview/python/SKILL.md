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

## Execution Phases

### Phase 1: Load Context

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`
2. Load `knowledge/languages/python.md` for Python dangerous function list
3. If git diff mode, load `delta.json` for changed function scope

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

## Difference from secguard-python

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + detectors | OWASP + Django/Flask security + concurrency + anti-patterns |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

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
