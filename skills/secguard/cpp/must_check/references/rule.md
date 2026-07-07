# Must-Check — Vulnerable vs Safe Patterns

## Pattern 1: Allocation Return Not Checked (malloc/calloc/realloc)

### Vulnerable

```c
// BAD: return not checked — NULL dereference if allocation fails
char *buf = malloc(1024);
memcpy(buf, data, len);                   // crash if buf is NULL

// BAD: implied cast discards check
int *arr = (int *)calloc(n, sizeof(int));
arr[0] = 42;                               // NULL deref on OOM

// BAD: checked only after first use
char *buf = malloc(1024);
buf[0] = '\0';                              // used before check!
if (!buf) return;                           // check is too late

// BAD: realloc with same pointer — old pointer lost on failure
ptr = realloc(ptr, new_size);               // if realloc fails, ptr=NULL and old memory leaked
```

### Safe

```c
// GOOD: immediate NULL check
char *buf = malloc(1024);
if (!buf) return ENOMEM;
memcpy(buf, data, len);

// GOOD: use temp pointer for realloc to avoid leak
void *newptr = realloc(ptr, new_size);
if (!newptr) {
    free(ptr);                             // old memory preserved
    return ENOMEM;
}
ptr = newptr;                              // only update on success

// GOOD: calloc, same rule
int *arr = (int *)calloc(n, sizeof(int));
if (!arr) return ERROR;
```

## Pattern 2: fopen/clopen/mmap Return Not Checked

### Vulnerable

```c
// BAD: fopen can return NULL — no check before use
FILE *fp = fopen(path, "r");
fread(buf, 1, size, fp);                   // crash if fp is NULL

// BAD: socket can return -1
int sock = socket(AF_INET, SOCK_STREAM, 0);
send(sock, data, len, 0);                  // -1 used as socket handle
```

### Safe

```c
// GOOD: check fopen return
FILE *fp = fopen(path, "r");
if (!fp) {
    perror("fopen");
    return ERROR;
}
fread(buf, 1, size, fp);

// GOOD: check socket return
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) {
    perror("socket");
    return ERROR;
}
```

## Pattern 3: snprintf Return Not Checked

### Vulnerable

```c
// BAD: truncated output not detected
char buf[256];
snprintf(buf, sizeof(buf), "prefix_%s_%d", name, id);
// buf may be incomplete — used downstream as authoritative
process_config(buf);
```

### Safe

```c
// GOOD: check if output was truncated
char buf[256];
int n = snprintf(buf, sizeof(buf), "prefix_%s_%d", name, id);
if (n < 0) return ERROR;                  // encoding error
if ((size_t)n >= sizeof(buf)) {           // truncated
    return ENOSPC;
}

// GOOD: also acceptable pattern when result is discarded
if (n >= sizeof(buf)) {
    return ENOSPC;
}
```

## Pattern 4: fgets/fread/fwrite Return Not Checked

### Vulnerable

```c
// BAD: fgets can return NULL (EOF/error), buf may be stale
char line[1024];
fgets(line, sizeof(line), fp);
printf("%s", line);                        // prints stale/garbage if fgets failed

// BAD: fread partial read not detected
char data[4096];
fread(data, 1, sizeof(data), fp);          // may read less than 4096 bytes
process(data);                              // processes uninitialized data

// BAD: fwrite partial write not detected
fwrite(data, 1, len, fp);                  // may write less than len bytes
// file is now incomplete, but caller assumes full write
```

### Safe

```c
// GOOD: fgets checked
char line[1024];
if (!fgets(line, sizeof(line), fp)) {
    clearerr(fp);
    return ERROR;                          // or handle EOF gracefully
}

// GOOD: fread checked
size_t nread = fread(data, 1, sizeof(data), fp);
if (nread < sizeof(data)) {
    if (ferror(fp)) return ERROR;
    // partial read is OK — only process nread bytes
}
process_n(data, nread);

// GOOD: fwrite checked
size_t written = fwrite(data, 1, len, fp);
if (written < len) {
    return ERROR;                          // partial write — caller can retry
}
```

## Pattern 5: read/write Return Not Checked

### Vulnerable

```c
// BAD: read can return -1 or partial — no check
char buf[1024];
read(fd, buf, sizeof(buf));
process(buf);                // partially filled or error state

// BAD: write short write not handled
write(fd, data, datalen);    // may write fewer bytes than requested
```

### Safe

```c
// GOOD: read return checked
ssize_t n = read(fd, buf, sizeof(buf));
if (n < 0) return ERROR;
process(buf, (size_t)n);     // only process bytes actually read

// GOOD: write return with short-write handling
ssize_t remaining = (ssize_t)datalen;
char *p = data;
while (remaining > 0) {
    ssize_t n = write(fd, p, (size_t)remaining);
    if (n < 0) return ERROR;
    remaining -= n;
    p += n;
}
```

## Pattern 6: setenv Return Not Checked

### Vulnerable

```c
// BAD: environment table may be full (returns -1)
setenv("PATH", new_path, 1);
// assumption that env var is now set — may be false
```

### Safe

```c
// GOOD: check return
if (setenv("PATH", new_path, 1) < 0) {
    perror("setenv");
    return ERROR;
}
```
