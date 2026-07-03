---
name: secreview-java
description: "AI Code Security Review for Java — dangerous API usage, framework security, and Java-specific vulnerabilities during pull request review"
category: language-specific
language: java
topic: [web, crypto, system]
---

# AI Security Code Review — Java

AI-powered security code review for Java code. Designed for pull request review and completed implementation analysis.

Focus areas: dangerous function usage, framework security (Spring), deserialization safety, and business logic vulnerabilities.

> **Prerequisite**: Command layer has executed `secguardian-index` to generate `index.json`. Use symbol table for review target identification rather than file-by-file traversal.

## Execution Phases

### Phase 1: Load Context

1. Read `index.json` — `files`, `symbols.functions`, `call_graph.edges`
2. Load `knowledge/languages/java.md` for Java dangerous API list
3. Load `knowledge/standards/sei-cert-java.md` for SEI CERT Java mapping
4. If git diff mode, load `delta.json` for changed function scope

### Phase 2: Vulnerability Detection by Code Review

For each function (focusing on git-diff changed functions in PR mode):

| # | Check | Detection Method | Example: Non-compliant |
|---|-------|-----------------|------------------------|
| 1 | SQL injection | Search `Statement.execute`/`createStatement` — user input concatenated? | `stmt.execute("SELECT * FROM users WHERE id=" + userId)` -> use `PreparedStatement` |
| 2 | XXE protection | Search `DocumentBuilderFactory`/`SAXParserFactory` — XXE disabled? | No `FEATURE_DISALLOW_DOCTYPE_DECL` -> vulnerable to XXE |
| 3 | Weak cryptography | Search `Cipher.getInstance` — algorithm parameters (ECB, DES, RC4)? | `Cipher.getInstance("AES/ECB/PKCS5Padding")` -> use GCM mode |
| 4 | Deserialization | Search `ObjectInputStream`/`readObject` — type whitelist present? | No `ObjectInputFilter` -> vulnerable to deserialization attacks |
| 5 | Log injection | Search `log.info(`/`logger.debug(` — user input in log format? | `log.info("User: " + request.getParameter("user"))` -> parameterized logging |
| 6 | Path traversal | Search `File`/`Files` — user-controlled path validated? | `new File(baseDir + fileName)` -> validate `getCanonicalPath()` |

**Pass output**: Each finding includes CWE mapping, exploit scenario, CVSS score, and fix recommendation.

### Phase 3: Business Logic & Framework Security

| # | Check | Detection Method | Fix Guidance |
|---|-------|-----------------|-------------|
| 1 | Crypto baseline | Check key lengths, algorithm versions, PRNG choice | AES-256-GCM + `SecureRandom`, disable DES/RC4/MD5/SHA-1 |
| 2 | HTTP security headers | Check Spring Security / Filter configuration | Enable HSTS/CSP/X-Frame-Options/X-Content-Type-Options |
| 3 | Session management | Check `HttpSession`/`SecurityContext` config | Cookie: `httpOnly`+`secure`+`sameSite`, timeout invalidation |
| 4 | Exception info leak | Search `e.printStackTrace()` in HTTP response | Global exception handler: generic message, full stack to log |
| 5 | CSRF protection | Check if CSRF protection is disabled for state-changing endpoints | Ensure `http.csrf().disable()` is justified and scoped |

### Phase 4: Anti-pattern Recognition

| # | Anti-pattern | Detection Signature | Fix |
|---|-------------|-------------------|-----|
| 1 | @Transactional self-call | Intra-class call to @Transactional method | Extract to separate Service Bean or use `AopContext.currentProxy()` |
| 2 | Filter ordering | Custom Filter without `@Order` | Explicit filter order: auth filters before authorization |
| 3 | @Autowired field injection | `@Autowired private XxxService service;` | Constructor injection + `final` for testability |
| 4 | SecurityManager absent | No `System.setSecurityManager()` with security policy | Evaluate need; ensure security policy file correctly configured |

### Phase 5: Output

Follows `knowledge/protocols/scan-output.md` (v5.0). Each finding:

- File path + line number + function name (from index.json)
- CWE ID + exploit scenario
- CVSS severity assessment
- Fix recommendation (before/after code)

## Difference from secguard-java

| Dimension | secguard (Secure Coding) | secreview (Code Review) |
|-----------|-------------------------|-------------------------|
| SDLC Stage | During coding | During pull request / code review |
| Granularity | API call level + detector filter | Function/module-level semantic + business logic |
| Primary Output | Vulnerability location + CVSS | CWE mapping + exploit scenario + business logic risk |
| Coverage | CWE Top 25 + detectors | SEI CERT Java + OWASP + Spring Security + anti-patterns |
| Typical Mode | Full codebase scan | Git diff / PR changeset |

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
