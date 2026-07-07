# Ownership Transfer — Vulnerable vs Safe Patterns

## Pattern 1: realloc Old Pointer Misuse

### Vulnerable

```c
// BAD: realloc frees old ptr internally — then caller frees it again
char *old = malloc(100);
char *newbuf = realloc(old, 200);
if (!newbuf) return;
free(old);                               // DOUBLE FREE: realloc already freed old

// BAD: realloc may move memory — old ptr is dangling
char *old = malloc(100);
char *newbuf = realloc(old, 200);
if (!newbuf) return;
old[0] = 'a';                            // USE-AFTER-FREE: old may be invalid
memcpy(old, data, 10);                    // USE-AFTER-FREE: writing to freed memory
```

### Safe

```c
// GOOD: only use the return pointer
char *p = realloc(p, 200);               // safe: p gets the new pointer
if (!p) return;                          // but OLD pointer is lost if realloc fails!

// GOOD: temp variable for realloc
char *newbuf = realloc(ptr, 200);
if (!newbuf) return;                     // ptr is still valid
ptr = newbuf;

// GOOD: never touch old after successful realloc
char *expanded = (char *)realloc(base, new_size);
if (!expanded) return;
// DO NOT reference old variables anymore
```

## Pattern 2: Free Then Use (Same Function)

### Vulnerable

```c
// BAD: classic use-after-free
free(ptr);
ptr->field = 1;                          // UAF: ptr freed

// BAD: read after free
free(conf);
printf("%s", conf->name);                 // UAF: conf freed

// BAD: pass to another function after free
free(item);
persist(item);                            // UAF: item freed, persists freed pointer
```

### Safe

```c
// GOOD: nullify after free
free(ptr);
ptr = NULL;

// GOOD: return after free
free(tmp);
return;

// GOOD: ptr reassigned before use
free(old);
old = malloc(100);
old->field = 1;                           // safe: old points to new allocation
```

## Pattern 3: Alias-Based UAF

### Vulnerable

```c
// BAD: p2 is an alias of p1 — both become dangling
char *p1 = malloc(100);
char *p2 = p1;
free(p1);
strcpy(p2, "data");                       // UAF: p2 points to freed p1 memory

// BAD: pointer arithmetic alias
char *base = malloc(256);
char *mid = base + 128;
free(base);
mid[0] = 'x';                             // UAF: mid was within freed region
```

### Safe

```c
// GOOD: nullify all aliases (impractical — better to restructure)
char *p1 = malloc(100);
char *p2 = p1;
free(p1);
p1 = NULL;
p2 = NULL;                                // both nullified

// GOOD: avoid aliases in the first place
// Use unique_ptr or unique ownership semantics
```

## Pattern 4: Ownership Transfer to a Container/Data Structure

### Vulnerable

```c
// BAD: after inserting into container, caller continues using original pointer
item_t *it = malloc(sizeof(item_t));
list_append(list, it);                    // list takes ownership
it->value = 42;                           // UAF: list may free/release it
// or caller later:
it->next = NULL;                          // UAF: list already freed it

// BAD: container iterates and frees, but caller holds stale pointer
list_free_all(list);                      // frees all items
item_t *first = list->items[0];           // dangles: list freed everything
```

### Safe

```c
// GOOD: after ownership is transferred to container, use the container to access
item_t *it = malloc(sizeof(item_t));
it->value = 42;
list_append(list, it);                    // ownership transferred
it = NULL;                                // clear local copy

// BAD pattern avoided: access through container
item_t *first = list_get(list, 0);        // safe: through the container

// GOOD: make deep copy for local use
item_t *it = malloc(sizeof(item_t));
it->value = 42;
item_t *copy = malloc(sizeof(item_t));
*copy = *it;                              // deep copy
list_append(list, it);                    // list owns it
// use copy for local operations
free(copy);
```

## Pattern 5: C++ unique_ptr Ownership Transfer

### Vulnerable

```c++
// BAD: moved-from object is still accessed
auto a = std::make_unique<int>(42);
auto b = std::move(a);
*a = 43;                                  // BAD: a is nullptr after move

// BAD: raw pointer extracted but original manages lifetime
int *raw = p.get();
p.reset();                                // p frees memory
*raw = 42;                                // UAF: raw is dangling
```

### Safe

```c++
// GOOD: after move, only use the new owner
auto a = std::make_unique<int>(42);
auto b = std::move(a);
*b = 43;                                  // safe: b is the new owner

// GOOD: release takes ownership out of unique_ptr
int *raw = p.release();                   // p no longer manages
// ... use raw ...
delete raw;                               // caller is responsible
```

## Pattern 6: Function That Takes Ownership via Parameter

### Vulnerable

```c
// BAD: caller passes pointer, callee frees it, caller continues using
void take_ownership(item_t *p) {
    // ...
    free(p);                              // callee asserts ownership
}

void caller() {
    item_t *it = malloc(sizeof(item_t));
    process(it);                          // does process free it?
    // ...
    it->value = 99;                       // UAF: process freed it
}
```

### Safe

```c
// GOOD: caller needs to understand the ownership contract
// If process() says "takes ownership", caller must not use it after:
item_t *it = malloc(sizeof(item_t));
process(it);                              // ownership transferred
it = NULL;                                // clear reference

// GOOD: check function documentation / name
// Function named *_free / *_destroy / *_release usually frees the argument
destroy_item(it);                         // assumed to free
// do not use it after this point
```
