---
name: secreview-js
description: "AI Code Security Review for JavaScript/Node.js — prototype pollution, async error handling, and JS-specific vulnerabilities during pull request review"
category: language-specific
language: javascript
topic: [web, crypto, system]
---

# AI Security Code Review — JavaScript/Node.js

AI-powered security code review for JavaScript/TypeScript code. Designed for pull request review and completed implementation analysis.

Focus areas: prototype pollution, async error handling, NoSQL injection, framework security (Express/React/Next.js), and business logic vulnerabilities.

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
2. Load `skills/secguard-js/references/language-features.md` for JS/Node.js dangerous API list
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
| 1 | Prototype pollution | Search `Object.assign`/`_.merge`/spread — recursive merge filters `__proto__`? | `_.merge(config, req.body)` -> use `_.merge({}, config, sanitize(req.body))` |
| 2 | NoSQL injection | Search `findOne(`/`find(` — query condition type-validated? | `User.findOne({username: req.body.username})` — `{$ne: null}` bypass |
| 3 | SSTI | Search `ejs.render`/`pug.compile`/`handlebars.compile` — user input in template source? | `res.render(userTemplate)` -> static template paths only |
| 4 | Weak cryptography | Search `crypto.createCipher`/`crypto.createHash('md5')` — algorithm choice? | `createCipher('aes-128-ecb', key)` -> use `createCipheriv('aes-256-gcm', key, iv)` |
| 5 | Unhandled promise | Search `await` — try-catch or `.catch()` chain present? | `await fetchData()` without catch -> add `.catch(handleError)` |
| 6 | Code injection | Search `eval()`/`new Function()`/`vm.runInNewContext()` — dynamic code execution? | Use `JSON.parse` for data, avoid dynamic code |

**Pass output**: Each finding includes CWE mapping, exploit scenario, CVSS score, and fix recommendation.

### Phase 3: Business Logic & Framework Security

| # | Check | Detection Method | Fix Guidance |
|---|-------|-----------------|-------------|
| 1 | Security headers | Search for helmet middleware | `app.use(helmet())` for all default security headers |
| 2 | Cookie security | Search `res.cookie(` — secure/httpOnly/sameSite? | `cookie('token', val, {httpOnly: true, secure: true, sameSite: 'strict'})` |
| 3 | CORS config | Search `cors(` — origin `*` or too permissive? | Whitelist origins, deny `Access-Control-Allow-Origin: *` |
| 4 | npm dependency safety | Check package.json — CI audit in place? | Run `npm audit --audit-level=high` in CI |
| 5 | SSR data leak | Next.js/Nuxt `getServerSideProps` — internal fields exposed? | Strip sensitive fields (password, token, internal IDs) before serialization |

### Phase 4: Anti-pattern Recognition

| # | Anti-pattern | Detection Signature | Fix |
|---|-------------|-------------------|-----|
| 1 | eval / dynamic code | `eval()` / `new Function()` / `vm.runInNewContext()` | Use `JSON.parse` for data, avoid dynamic code execution |
| 2 | Unhandled promise rejection | await without try-catch, Promise without `.catch()` | All awaits in try-catch; unified `process.on('unhandledRejection')` |
| 3 | Express error middleware leak | `err.stack` returned to client | Production: generic error message, stack in logging system |
| 4 | innerHTML / dangerouslySetInnerHTML | Direct HTML with user input | Use `textContent` or DOMPurify-sanitized content |
| 5 | localStorage sensitive data | JWT/Token stored in `localStorage.setItem()` | JWT in httpOnly cookie, sensitive data in memory only |
| 6 | Math.random() for security | Verification codes/tokens using `Math.random()` | Use `crypto.randomBytes()` or `crypto.randomUUID()` |
| 7 | Mongoose field leak | Schema password/token without `select: false` | Set `select: false`, explicit `.select('+field')` for queries |
| 8 | TypeScript any bypass | `(data as any).dangerousMethod()` | Define full type interfaces, no `any` on security-sensitive paths |
| 9 | Service Worker auth caching | SW caching responses with Authorization header | Filter auth requests, never cache Authorization/Cookie responses |

### Phase 5: Output

Follows `knowledge/protocols/scan-output.md` (v5.0). Each finding:

- File path + line number + function name (from index.json)
- CWE ID + exploit scenario
- CVSS severity assessment
- Fix recommendation (before/after code)

## 🎯 Review Focus (Skill Layer)

> 以下内容定义了 review 的关注领域和规则，属于 Skill 层职责。

## Difference from secguard-js

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + detectors | OWASP + Node.js security + React/Next.js + anti-patterns |
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
