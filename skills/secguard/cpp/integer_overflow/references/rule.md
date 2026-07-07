# Integer Overflow — Vulnerable vs Safe Patterns

## Pattern 1: Allocation-Size Multiplication (malloc)

### Vulnerable

```c
// BAD: count * sizeof(T) can overflow — returns small buffer for large count
item_t *arr = malloc(count * sizeof(item_t));

// BAD: width * height can wrap to tiny allocation
pixels = malloc(width * height * 3);

// BAD: n + 1 can wrap (n == SIZE_MAX)
char *copy = malloc(n + 1);
```

### Safe

```c
// GOOD: overflow check before multiplication
if (count > SIZE_MAX / sizeof(item_t)) return ERR_OVERFLOW;
item_t *arr = malloc(count * sizeof(item_t));

// GOOD: use built-in checked multiplication (GCC/Clang)
size_t total;
if (__builtin_mul_overflow(count, sizeof(item_t), &total)) return ERR_OVERFLOW;
item_t *arr = malloc(total);

// GOOD: reallocarray handles overflow safely (OpenBSD, glibc >= 2.26)
item_t *arr = reallocarray(NULL, count, sizeof(item_t));

// GOOD: C23 ckd_mul checked arithmetic
size_t total;
if (ckd_mul(&total, count, sizeof(item_t))) return ERR_OVERFLOW;
item_t *arr = malloc(total);

// GOOD: compile-time constants don't overflow
buf = malloc(256 * sizeof(int)); // both operands are constants
```

## Pattern 2: Addition in Boundary Check

### Vulnerable

```c
// BAD: offset + len can wrap — check passes, but subsequent memcpy reads out-of-bounds
if (offset + len > buf_size) return;      // wrap: offset + len < buf_size
memcpy(buf + offset, src, len);           // bypassed!

// BAD: idx + 1 overflow in loop guard
for (size_t i = len; i > 0; i--) {
    buf[i - 1] = data;                    // i = 0 wraps to SIZE_MAX on decrement
}
```

### Safe

```c
// GOOD: check before addition
if (len > buf_size - offset) return;
memcpy(buf + offset, src, len);

// GOOD: subtract instead of add to avoid overflow
if (offset >= buf_size || len > buf_size - offset) return;

// GOOD: use __builtin_add_overflow for checked addition
size_t end;
if (__builtin_add_overflow(offset, len, &end)) return;
```

## Pattern 3: Signed-to-Unsigned Cast

### Vulnerable

```c
// BAD: negative n becomes huge size_t — memcpy reads out-of-bounds
int n = get_user_input();            // attacker supplies -1
memcpy(dst, src, (size_t)n);         // size_t(-1) = 18446744073709551615

// BAD: signed overflow is undefined behavior — compiler can optimize check away
int offset = compute_offset();
if (offset + size > MAX) return;     // if offset = INT_MAX, INT_MAX+1 is UB
```

### Safe

```c
// GOOD: validate signed value before casting
int n = get_user_input();
if (n < 0) return ERROR;
if ((size_t)n > buf_size) return ERROR;
memcpy(dst, src, (size_t)n);

// GOOD: use size_t from the start
size_t n = (size_t)get_unsigned_input();
if (n > buf_size) return ERROR;
```

## Pattern 4: Subtraction Underflow

### Vulnerable

```c
// BAD: if data_len <= header_len, (data_len - header_len) wraps
if (data_len - header_len > MAX_PAYLOAD) return;   // underflow!
process(data, data_len - header_len);

// BAD: size_t subtraction before check
char *body = payload + header_len;
size_t body_len = total_len - header_len;           // underflow if total < header
```

### Safe

```c
// GOOD: check before subtraction
if (data_len < header_len) return;
if (data_len - header_len > MAX_PAYLOAD) return;

// GOOD: use defensive comparison
if (data_len <= header_len) return;
size_t body_len = data_len - header_len;
```

## Pattern 5: Integer Shifting

### Vulnerable

```c
// BAD: large shift can overflow or be undefined
size_t size = 1 << shift;                    // shift >= 64 on 64-bit = UB
bitmap = calloc(1, size);

// BAD: left shift of signed type is UB for sign-changing values
int flags = 1 << 31;                         // INT_MIN is implementation-defined
```

### Safe

```c
// GOOD: check shift amount and use unsigned type
if (shift >= sizeof(size_t) * CHAR_BIT) return ERROR;
size_t size = (size_t)1 << shift;
