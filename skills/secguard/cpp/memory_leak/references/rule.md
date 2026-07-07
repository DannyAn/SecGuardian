# 内存泄漏规则定义 (Memory Leak Rule Definitions)

## 概述

CWE-401: 分配的内存未在生命周期结束时释放。累积泄漏将导致进程内存耗尽（OOM），在长期运行的服务中尤其严重。

## 核心规则

**规则**: 对每个 malloc/calloc/realloc 分配点，分配所在函数的所有退出路径上，该内存要么被 free() 释放，要么所有权被明确转移给调用者。

## 漏洞模式

### 模式 1: 无条件不释放

```c
// LEAK: 分配后永不释放
char *process(const char *input) {
    char *copy = strdup(input);
    // transform copy...
    return copy;  // 不释放返回了 copy？看函数语义
}
```
判定: 若函数名暗示返回新分配（如 `duplicate`、`copy`、`clone`），所有权转移 → 非泄漏。若函数名为 `process`、`handle` → caller 可能不知道需释放。

### 模式 2: 异常路径泄漏

```c
// LEAK: 中间失败直接返回
char *load_file(const char *path) {
    FILE *f = fopen(path, "r");
    char *buf = malloc(4096);
    if (!f) return NULL;        // LEAK: buf 未释放
    if (fread(buf, 1, 4096, f) < 0) {
        fclose(f);
        return NULL;            // LEAK: buf 未释放
    }
    fclose(f);
    return buf;                 // 所有权转移给调用者
}

// SAFE
char *load_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return NULL;
    char *buf = malloc(4096);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, 4096, f) < 0) {
        free(buf); fclose(f);
        return NULL;
    }
    fclose(f);
    return buf;
}
```

### 模式 3: 循环中泄漏

```c
// LEAK: 每次循环分配，退出时不清理
for (int i = 0; i < n; i++) {
    char *tmp = malloc(100);
    compute(tmp, i);
    // tmp 在下次迭代时丢失引用
}

// SAFE
for (int i = 0; i < n; i++) {
    char *tmp = malloc(100);
    compute(tmp, i);
    free(tmp);
}
```

### 模式 4: 覆盖指针（pointer aliasing）

```c
// LEAK: 原指针被覆盖，无法再释放
char *buf = malloc(1024);
buf = malloc(2048);     // 原 1024 字节泄漏
free(buf);             // 仅释放第二次分配

// SAFE
char *buf = malloc(1024);
// ... use buf ...
free(buf);
buf = malloc(2048);
```

### 模式 5: realloc 失败后原指针丢失

```c
// LEAK: 使用自身 realloc，失败时原指针仍在但丢失清理机会
p = realloc(p, 2048);  // 若 realloc 返回 NULL，p=NULL 且原内存未释放

// SAFE
tmp = realloc(p, 2048);
if (tmp == NULL) {
    free(p);            // 释放原内存
    return -1;
}
p = tmp;
```

## 已知安全模式

### RAII (C++)

```c++
// SAFE: unique_ptr 自动释放
std::unique_ptr<char[]> buf(new char[1024]);

// SAFE: shared_ptr
auto buf = std::make_shared<std::vector<char>>(1024);

// SAFE: scoped_ptr / auto_ptr
boost::scoped_ptr<Foo> p(new Foo());
```

### Arena 分配（一次性释放）

```c
// SAFE: arena 在函数结束时整体释放
void *arena = malloc(ARENA_SIZE);
char *p1 = arena_alloc(arena, 100);
char *p2 = arena_alloc(arena, 200);
// 无需单独释放 p1/p2
arena_free(arena);  // 一次性释放全部
```
