> **定位**: 定义哪些看似 use-after-free 的场景实际是合法的内存管理模式 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 释放后使用例外规则

## 安全模式（不报告）

1. **置 NULL 后使用**: `free(p); p = NULL;` → 之后对 p 的任何操作不影响实际内存
2. **重新分配**: `free(p); p = malloc(n); p->field = x;` → 安全
3. **提前 return**: `free(p); return;` → 无后续使用路径
4. **引用计数保护**: `if (--refcount == 0) { free(p); }` → 其他使用者仍合法
5. **智能指针**: `std::unique_ptr` / `std::shared_ptr` 管理的指针不适用

## 高级安全模式

### 1. NULL-after-free 惯用法

```c
// 安全：free 后立即置 NULL，后续访问可被检测
void safe_cleanup(resource_t *r) {
    free(r->data);
    r->data = NULL;  // 防止悬挂指针
    // 后续代码可通过 if(r->data) 安全地检查
}

void caller() {
    resource_t r = {.data = malloc(128)};
    safe_cleanup(&r);
    if (r.data) {  // 安全：r.data 为 NULL
        r.data->field = 1;  // 不可达
    }
}
```

### 2. realloc 成功路径

```c
// 安全：realloc 成功后旧指针隐式释放，新指针有效
void *resize_buffer(void *buf, size_t old_sz, size_t new_sz) {
    void *tmp = realloc(buf, new_sz);
    if (!tmp) {
        // 失败：buf 仍有效，旧数据未丢失
        return buf;
    }
    // 成功：tmp 是新地址，buf 已隐式释放
    // 后续使用 tmp 是安全的
    return tmp;
}
```

### 3. 内存池/竞技场分配器

```c
// 安全：arena 分配器的生命周期管理不同于 free
typedef struct {
    char *base;
    char *current;
    size_t remaining;
} arena_t;

void *arena_alloc(arena_t *a, size_t n) {
    if (n > a->remaining) return NULL;
    void *p = a->current;
    a->current += n;
    a->remaining -= n;
    return p;
}

// arena 释放是一次性的，不存在单个对象 UAF
void arena_reset(arena_t *a) {
    a->current = a->base;
    a->remaining = a->base ? (a->current - a->base + a->remaining) : 0;
    // 重置后旧指针悬空，但通常 arena 用户理解此语义
}
```

### 4. 垃圾收集器/引用计数环境

```c
// 安全：引用计数保护的释放
typedef struct {
    int refcount;
    void *data;
} gc_obj_t;

void gc_release(gc_obj_t *obj) {
    if (--obj->refcount == 0) {
        free(obj->data);
        free(obj);
    }
}

void user(gc_obj_t *obj) {
    gc_obj_t *ref = obj;
    ref->refcount++;  // 增加引用
    gc_release(obj);  // 仅减少计数，可能不释放
    ref->data;  // 安全：ref 持有一个引用
    gc_release(ref);  // 最终释放
}
```

## 边界情况

1. 释放后仅指针地址比较（不访问内容）: `if (p == other_ptr)` → 这是合法的，不访问已释放内存
2. 释放后指针传递给 `free()`: `free(p); free(p);` → 这是 double-free 而非 UAF，转 double_free skill
3. 释放后 sizeof 操作: `free(p); size_t s = sizeof(*p);` → sizeof 是编译期操作，不实际解引用
4. **内存池 guard page**: 自定义分配器使用 mprotect 保护已释放页面 → 释放后访问触发 SIGSEGV，但分配器内部合理使用则安全
5. **栈对象误判**: 指向栈的指针被 `free()` 调用 → 这是非法释放而非 UAF，但仍需报告

## CWE 映射

| CWE | 说明 | 本规则覆盖 |
|-----|------|-----------|
| CWE-416 | Use After Free | 核心覆盖 |
| CWE-415 | Double Free | 关联（转 double_free skill） |
| CWE-825 | Expired Pointer Dereference | 悬挂指针解引用 |

## SEI CERT C 参考

- **MEM30-C**: Do not access freed memory — 本规则的核心
- **MEM01-C**: Store a new value in pointers immediately after free() — NULL-after-free 防御
- **MEM50-CPP**: Do not access freed memory (C++)
