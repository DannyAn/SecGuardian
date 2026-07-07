# 空指针解引用规则定义 (Null Dereference Rule Definitions)

## 概述

动态内存分配函数（malloc、calloc、realloc）在内存不足时返回 NULL。C 标准未规定解引用 NULL 指针的行为，实际表现为段错误（SIGSEGV）。在嵌入式或低内存环境中，这可能导致拒绝服务或安全绕过。

## 核心规则

**规则**: 每个 malloc/calloc/realloc 调用点之后，在使用其返回值之前，必须至少有一个可达的 NULL 检查路径。

## 漏洞模式

### 模式 1: 完全无检查

```c
// VULNERABLE: 无 NULL 检查
char *buf = (char*)malloc(1024);
buf[0] = 'a';       // 若 malloc 返回 NULL，此处崩溃
read(fd, buf, 100);

// SAFE
char *buf = (char*)malloc(1024);
if (buf == NULL) {
    return -1;
}
buf[0] = 'a';
```

### 模式 2: 延迟检查

```c
// VULNERABLE: 检查在解引用之后
char *buf = (char*)malloc(1024);
buf[0] = 'a';       // 崩溃先于检查
if (buf == NULL) {
    return -1;
}

// SAFE
char *buf = (char*)malloc(1024);
if (buf == NULL) {
    return -1;
}
buf[0] = 'a';
```

### 模式 3: realloc 丢失原指针

```c
// VULNERABLE: realloc 返回 NULL 时原指针丢失且内存泄漏
ptr = (int*)realloc(ptr, new_size * sizeof(int));
ptr[0] = 42;  // realloc 失败 → 崩溃

// SAFE
int *tmp = (int*)realloc(ptr, new_size * sizeof(int));
if (tmp == NULL) {
    free(ptr);
    return -1;
}
ptr = tmp;
ptr[0] = 42;
```

### 模式 4: calloc 乘法溢出

```c
// VULNERABLE: n * sizeof(T) 可能溢出
struct Large *arr = (struct Large*)calloc(n, sizeof(struct Large));
if (arr == NULL) return -1;
arr[n-1].value = 42;  // 若 calloc 因溢出返回小内存，arr[n-1] 越界

// SAFE: 检查乘法是否溢出 + NULL 检查
if (n > SIZE_MAX / sizeof(struct Large)) return -1;
struct Large *arr = (struct Large*)calloc(n, sizeof(struct Large));
if (arr == NULL) return -1;
```

### 模式 5: 条件编译下的分配

```c
// VULNERABLE
#ifdef DEBUG
    char *buf = (char*)malloc(1024);
#endif
    buf[0] = 'a';  // DEBUG 未定义时 buf 未声明

// SAFE
#ifdef DEBUG
    char *buf = (char*)malloc(1024);
    if (buf == NULL) return -1;
    buf[0] = 'a';
#endif
```

## 已知安全模式

```c
// SAFE: xmalloc 封装（abort on OOM）
static inline void *xmalloc(size_t n) {
    void *p = malloc(n);
    if (p == NULL) abort();
    return p;
}
void *p = xmalloc(1024);  // 永远非 NULL
p[0] = 'a';               // 安全

// SAFE: calloc + assert
void *p = calloc(n, size);
assert(p != NULL);
p[0] = 'a';               // debug 模式下安全

// SAFE: return on NULL + else 块
p = malloc(n);
if (p == NULL) return -1;
p[0] = 'a';               // 安全
```
