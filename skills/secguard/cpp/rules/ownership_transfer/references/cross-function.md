> **定位**: 所有权跨函数边界转移时的追踪规则与常见模式 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 所有权转移跨函数追踪

## 规则

当指针所有权转移通过函数参数或返回值跨函数传递时，追踪目标函数内部的行为。

### 最大深度: 1 层

```c
void *acquire() {
    return malloc(100);
}

void use() {
    void *p = acquire();
    free(p);
    // p 后续是否被使用？
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 返回值所有权转移

### 1. 工厂函数返回（调用者接管所有权）

```c
// 追踪：返回值所有权转移给调用者
char *create_buffer(size_t n) {
    return malloc(n);  // 所有权从 create_buffer 转移给调用者
}

void user() {
    char *buf = create_buffer(1024);  // user() 现在拥有 buf
    // buf 由 user() 负责释放
    free(buf);
}
```

### 2. 借用返回（不转移所有权 — 安全）

```c
// 安全：返回内部指针不转移所有权
const char *get_error_message(int code) {
    // 返回静态字符串/内部缓冲区指针
    return error_table[code];  // 所有权不转移
}

void handler() {
    const char *msg = get_error_message(404);
    // 不应 free(msg) — 返回的是借用引用
}
```

## 输出参数所有权转移

### 1. 输出参数分配（调用者接管所有权）

```c
// 追踪：out 参数接收新分配的内存
int allocate_buffer(char **out, size_t size) {
    *out = malloc(size);  // 所有权转移到 *out（调用者的变量）
    return *out ? 0 : -1;
}

void user() {
    char *buf = NULL;
    if (allocate_buffer(&buf, 1024) == 0) {
        // buf 现在拥有分配的内存
        use(buf);
        free(buf);  // 调用者负责释放
    }
}
```

### 2. 双重输出参数

```c
// 追踪：多个输出参数同时接收所有权
int create_pair(resource_t **a, resource_t **b) {
    *a = malloc(sizeof(resource_t));
    *b = malloc(sizeof(resource_t));
    if (!*a || !*b) {
        free(*a);  // 部分失败时清理
        free(*b);
        return -1;
    }
    return 0;  // 两个所有权都转移给调用者
}
```

## 回调所有权转移

### 1. 回调参数传递所有权

```c
// 追踪：alloc 回调的结果所有权
typedef void *(*alloc_fn)(size_t);

void process(size_t n, alloc_fn alloc, void (*free_fn)(void *)) {
    void *buf = alloc(n);
    // buf 所有权在 process 内部
    free_fn(buf);
    // 所有权结束
}

// 调用
process(1024, malloc, free);  // 所有权在 process 内部闭合
```

### 2. 回调接收所有权（不转移回调用者）

```c
// 追踪：item 的所有权转移给 list
void list_process(list_t *l, void (*item_handler)(void *)) {
    for (int i = 0; i < l->count; i++) {
        item_handler(l->items[i]);  // 所有权不转移（仅访问）
    }
}
```

## 常见模式

1. **工厂函数返回分配**: 调用者需注意释放责任
2. **容器接管**: list_append(list, item) 后 list 负责 item 生命周期
3. **realloc 返回值**: realloc 可能返回新地址，旧地址已释放
4. **跨模块释放**: 模块 A 分配、模块 B 释放 → 确保使用相同分配器
5. **返回 unique_ptr**: `std::unique_ptr<T> create()` → 编译期保证所有权转移安全
6. **移动构造函数**: `T(T&& other)` → 所有权从 other 转移到新对象

## SEI CERT C 参考

- **MEM30-C**: Do not access freed memory
- **MEM31-C**: Free dynamically allocated memory when no longer needed
- **MEM34-C**: Only free memory allocated dynamically
- **MEM35-C**: Allocate sufficient memory for an object
