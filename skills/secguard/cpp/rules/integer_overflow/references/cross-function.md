# Integer Overflow — Cross-Function Tracing (Max Depth 1)

## Principle

Cross-function tracing for integer overflow is limited to **max 1 level of indirection**. Beyond that, downgrade to `confidence: low` / `suspicious`. The rationale: overflow analysis requires precise knowledge of operand value ranges, which decays rapidly across function boundaries.

## Tracing Rule: Allocation Size from a Callee

### When the size argument to `malloc/calloc/realloc` is a function return value

```
malloc(compute_size(a, b));
//       ^^^^^^^^^^^^^^  depth 1
```

**Procedure**:
1. Locate the callee (`compute_size`) in `symbols.functions`
2. Read the callee body (±15 lines)
3. Check inside the callee: does the arithmetic have an overflow guard?
4. If NO guard inside callee: report `confirmed` — the caller trusts a size that may overflow
5. If guard present: report `safe` — overflow is handled before returning

**Example — Vulnerable**:
```c
// caller.c
void *arr = malloc(compute_size(count, sizeof(item_t)));

// compute_size.c
size_t compute_size(size_t n, size_t elem_size) {
    return n * elem_size;  // NO overflow check — report
}
```

**Example — Safe**:
```c
// caller.c
void *arr = malloc(compute_size(count, sizeof(item_t)));

// compute_size.c
size_t compute_size(size_t n, size_t elem_size) {
    if (n > SIZE_MAX / elem_size) return SIZE_MAX;  // overflow handled
    return n * elem_size;
}
```

## Tracing Rule: Check Deferred to a Wrapper Function

### When the caller does the check in a separate validation function

```c
// caller.c
if (!validate_size(count)) return;
void *arr = malloc(count * sizeof(item_t));  // relies on validate_size

// validate_size.c
bool validate_size(size_t n) {
    return n <= MAX_ITEMS;  // does this guard overflow?
}
```

**Procedure**:
1. Check if the validation function checks `n > SIZE_MAX / sizeof(element_type)`
2. If the validation only checks `n <= MAX_ITEMS` but NOT `SIZE_MAX / elem_size`, and `MAX_ITEMS` times `elem_size` can overflow: report `confirmed`
3. If `MAX_ITEMS * sizeof(item_t)` is trivially safe (e.g., both small constants): report `safe`

## Tracing Rule: Caller-Side Check After Callee Computation

```c
// caller.c
size_t total = compute_size(count, sizeof(item_t));
if (total > MAX_BUF) return;         // checks result after computation
void *arr = malloc(total);
```

**Procedure**:
1. The overflow already happened inside `compute_size` before the check
2. **Exercise extreme caution**: if `count` is large, `total` wrapped to a small value, and the check `total > MAX_BUF` passed because the wrapped value is small
3. Only consider safe if `compute_size` uses checked arithmetic internally, or if the caller checks each operand before calling
4. If caller only checks `total` after computation: report `confirmed`

## When to Downgrade to Suspicious

Downgrade from `confirmed` to `suspicious` in these cross-function cases:

| Scenario | Rationale |
|----------|-----------|
| Depth > 1: `malloc(f(g(h(x))))` | Too many layers; operand ranges are untraceable |
| Inline asm or non-standard calling convention | Cannot reliably parse the arithmetic |
| Callee is a virtual/dispatch function | The actual implementation is unknown until runtime |
| Callee is in a third-party library not in index.json | No source to inspect — flag as `suspicious` and note missing source |
| Value passes through a container/array lookup | Range depends on dynamic data not available statically |

## Summary Matrix

| Caller Pattern | Callee Contains Overflow Guard? | Report |
|---------------|-------------------------------|--------|
| `malloc(f(x))` | No | **confirmed** |
| `malloc(f(x))` | Yes | safe |
| `malloc(x * y)` after `f(x)` validates | f(x) checks range **and** `SIZE_MAX / y` | safe |
| `malloc(x * y)` after `f(x)` validates | f(x) only checks `<= MAX_ITEMS` | **confirmed** (unless trivially safe) |
| `malloc(f(g(x)))` | Either | **suspicious** (depth > 1) |
