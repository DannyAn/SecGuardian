/**
 * memory_extra.c — Additional memory vulnerability examples
 *
 * VULNERABILITIES:
 *   - CWE-122: Heap buffer overflow (line 20)
 *   - CWE-457: Uninitialized memory (line 40)
 *   - CWE-401: Memory leak (line 58)
 *   - CWE-762: Mismatched free (line 78)
 *   - CWE-193: Off-by-one error (line 97)
 *   - CWE-704: Bad type cast (line 113)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ── CWE-122: Heap Buffer Overflow ────────────────────────── */
void heap_overflow_example(int user_len) {
    // VULNERABILITY [CWE-122]: Heap buffer overflow
    // User-controlled size leads to insufficient allocation
    char *buf = (char *)malloc(user_len);  // Allocate N bytes
    if (!buf) return;

    // BAD: copies user_len+10 bytes into N-byte buffer
    for (int i = 0; i < user_len + 10; i++) {
        buf[i] = 'A';  // OVERFLOW: writes past allocated region
    }
    free(buf);
}

/* ── CWE-457: Uninitialized Memory ────────────────────────── */
int process_flag() {
    int flag;  // VULNERABILITY [CWE-457]: Uninitialized automatic variable
    // flag is never assigned before use
    if (flag == 1) {  // BAD: flag has indeterminate value
        return 1;
    }
    return 0;
}

typedef struct {
    int id;
    char *name;
} Record;

Record *create_record() {
    Record *r = (Record *)malloc(sizeof(Record));
    // VULNERABILITY [CWE-457]: r->id and r->name uninitialized
    // malloc does NOT zero memory — calloc would be safe
    return r;  // BAD: returned with uninitialized fields
}

/* ── CWE-401: Memory Leak ─────────────────────────────────── */
void leak_in_path(int flag) {
    char *buf = (char *)malloc(1024);
    if (!buf) return;

    if (flag) {
        // VULNERABILITY [CWE-401]: Memory leak on early return
        // buf is not freed before returning
        return;  // LEAK: allocated memory lost
    }

    free(buf);
}

void *allocate_and_forget() {
    char *buf = (char *)malloc(256);
    strcpy(buf, "temporary");
    // VULNERABILITY [CWE-401]: Returned pointer stored but never freed by caller
    // No tracking mechanism, memory leaks silently
    return buf;
}

/* ── CWE-762: Mismatched Free ─────────────────────────────── */
void mismatched_free_example() {
    // VULNERABILITY [CWE-762]: malloc + operator delete (C++)
    // Using free() on memory allocated with C++ new, or delete on malloc
    char *buf = (char *)malloc(64);
    strcpy(buf, "test");

    // BAD: malloc'd memory freed with wrong deallocator
    // In C++ this would be: delete buf;  (should be free(buf))
    // In C with strdup:
    char *dup = strdup("hello");
    free(buf);  // OK for C
    // VULNERABILITY [CWE-762]: Wrong deallocator for strdup
    // strdup uses malloc internally, so free() is correct in C.
    // But if this were C++ with new/malloc mixed:
    // int *p = new int; free(p);  // C++: new + free = UB
    printf("Buffer freed (mismatch depends on language context)\n");
}

/* ── CWE-193: Off-by-One ──────────────────────────────────── */
void off_by_one_example() {
    char buf[64];

    // VULNERABILITY [CWE-193]: Off-by-one in loop
    // Array of 64 elements indexed 0..63
    for (int i = 0; i <= 64; i++) {  // BAD: should be i < 64
        buf[i] = 0;  // Last iteration writes to buf[64] (out of bounds)
    }

    // VULNERABILITY [CWE-193]: Off-by-one in string null termination
    char dest[8];
    strncpy(dest, "long string", 8);  // BAD: copies 8 chars, no null terminator
    // dest is not null-terminated — subsequent strlen reads past buffer
    int len = strlen(dest);  // UB: reads beyond array bounds
    printf("Length: %d\n", len);
}

/* ── CWE-704: Bad Cast ────────────────────────────────────── */
void bad_cast_example() {
    int value = 0x41424344;  // ABCD in ASCII

    // VULNERABILITY [CWE-704]: Cast between incompatible types
    // BAD: treating int as char pointer (strict aliasing violation)
    char *str = (char *)&value;
    printf("String: %c%c%c%c\n", str[0], str[1], str[2], str[3]);  // UB

    // VULNERABILITY [CWE-704]: Truncation via narrowing cast
    long large_value = 0x100000001L;
    int truncated = (int)large_value;  // BAD: truncation on 64-bit systems
    printf("Truncated: %d (original: %ld)\n", truncated, large_value);
}

/* ── Main ─────────────────────────────────────────────────── */
int main() {
    printf("Additional memory vulnerability demo\n");
    heap_overflow_example(16);
    process_flag();
    create_record();
    leak_in_path(1);
    off_by_one_example();
    bad_cast_example();
    return 0;
}
