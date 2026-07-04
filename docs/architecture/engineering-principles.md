# SecGuardian Engineering Principles

> **Document**: Anti-Over-Engineering Constraints
> **Purpose**: Prevent premature abstraction, platformization, and system design
> **Updated**: 2026-07-04
> **Enforcement**: Every architecture proposal must pass all principles below

---

## Principle EP-1: No Premature Execution Kernel Abstraction

### Statement

Do not design or implement a "Security Engine," "Execution Kernel,"
"Rule Runtime," or any system that abstracts the current LLM-driven
execution path into a pluggable or replaceable component.

### Rationale

The current system has exactly **one execution strategy**: LLM-assisted.
Extracting a kernel interface before a second strategy exists creates:
- An abstract interface with one implementation (useless abstraction)
- Maintenance burden for zero benefit
- Design decisions that constrain future strategy implementation
- A false sense of modularity (the interface implies two strategies exist)

### What to Do Instead

When a second execution strategy (e.g., deterministic matching) is ready
for production, extract it from real, tested code — not from a design doc.

### Violation Example

```go
// ❌ Premature
type SecurityEngine interface {
    Scan(ctx context.Context, index Index, rules []Rule) (*Result, error)
}
// One implementation today, another "someday" — bad abstraction.
```

### Non-Violation Example

```go
// ✅ Acceptable — concrete, not abstract
func runLLMAssistedScan(index Index, rules []Rule, llm LLMClient) (*Result, error) {
    // Build prompt, call LLM, parse response.
}
// When deterministic strategy arrives, add runDeterministicScan() —
// no interface needed until 3+ strategies share common logic.
```

---

## Principle EP-2: No Unimplemented Runtime

### Statement

Do not introduce a "Runtime," "Execution Mode," or "Platform" that has
no implementation in the current codebase.

### Rationale

Designing a runtime that does not exist yet leads to:
- Architecture that optimizes for imaginary constraints
- Premature platformization (CI/CD platform before CI/CD integration)
- Implementation pressure to build "runtime infrastructure" that
  should be a thin wrapper

### What to Do Instead

Let runtimes emerge from real integrations. When CI/CD support is
implemented, document it as "CI/CD Integration" — not "CI Runtime."

### Current Enforcement

There is exactly **one runtime**: the AI Agent (or terminal via wrapper).
"CI Runtime" does not exist as an independent entity. It is a future
consumption mode of the same pipeline.

---

## Principle EP-3: All CI/CD Design Must Be Artifact-Based

### Statement

CI/CD integration must be designed around **output artifacts**, not
execution logic. CI reads what the pipeline produces. It does not
control how the pipeline runs.

### Rationale

CI/CD's value is:
1. **Telemetry** — score trends, finding lifecycle
2. **Gate** — pass/fail based on artifact data
3. **Evidence** — SARIF for compliance

These do not require controlling execution. They only require reading
the output directory. Any CI design that requires pipeline changes
(not artifact format changes) is over-engineering.

### What to Do Instead

Design CI integration as:
```
Pipeline → output artifacts → CI reads artifacts → gate decision
```
Not:

See `docs/ci-cd-interface.md` for the CI/CD artifact consumption contract.
```
CI controls pipeline → CI-specific execution mode → CI-specific artifacts
```

---

## Principle EP-4: Engine Abstraction Requires 2+ Production Use Cases

### Statement

Before abstracting any execution logic (rule loading, index matching,
finding generation) into a shared interface or engine, there must be
at least **two production use cases** that prove the abstraction is
correct and necessary.

### Rationale

Single-use-case abstractions are wrong 90% of the time. The second
use case always reveals constraints that the first didn't have (e.g.,
language-specific rule formats, context window differences, output
schema variations).

### What to Do Instead

Implement the first use case concretely. When the second use case
arrives and shares logic, extract the shared code into a concrete
shared function — not an abstract interface.

---

## Principle EP-5: Knowledge Is Markdown, Not DSL

### Statement

Detector rules are Markdown files consumed by LLM prompts. Do not
design a DSL, structured rule format, or rule compiler until:
1. The Markdown format has failed in production (e.g., rules are too
   complex for LLM to interpret)
2. A deterministic matcher has been validated against 2+ detectors

### Rationale

Structured rules (YAML/JSON with regex, CWE, severity, pattern) imply
deterministic matching. But the current system uses LLM-driven reasoning,
not pattern matching. Structured rules would add tooling overhead without
changing how the system executes.

### What to Do Instead

Keep rules in Markdown. Add structured frontmatter (YAML) incrementally
when a specific detector proves it needs deterministic matching. Do not
redesign the rule format before the execution strategy changes.

---

## Principle EP-6: One Pipeline, Multiple Consumption Modes

### Statement

There is exactly **one execution pipeline**. All consumption modes
(AI Agent, CLI, CI/CD) consume its output. No consumption mode gets
a separate pipeline.

### Rationale

Pipeline splits create:
- Divergent outputs (different findings from same codebase)
- Debug hell (which pipeline produced this finding?)
- Maintenance burden (updates must propagate to N pipelines)

### What to Do Instead

Extend the output protocol for new consumption modes. The pipeline
stays unchanged. Add new artifact types or format variations, not
new execution paths.

---

## Principle EP-7: Document What Exists, Not What Might Exist

### Statement

Architecture documentation must describe the **current system**.
Future directions are allowed as brief "Future Direction" notes,
but the majority of each document must describe what exists today.

### Rationale

Documenting what might exist creates:
- Implementation pressure to build the documented future system
- Confusion when the documented system doesn't match the codebase
- A credibility gap when future directions change

### What to Do Instead

Use this document structure:
```
1. Current System (80% of document) — what exists today
2. Future Direction (20% of document, optional) — what might exist
```

Future Direction sections must be explicitly labeled as research/exploration,
not as implementation plans.

---

## Summary Table

| # | Principle | Enforcement |
|---|-----------|-------------|
| EP-1 | No premature execution kernel abstraction | No SecurityEngine interface or API |
| EP-2 | No unimplemented runtime | No CI Runtime as entity |
| EP-3 | CI/CD artifact-based | CI reads output artifacts, not pipeline |
| EP-4 | Engine abstraction needs 2+ use cases | No shared interfaces before 2nd strategy |
| EP-5 | Knowledge is Markdown, not DSL | No rule format redesign |
| EP-6 | One pipeline, multiple consumption modes | No pipeline split |
| EP-7 | Document what exists, not what might exist | 80% current system per doc |

---

## Review History

| Date | Reviewer | Notes |
|------|----------|-------|
| 2026-07-04 | ChatGPT (Round 1 review) | Identified over-engineering in Engine interface, dual-runtime, and rule DSL assumptions. These principles are the direct output of that review. |
