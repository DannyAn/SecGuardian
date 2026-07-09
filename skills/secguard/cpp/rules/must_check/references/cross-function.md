# Must-Check — Cross-Function Tracing (Max Depth 1)

## Principle

Cross-function tracing for unchecked return values follows the pointer through one function boundary. The question: *does any caller or callee check this return value?*

## Tracing Rule 1: Return Value Passed to a Checking Wrapper

```c
// caller.c
char *buf = malloc(1024);                    // unchecked here
if (validate_ptr(buf)) {                     // depth 1
    process(buf);
}

// validate_ptr.c
bool validate_ptr(void *p) {
    return p != NULL;
}
```

**Procedure**:
1. Locate `validate_ptr` in `symbols.functions`
2. Read the callee body (±15 lines)
3. Does it compare the pointer against NULL and return a bool?
4. If YES: the original `malloc` is safe — the check is deferred but present
5. If NO (wrapper just logs and returns same pointer): original is still unchecked — report `confirmed`

## Tracing Rule 2: Return Value Flows Into a Container

```c
// caller.c
char *buf = malloc(1024);
if (!buf) return ERROR;
insert_into_pool(pool, buf);                 // ownership transferred

// insert_into_pool.c
void insert_into_pool(pool_t *p, void *item) {
    p->items[p->count++] = item;             // just stores, no check needed
}
```

**Procedure**:
1. The `malloc` is already checked (`if (!buf)`), so the finding is safe
2. If the caller did NOT check before passing to `insert_into_pool`:
   - `insert_into_pool` does not dereference the pointer — so the finding is about potential future dereference
   - Mark as `suspicious` — the container now holds a potentially-NULL pointer for future use

## Tracing Rule 3: Return Value of a Callee Is the Allocation

```c
// caller.c
char *buf = read_config("path");
process(buf);                               // buf could be NULL from read_config

// read_config.c
char *read_config(const char *path) {
    FILE *fp = fopen(path, "r");
    if (!fp) return NULL;                   // valid NULL return from fopen
    char *buf = malloc(4096);
    if (!buf) { fclose(fp); return NULL; }
    fread(buf, 1, 4096, fp);
    fclose(fp);
    return buf;
}
```

**Procedure**:
1. Trace into `read_config` (depth 1)
2. `read_config` properly checks all allocations (fopen, malloc, fread)
3. The unchecked return `buf` in caller means: **caller must check**
4. If `caller` does NOT check `buf` before `process(buf)`: the `read_config` function itself is "safe" (it handles its failures), but `caller` has an unchecked dereference
5. Report as `confirmed` at the caller's call site: `char *buf = read_config("path");` — unchecked return propagation

## Tracing Rule 4: Two-Stage Wrapper Where Callee Is Inline

```c
// caller.c
char *buf = safe_malloc(count * sizeof(item_t));
process(buf);                               // unchecked

// safe_malloc.c
void *safe_malloc(size_t sz) {
    void *p = malloc(sz);
    if (!p) {
        log_error("OOM");
        abort();                            // never returns NULL
    }
    return p;
}
```

**Procedure**:
1. `safe_malloc` never returns NULL (aborts on OOM)
2. The `malloc` inside is checked — the wrapper is intentionally designed to skip caller-side checks
3. **Do NOT report**: the pattern is a deliberate trade-off (crash over silent corruption)
4. Exception: if `safe_malloc` logs but continues, or returns NULL in some path, report at caller

## Tracing Rule 5: IO Return Checked in the Read Loop

```c
// caller.c
int fd = open(path, O_RDONLY);
if (fd < 0) return;
char buf[4096];
int done = 0;
while (!done) {
    ssize_t n = read(fd, buf + total, sizeof(buf) - (size_t)total);
    if (n < 0) { done = 1; continue; }      // checked here
    if (n == 0) { done = 1; continue; }      // EOF
    total += (size_t)n;
}
process(buf);                               // buf is valid
```

**Procedure**:
1. The `read` return is checked inside the while loop
2. This is safe — every `read` return is validated before use
3. **Do NOT report** any read inside a loop that checks `n < 0` or `n == 0`

## When to Downgrade to Suspicious

| Scenario | Rationale |
|----------|-----------|
| `ptr = malloc(100);` at depth 0, usage in caller at depth 1 | The check may exist at depth 1 — cannot confirm without scanning caller |
| `int fd = socket(...)` at depth 0, fd passed to wrapper that may `if (fd < 0)` | Wrapper behavior unknown — marker-aware wrapper might check |
| `fp = fopen(path)` in library init, used in library close | The file pointer is checked on first use, not on creation — this is defensive, not a bug |
| `fgets` return unchecked inside a callback depth > 1 | Too many layers of indirection to trace all error paths |
