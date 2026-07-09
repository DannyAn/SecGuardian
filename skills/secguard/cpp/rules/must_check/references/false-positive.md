# Must-Check — False Positive Suppression Strategies

## Strategy 1: Check Outside Visible Context (Split Declaration)

The most common FP: the check is present but outside the ±15-line read window.

```c
// Line 10:  char *buf = malloc(1024);           // found by detector
// Line 11:  use(buf);
// ...
// Line 25:  if (!buf) return;                     // not in read window
```

**Suppression logic**: If a call site is found with no check in the immediate ±15 lines, AND the variable is used within those same lines, AND there is an `if` that names the same variable earlier (out of read window), widen the read window by 15 more lines and re-evaluate.

## Strategy 2: Allocation Inside a Loop With Late Check

```c
// Lines 50-60:
while (condition) {
    char *buf = malloc(1024);                    // found: unchecked
    if (!buf) continue;                          // checked — OK
}
```

**Suppression**: If the check is in a `continue`/`break`/`return` within 3 lines of the allocation, within the same block scope, the allocation is safe.

## Strategy 3: Errno/Side-Channel Validation Is Not Sufficient

```c
// Do NOT consider this a valid check:
char *buf = malloc(1024);
errno = 0;
use(buf);
```

`errno` is not reliably set by `malloc`. Do NOT accept any form of side-channel validation as a valid check. Only direct pointer comparison against NULL counts.

## Strategy 4: Recognized Checked-Allocation Wrappers

Some well-known wrappers already validate:

```c
// Suppress allocations inside these:
xmalloc(sz);           // glib/WebKit — aborts on OOM
safe_malloc(sz);       // custom — check its definition first
MALLOC(sz);            // macro — likely CHECKED
g_new(Type, n);        // glib — aborts on OOM
new (std::nothrow)     // C++ nothrow: returns nullptr on failure
```

**Procedure**: If the wrapper is defined in the same project (in `symbols.functions`), read its body and check for NULL check + abort/exit. If the wrapper aborts, suppress. If it just returns NULL, do NOT suppress — the caller still needs to check.

## Strategy 5: Unused Return in Non-Security-Critical Context

```c
// Suppress: logging/write to stderr is best-effort
write(STDERR_FILENO, msg, len);                   // logging path

// Suppress: trace/debug prints
fprintf(stderr, "entered function\n");            // debug path
```

**Rule**: Only suppress if ALL of these hold:
1. The I/O is to stderr or a log file (not to a network socket or data file)
2. The output is diagnostic-only (not business data)
3. There is no upstream expectation that the write completes

## Strategy 6: Known-Valid Return Guarantee

Some functions guarantee their return value in specific configurations:

```c
// snprintf with N == 0 returns bytes that WOULD be written, always nonnegative
snprintf(NULL, 0, "%s", data);                    // size query pattern

// malloc(0) implementation-defined behavior — some always return non-NULL
```

**Rule**: Do not report `snprintf(NULL, 0, ...)` — it's the size-query pattern. Do not report `malloc(0)` — it's often used as a valid empty allocation. These are well-known idioms.

## Strategy 7: The `if (condition); func()` Single-Line Deception

```c
// BAD style, but NOT a must-check finding:
if (!some_condition);                          // dangling semicolon — NOT related to allocation
char *buf = malloc(1024);                      // the check below is actually for buf
if (!buf) return;
```

The `if (!some_condition);` is a no-op. The real check `if (!buf)` is present. The detector must distinguish between: `if (!some_flag); /* unrelated */ char *b = malloc(1024); if (!b) return;` (safe) and the genuinely unchecked pattern.

## Strategy 8: Short-Lived Temporary Allocation on Stack

```c
char small[64];       // stack allocation — can't "fail" in practice
// But VLA can fail:
char vla[n];           // VLA failure is runtime; no return to check
```

**Rule**: Stack array declarations (`char buf[CONSTANT]`) do not need checking. Variable-length arrays (`char buf[n]`) are unchecked by nature — report as `suspicious` if `n` is potentially large and the function has no stack-overflow guard. Skip reporting entirely for fixed-size arrays.

## Strategy 9: Excessive Checking Is Also an Anti-Pattern

```c
// Some projects double-check; avoid double-reporting:
char *buf = malloc(1024);
if (!buf) abort();                               // valid check
// ... 20 lines later ...
if (!buf) { /* redundant */ }                    // buf cannot be NULL after first check
```

**Rule**: If the first check is present (and not in a dead branch), do NOT flag subsequent usage. Only report if a code path exists where allocation succeeds (pointer non-NULL) but a subsequent mutation could make it NULL.
