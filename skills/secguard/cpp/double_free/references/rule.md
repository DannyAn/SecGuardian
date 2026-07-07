# 双重释放规则定义 (Double Free Rule Definitions)

## 概述

CWE-415: 同一动态分配的内存被释放两次。double-free 可导致堆损坏，攻击者可利用此漏洞实现任意代码执行（堆风水攻击）。

## 核心规则

**规则**: 对每个 free(ptr) 调用点，从该点到函数返回之间的所有可达路径上，不能存在对同一指针的第二次 free()，除非指针在两次 free 之间被重新赋值或置 NULL。

## 漏洞模式

### 模式 1: 简单连续释放

```c
// DOUBLE-FREE: 连续两次释放
void cleanup(struct Data *d) {
    free(d->buffer);
    free(d->buffer);   // 第二次释放同一指针
}

// SAFE
void cleanup(struct Data *d) {
    free(d->buffer);
    d->buffer = NULL;   // 置 NULL 防止二次释放
}
```

### 模式 2: 错误处理路径泄漏 + 后续释放

```c
// DOUBLE-FREE: 条件路径中释放后未置 NULL
int process(struct Data *d) {
    if (d->flag) {
        free(d->buf);
        return -1;       // 释放，但未置 NULL
    }
    // ...
    free(d->buf);        // d->flag 为真时 → double-free
    return 0;
}

// SAFE
int process(struct Data *d) {
    if (d->flag) {
        free(d->buf);
        d->buf = NULL;   // 置 NULL
        return -1;
    }
    free(d->buf);
    return 0;
}
```

### 模式 3: 多次调用清理函数

```c
// DOUBLE-FREE: 清理函数可被多次调用
void free_data(struct Data *d) {
    free(d->ptr);
}

void process() {
    struct Data d = {.ptr = malloc(100)};
    free_data(&d);
    free_data(&d);   // 第二次调用 → double-free
}

// SAFE: 清理后置 NULL
void free_data(struct Data *d) {
    free(d->ptr);
    d->ptr = NULL;
}
```

### 模式 4: 错误标签（goto cleanup 双重命中）

```c
// DOUBLE-FREE: 清理标签被多处 goto
int init() {
    char *buf = malloc(1024);
    if (step1() < 0) goto cleanup;
    if (step2() < 0) {
        free(buf);      // 手动释放
        return -1;      // 正确跳过了 goto cleanup
    }
    return 0;
cleanup:
    free(buf);          // step1 失败时单次释放（安全）
    return -1;
}

// DOUBLE-FREE: 更隐蔽的 goto 重叠
int init() {
    char *buf = malloc(1024);
    if (step1() < 0) goto cleanup;
    free(buf);          // step1 成功时先释放
    return 0;
cleanup:
    free(buf);          // step1 失败时 → 单次释放；step1 成功时不执行此处 → 安全
    return -1;
}

// 实际上在以上场景中，由于 return 0 不经过 cleanup，实际是安全的。
// 检查时需要确认 goto cleanup 和执行 free(buf) 后是否 return，避免干净路径再经过 cleanup。
```

### 模式 5: 双重释放 + 别名

```c
// DOUBLE-FREE: 指针别名
char *alias = buf;
free(buf);
free(alias);   // 别名指向同一内存 → double-free

// DOUBLE-FREE: 结构体嵌套
free(d->inner);
free(d);       // 取决于结构体设计，如果 free(d) 内部也释放 d->inner 则 double-free
```

## 已知安全模式

```c
// SAFE: 置 NULL 后 free
free(p);
p = NULL;
free(p);           // free(NULL) 安全

// SAFE: 互斥分支
if (mode == A) {
    free(p);
} else {
    // p 在 mode A 路径被释放，mode B 路径不释放
}

// SAFE: 重新分配
free(p);
p = malloc(512);
free(p);           // 释放新分配，非双重释放
```
