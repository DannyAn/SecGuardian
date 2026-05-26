# secreview — security code review

## Available Languages

| Extension | Language | Review Skill |
|-----------|----------|-------------|
| `.java` | Java | Anti-patterns, best practices |
| `.py` | Python | Danger function review, concurrency |
| `.c/.cpp/.h` | C/C++ | Memory safety, UB, RAII |
| `.go` | Go | Stdlib safety, concurrency patterns |

## Execution Instructions

1. Detect target language by file extension distribution
2. Load `skills/secreview-<language>/SKILL.md` for review criteria
3. Check each source file against:
   - Security API misuse (unsafe functions, missing safeguards)
   - Anti-patterns (swallowed exceptions, debug leaks, type safety)
   - Best practice violations (framework config, concurrency, error handling)
4. For each violation, create a finding following the finding schema
5. Generate a Markdown review summary

## Scope

- NOT: line-level bug detection (use `/secguard` for that)
- IS: module-level semantic review

## Output Format

Same as system prompt schema. se Review-specific:
- Focus on anti-pattern and best practice categories
- Severity tends toward Medium-High (not typically Critical)
- Include reference links to secure coding standards
