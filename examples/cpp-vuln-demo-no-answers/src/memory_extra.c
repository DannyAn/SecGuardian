/**
 * memory_extra.c — Additional memory vulnerability examples
 *







 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


void heap_overflow_example(int user_len) {

    // User-controlled size leads to insufficient allocation
    char *buf = (char *)malloc(user_len);  // Allocate N bytes
    if (!buf) return;


    for (int i = 0; i < user_len + 10; i++) {
        buf[i] = 'A';  // OVERFLOW: writes past allocated region
    }
    free(buf);
}


int process_flag() {
    int flag;
    // flag is never assigned before use
    if (flag == 1) {
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

    // malloc does NOT zero memory — calloc would be safe
    return r;
}


void leak_in_path(int flag) {
    char *buf = (char *)malloc(1024);
    if (!buf) return;

    if (flag) {

        // buf is not freed before returning
        return;  // LEAK: allocated memory lost
    }

    free(buf);
}

void *allocate_and_forget() {
    char *buf = (char *)malloc(256);
    strcpy(buf, "temporary");

    // No tracking mechanism, memory leaks silently
    return buf;
}


void mismatched_free_example() {

    // Using free() on memory allocated with C++ new, or delete on malloc
    char *buf = (char *)malloc(64);
    strcpy(buf, "test");


    // In C++ this would be: delete buf;  (should be free(buf))
    // In C with strdup:
    char *dup = strdup("hello");
    free(buf);  // OK for C

    // strdup uses malloc internally, so free() is correct in C.
    // But if this were C++ with new/malloc mixed:
    // int *p = new int; free(p);  // C++: new + free = UB
    printf("Buffer freed (mismatch depends on language context)\n");
}


void off_by_one_example() {
    char buf[64];


    // Array of 64 elements indexed 0..63
    for (int i = 0; i <= 64; i++) {
        buf[i] = 0;  // Last iteration writes to buf[64] (out of bounds)
    }


    char dest[8];
    strncpy(dest, "long string", 8);
    // dest is not null-terminated — subsequent strlen reads past buffer
    int len = strlen(dest);  // UB: reads beyond array bounds
    printf("Length: %d\n", len);
}


void bad_cast_example() {
    int value = 0x41424344;  // ABCD in ASCII



    char *str = (char *)&value;
    printf("String: %c%c%c%c\n", str[0], str[1], str[2], str[3]);  // UB


    long large_value = 0x100000001L;
    int truncated = (int)large_value;
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
