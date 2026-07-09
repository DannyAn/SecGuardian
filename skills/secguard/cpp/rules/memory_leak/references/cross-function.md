# 内存泄漏跨函数追踪规则 (Cross-Function Tracing)

## 原则

最大追踪深度 1 层。分配与释放分处不同函数时跨函数追踪。

## 场景 1: 分配在某函数，释放在其调用者

```c
// 检视点: load_config 分配了 buf
char *load_config(const char *path) {
    char *buf = malloc(4096);
    if (read_file(path, buf, 4096) < 0) {
        return NULL;     // LEAK: buf 未释放
    }
    return buf;          // 所有权转移
}

// 调用者
void start() {
    char *cfg = load_config("/etc/app.conf");
    // 使用 cfg...
    free(cfg);           // 正确释放
}
```

**追踪规则**:
1. 检测到 `load_config` 中 malloc → 检查所有 return 路径
2. 发现 `return buf` 路径 → 所有权转移
3. 查调用图中 `load_config` 的调用者
4. 检查调用者是否在适当时候 `free(cfg)` → 是则豁免
5. 检查调用者是否在所有退出路径上都 free → 完整豁免

## 场景 2: 延迟释放

```c
void handler() {
    char *data = prepare_data();
    // data 内存分配在 prepare_data 内
    process(data);
    // 是否释放了 data?
}

char *prepare_data() {
    return malloc(1024);  // 所有权转移
}

void process(char *data) {
    // 使用 data...
    // process 不负责释放
}
```

**追踪规则**:
1. `prepare_data` 返回 malloc → 所有权在 caller
2. 在 `handler` 中，`process(data)` 后是否有 free？
3. 若无 → handler 末尾是否隐含（如局部变量被作用域释放）？
4. 均无 → 泄漏

## 场景 3: 释放后被调用者持有

```c
void register_callback() {
    struct Event *ev = malloc(sizeof(*ev));
    ev->type = EV_KEY;
    add_event_listener(ev);  // 事件系统接管所有权
    // 这里不 free(ev) → 正确
}
```

**追踪规则**:
1. `add_event_listener` 接受 `struct Event *`
2. 查 `add_event_listener` 定义：是否存储了指针
3. 若存储 → 所有权转移，非泄漏
4. 无法确认 → 标记为 low 级别「疑似转移但不可确认」

## 场景 4: 结构体内指针泄漏

```c
struct Request {
    char *body;
    int len;
};

struct Request *parse_request(const char *raw) {
    struct Request *req = malloc(sizeof(*req));
    req->body = malloc(1024);   // ← 内层分配
    copy_body(req->body, raw);
    return req;                  // 外层所有权转移
}
```

**追踪规则**:
1. 检测到 `req->body = malloc(1024)`
2. 检查 `parse_request` 的退出路径（仅 `return req`）
3. 内层 `req->body` 的释放责任转移到被调用的释放函数
4. 需要调用者调用类似 `free_request(req)` 来释放内部成员
5. 无配套释放函数 → 难以静态判定，标记为 suspicious

## 不可追踪情况

1. **函数指针回调**: `void (*free_fn)(void*)` 无法追踪
2. **跨线程传递**: malloc 在一个线程，free 在另一线程 → 运行时不确定性
3. **外部库**: `lib_init()` 在内部 malloc，`lib_cleanup()` 释放 → 非本代码库
