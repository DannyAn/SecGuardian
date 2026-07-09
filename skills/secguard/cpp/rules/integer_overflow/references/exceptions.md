# Integer Overflow — Suppression Edge Cases

## 1. Compile-Time Constant Arithmetic

All operands are compile-time constants — the compiler evaluates the expression and rejects overflow at build time.

```c
// Do NOT report: all constants
buf = malloc(256 * sizeof(int));
buf2 = calloc(64, sizeof(short));

// Do NOT report: sizeof result + constant
buf = malloc(sizeof(int) + sizeof(short));
```

**Rule**: If every operand in the arithmetic expression is a literal, sizeof expression, or enum constant, AND the expression involves no runtime variable, skip the finding.

## 2. Pre-Checked Values

The arithmetic is safe because a guarding comparison was evaluated before the expression runs.

```c
// Do NOT report: if (n > SIZE_MAX / sizeof(T)) guards the multiplication
if (count > SIZE_MAX / sizeof(item_t)) return;
item_t *arr = malloc(count * sizeof(item_t));
```

**Rule**: If within the preceding 10 lines there is an `if` that compares a multiply operand against `SIZE_MAX / operand` or similar divide-based guard, the allocation is protected.

## 3. Safe Builtins Already Used

GCC/Clang checked-arithmetic builtins or C23 standard checked-arithmetic macros are in use.

```c
// Do NOT report: __builtin_mul_overflow handles overflow detection
size_t total;
if (__builtin_mul_overflow(count, sizeof(item_t), &total)) return;
buf = malloc(total);

// Do NOT report: C23 ckd_mul
if (ckd_mul(&total, count, sizeof(item_t))) return;

// Do NOT report: reallocarray is inherently safe
p = reallocarray(NULL, n, sizeof(T));
```

**Rule**: If the exact allocation statement or the immediately preceding conditional uses `__builtin_*_overflow`, `ckd_mul`, `ckd_add`, or `reallocarray`, skip the finding.

## 4. Idiomatic Safe Patterns

Some patterns look dangerous but are standard and safe.

```c
// Do NOT report: sizeof member in array — `sizeof` is a constant
arr = malloc(n * sizeof(struct huge));  // sizeof is compile-time eval

// Do NOT report: well-known constant multiplication
cache = calloc(1, PAGE_SIZE * 4);

// Do NOT report: small fixed expansions
buf = realloc(ptr, current_cap * 2);  // common grow pattern; if cap is capped
```

**Rule**: `sizeof` is always compile-time in C/C++. When one operand is `sizeof(E)` and the other is a pointer-size or usage-size variable, evaluate the actual range — only report if the runtime variable can reasonably exceed `SIZE_MAX / sizeof_result`.

## 5. Non-Security-Critical Overflow

The overflow result is not used for memory allocation, array indexing, or security boundary checks.

```c
// Do NOT report: overflow used only for display/logging
size_t elapsed = start + delta;   // wraps but only used for logging
printf("Time: %zu", elapsed);

// Do NOT report: statistical counter
stats.total_bytes += incoming;    // wrap is acceptable for counting
```

**Rule**: The overflow must affect a `malloc/calloc/realloc/new` size argument, a `memcpy/memmove` length, an array index expression, or a buffer boundary check. Purely cosmetic or statistical use is excluded.

## 6. Size-Limited Input Domain

The upstream API contract guarantees the value stays within range.

```c
// Do NOT report: loop variable is bounded by array length
for (int i = 0; i < 100; i++) {
    sum += arr[i];                           // i is trivially bounded
}

// Do NOT report: bit-length bounded
uint8_t small;
size_t idx = small * sizeof(int);            // max 255 * 4 < SIZE_MAX
```

**Rule**: If the runtime variable's type and context together prove the value is less than a small constant (e.g., `uint8_t`, `int` loop variable bounded to `< 256`), and the multiplication result is necessarily less than `SIZE_MAX`, skip.

## 7. Defensive Value Truncation After Cast

```c
// Do NOT report: value range truncated by cast to smaller type
uint64_t big = external_input;
size_t sz = (size_t)big;                     // truncates high bits but semantically fine
```

**Rule**: Truncation itself is not an overflow finding — the truncation must cause a security-critical wrap in a subsequent arithmetic operation. If the truncated value is used directly in an allocation without arithmetic, do not report.
