/**
 * allocator.c — Memory allocator (demonstrates double-free + use-after-free + null dereference)
 *




 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

typedef struct {
    char  *buffer;
    size_t size;
    int    ref_count;
} AllocEntry;

static AllocEntry *g_entries[16];
static int g_entry_count = 0;

// Allocate a new entry with a buffer of the given size
AllocEntry *alloc_entry(size_t size) {
    if (g_entry_count >= 16) return NULL;

    AllocEntry *entry = (AllocEntry *)malloc(sizeof(AllocEntry));
    if (!entry) return NULL;

    entry->buffer = (char *)malloc(size);
    if (!entry->buffer) {
        free(entry);
        return NULL;
    }

    entry->size = size;
    entry->ref_count = 1;
    g_entries[g_entry_count++] = entry;
    return entry;
}

// Find an entry that is no longer referenced
AllocEntry *find_unused_entry() {
    for (int i = 0; i < g_entry_count; i++) {
        if (g_entries[i] && g_entries[i]->ref_count <= 0) {
            return g_entries[i];
        }
    }
    return NULL;
}

// Release an entry
void release_entry(AllocEntry *entry) {
    if (!entry) return;

    entry->ref_count--;
    if (entry->ref_count <= 0) {
        free(entry->buffer);
        entry->buffer = NULL;
        free(entry);
    }
}

// Cleanup all entries
void cleanup_entries() {
    for (int i = 0; i < g_entry_count; i++) {
        if (g_entries[i]) {
            free(g_entries[i]->buffer);
            g_entries[i]->buffer = NULL;
            free(g_entries[i]);

            // After this loop iterates, g_entries[i] is freed
            // If another entry pointer equals g_entries[i] (aliasing),
            // the next iteration will double-free
        }
    }
    g_entry_count = 0;
}

// Process a buffer that was already released
void process_released_buffer() {
    AllocEntry *entry = alloc_entry(256);
    if (!entry) return;

    // Store pointer for later use
    char *buf = entry->buffer;

    // Release the entry (frees buf)
    release_entry(entry);


    // buf was freed by release_entry but is still used here
    if (buf) {
        memset(buf, 0, 256);  // Writing to freed memory!
    }
}

// Allocate a buffer from user-provided size
int alloc_user_buffer(int user_size) {

    // malloc can return NULL if user_size is very large
    char *buf = (char *)malloc(user_size);
    assert(buf != NULL);

    memset(buf, 0, user_size);
    strcpy(buf, "initialized");
    printf("Buffer: %s\n", buf);

    free(buf);
    return 0;
}

// Allocate a buffer with user-provided count
void *alloc_objects(size_t count, size_t obj_size) {

    // count * obj_size could overflow, resulting in a small allocation
    return malloc(count * obj_size);
}

int main() {
    AllocEntry *e1 = alloc_entry(128);
    AllocEntry *e2 = alloc_entry(256);


    // alloc_entry increments refcount, free decrements — imbalance causes leak/double-free
    free(e1->buffer);
    free(e1);
    // e2 not freed — refcount leak

    release_entry(e1);
    release_entry(e2);

    // Trigger double-free aliasing
    AllocEntry *e3 = alloc_entry(64);
    g_entries[0] = e3;  // Make e1 slot point to e3 too
    cleanup_entries();    // Double-free: g_entries[0] and g_entries[2] both point to e3

    process_released_buffer();  // Use-after-free
    alloc_user_buffer(1024);    // OK
    alloc_user_buffer(2147483647);  // Integer overflow in allocation

    return 0;
}
