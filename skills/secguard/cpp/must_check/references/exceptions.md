# Must-Check — Suppression Edge Cases

## 1. Return Discarded Explicitly With `(void)`

```c
// Do NOT report: explicit discard is intentional
(void)write(fd, banner, banner_len);    // best-effort logging
(void)snprintf(buf, sizeof(buf), "%s", msg);  // truncation acceptable
```

**Rule**: If the function is immediately cast to `(void)`, the developer intentionally discarded the return. Report only if the comment or context suggests the return matters (e.g., `(void)snprintf` in a security-critical path).

## 2. Return Checked Through an Error Variable

```c
// Do NOT report: return is validated through errno or other mechanism
char *buf = malloc(1024);
errno = 0;
// ... 3 lines later ...
if (errno == ENOMEM) return;                       // indirect null check
```

**Rule**: `errno` is **not** a reliable indicator for allocation failure (malloc may not set errno consistently). Only suppress if the check pattern is well-known: `if (!buf)` for NULL, `if (ret < 0)` for socket, `if (!fp)` for fopen.

## 3. Macro Wrapper That Checks Internally

```c
// Do NOT report: MALLOC_CHECK is a checked wrapper
#define MALLOC_CHECK(p) if (!(p)) { abort(); }
char *buf = malloc(1024);
MALLOC_CHECK(buf);                                    // crash on OOM, not silent
```

**Rule**: Accept any macro defined in the same file or included header that checks the pointer value against NULL and terminates or returns. Search for `if.*NULL.*abort\|if.*!p.*log\|CHECK.*malloc\|ENSURE.*ptr` style patterns in the 5 lines after the allocation.

## 4. Allocation Inside a Known-Reliability Context

```c
// Do NOT report: early program init — OOM is catastrophic anyway
int main() {
    char *huge = malloc(1024 * 1024 * 1024);     // at init, OOM aborts program
}
```

**Rule**: `main()` and static initializers where failure is equivalent to "can't start" may omit returns. Report as `low` confidence but flag if the allocated memory is used for security-critical data (password buffers, crypto keys).

## 5. Signal Handler (Async-Signal-Safe Context)

```c
// Do NOT report: async-signal-safe context — `write` is used but checking is impractical
void handler(int sig) {
    write(STDERR_FILENO, msg, len);               // can't check, can't block
}
```

**Rule**: Functions called from signal handlers are exempt from return-value checking because the handler cannot handle errors (no return, no errno, no abort). This is an acceptable omission.

## 6. Death-March Allocations (Performance-Critical)

```c
// Do NOT report: hot path where OOM causes segfault anyway
void insert_hot_path(hash_t *h, item_t *v) {
    node_t *n = malloc(sizeof(node_t));           // embedded systems w/ guar
    n->value = v;
    h->buckets[idx] = n;
}
```

**Rule**: Only suppress in embedded or real-time systems where the code is **documented** to have guaranteed memory. Report as `suspicious` if unannotated — the developer may have assumed incorrectly.

## 7. Varargs / Pattern Where Checking Is on the Caller

Some functions propagate their return upward rather than checking internally.

```c
// Do NOT report: the caller does the check
char *read_file(const char *path) {
    FILE *fp = fopen(path, "r");
    if (!fp) return NULL;                                  // propagate
    ...
}
// Caller side:
char *data = read_file("config.cfg");
if (!data) return;                                          // up to caller to handle NULL
```

**Rule**: If the allocating function returns the pointer (ownership transfers upward) and the caller is responsible for checking, the middle function's unchecked return is acceptable. The must-check burden is on the **point of dereference**, not the allocation point.

## 8. Ignored Return from Functions Guaranteed to Succeed

```c
// Do NOT report: fclose returns error but file already closed
fclose(fp);                   // resources released; error about flush is informational

// Do NOT report: realloc(ptr, 0) semantics — some implementations return NULL
```

**Rule**: `fclose` and `free` are common exceptions. Only `free` is universally safe to ignore. For `fclose`, the error matters only in write mode (data loss). Default: report `fclose` in write mode as `low` confidence only.
