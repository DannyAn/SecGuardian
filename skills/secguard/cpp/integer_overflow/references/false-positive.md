# Integer Overflow — False Positive Suppression Strategies

## Strategy 1: Whitelist Guarded Multiplication

The most common FP trigger: a `malloc(n * sizeof(T))` that appears to overflow, but the code uses the idiomatic range-limit pattern upstream.

**Suppression logic**: Search the preceding 10 lines for a conditional that compares one operand against `SIZE_MAX / sizeof_result`. Acceptable forms:

```c
// Acceptable guard forms:
if (n > SIZE_MAX / sizeof(T))     // division-based
if (__builtin_mul_overflow(...))  // builtin
if (ckd_mul(...))                 // C23
if (n > UINT_MAX / sizeof(T))     // type-specific limit (non-size_t)
```

## Strategy 2: Recognize Safe Size Types

Some integer types have natural upper bounds that prevent overflow in practice:

```c
// Types with trivially safe ranges:
uint16_t small;                     // max 65535
uint8_t tiny;                       // max 255
int idx;
if (idx < 100) { ptr->items[idx * sizeof(T)]; }  // idx bounded
```

**Suppression heuristic**: If the runtime operand's type is `uint16_t` or smaller OR is an `int`/`size_t` proven bounded to `< 1024` by surrounding code, mark the multiplication as low-risk.

## Strategy 3: Reject FP from sizeof-Only Expressions

`sizeof` is a compile-time constant in C/C++. Expressions consisting entirely of `sizeof(x) * sizeof(y)` are safe:

```c
// All safe:
size_t sz = sizeof(int) * sizeof(short);    // 4 * 2 = 8
size_t sz = sizeof(struct Header) * 256;    // known constant
```

**Suppression rule**: If all operands are `sizeof(...)` expressions or integer literals — no runtime variable involved — suppress automatically.

## Strategy 4: Recognize reallocarray / calloc Overflow Protection

`calloc` and `reallocarray` already check overflow internally:

```c
// These are internally safe — do NOT report:
arr = calloc(n, sizeof(T));                          // calloc does n*sizeof(T) with overflow check
arr = reallocarray(NULL, n, sizeof(T));               // same, with realloc
arr = reallocarray(ptr, ns, sizeof(T));               // same
```

**Exception**: `calloc` is guaranteed safe in POSIX and C11 onward. `reallocarray` is in OpenBSD, glibc 2.26+, FreeBSD. For embedded/legacy libc, fall back to `calloc` safety assumption.

## Strategy 5: Function-Level Suppression via Annotations

If a function is annotated or documented as having a bounded domain:

```c
// Suppress if any of these are found:
__attribute__((integer_overflow_safe))
// Or documentation comment:
// PARAM(n): n <= MAX_BLOCKS, where MAX_BLOCKS * sizeof(T) < SIZE_MAX
```

Custom attributes are rare — this strategy applies mainly to well-known library wrappers.

## Strategy 6: Review Context for Redundant Checks

```c
// Example of false "overflow before check":
size_t total = n * sizeof(T);          // <-- triggers FP: "overflow before check"
if (total > MAX_BUF) return;          // <-- but the check still prevents over-allocation
```

**Reality**: The overflow happened BEFORE the check, so `total` could be wrong. However, if `MAX_BUF` is small enough that a wrapped `total > MAX_BUF` still evaluates true (i.e., the wrapped value is small but still less than MAX_BUF due to wrapping), it's a genuine FP. This is subtle:

- If `n = SIZE_MAX / sizeof(T) + 1`, then `total ≈ 0`. If `MAX_BUF = 100`, then `0 > 100` is FALSE — the check is bypassed. **This is a real bug, not FP.**
- If `SIZE_MAX / sizeof(T) + 1` produces a wrapped value between `0` and `MAX_BUF`, the check is bypassed.

**Do NOT assume "check after operation" makes it safe.** Only suppress if:
1. The operand range is provably bounded (e.g., `n` is `uint8_t`), OR
2. The check uses `__builtin_add_overflow` / `ckd_add` and branches on the result

## Strategy 7: Known Safe Libraries and Frameworks

Some libraries guarantee checked allocation:

| Library | Functions | Suppression |
|---------|-----------|-------------|
| glib | `g_malloc(n)`, `g_new(T, n)` | Always safe (logs and aborts on overflow) |
| APR | `apr_palloc(pool, sz)` | Pool allocator, safe |
| jemalloc | implicit | Standard behavior; no builtin overflow check — do NOT suppress |
| tcmalloc | `tc_malloc` | Standard behavior — do NOT suppress |

Only suppress for libraries that **document and guarantee** overflow-safe allocations.

## Strategy 8: When in Doubt, Mark Suspicious

If the FP suppression logic cannot definitively determine safety, do NOT suppress — mark as `suspicious` instead of `confirmed`. This forces human review without blocking CI:

```ruby
confidence = confirmed? ? "confirmed" : "suspicious"
# Criteria for confirmed:
# - No overflow guard found in scope (same function OR depth-1 callee)
# - Operand is runtime variable of size >= uint32_t
# - Result used in allocation or boundary check
```

**Never suppress a finding purely because "it seems unlikely."**
