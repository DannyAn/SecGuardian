> **定位**: use-after-free 跨函数边界的追踪规则与常见漏洞模式 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 释放后使用跨函数追踪

## 规则

当 free 在函数 A 中完成，但指针解引用在函数 B 中、且 A 调用 B 时：

### 最大深度: 1 层

```c
void A() {
    free(p);
    B(p);  // B 接收已释放指针
}

void B(void *ptr) {
    ptr->field = 1;  // UAF
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 跨函数 UAF 核心模式

### 1. 调用者释放、被调用者使用（Caller Frees, Callee Uses）

```c
// 报告：A 释放后调用 B，B 使用已释放指针
void A(resource_t *r) {
    free(r);
    process_completion(r);  // 传递已释放指针 → UAF
}

void process_completion(resource_t *r) {
    log_event(r->name);  // UAF: r 已被 A 释放
}
```

### 2. 被调用者释放、调用者继续使用（Callee Frees, Caller Uses）

```c
// 报告：cleanup() 释放了 data，调用者继续使用
void cleanup(resource_t *r) {
    free(r->data);
    r->data = NULL;  // 防御：但仅当调用者检查 r->data 时才安全
}

void caller() {
    resource_t *r = create_resource();
    // ... 使用 r->data ...
    cleanup(r);
    process(r->data);  // 如果 cleanup 未置 NULL 或调用者未检查 → UAF
}
```

### 3. 回调中的 UAF

```c
// 报告：回调上下文在回调前被释放
typedef void (*callback_fn)(void *ctx);

void schedule_callback(callback_fn cb, void *ctx) {
    // 存储回调到队列
    event_queue_push(cb, ctx);
}

void buggy_cleanup(context_t *ctx) {
    free(ctx);  // 释放上下文
    dispatch_pending_events();  // 触发回调
    // 如果回调中使用了 ctx → UAF
}

void on_event(void *ctx) {
    context_t *c = (context_t *)ctx;
    c->status = READY;  // UAF: ctx 已在 buggy_cleanup 中被释放
}
```

### 4. 信号处理器中的 UAF

```c
// 报告：信号处理器访问可能已释放的全局指针
static volatile context_t *g_ctx = NULL;

void sigusr1_handler(int sig) {
    if (g_ctx) {
        g_ctx->signal_count++;  // UAF: g_ctx 可能在主线程中被释放
        // 信号处理器与主线程并发，无法同步
    }
}

void main_cleanup(void) {
    free((void *)g_ctx);  // 释放
    g_ctx = NULL;  // 但信号可能在 free 后、NULL 前到达
    // 正确做法：先屏蔽信号，再释放
}
```

### 5. 事件循环 UAF

```c
// 报告：事件已释放但仍在事件队列中
typedef struct {
    int type;
    void *data;
} event_t;

void event_loop_process(event_t *ev) {
    dispatch_handler(ev);
    free(ev->data);
    free(ev);  // 事件释放
}

// 如果 dispatch_handler 重新将 ev 放入队列 → UAF
void dispatch_handler(event_t *ev) {
    if (ev->type == RETRY) {
        event_queue_push(ev);  // ev 将被释放但仍在队列中
    }
    free(ev->data);  // 双重释放
}
```

## 跨函数 UAF 检测信号

| 模式 | 信号 | 置信度 |
|------|------|--------|
| free(A); B(A); 链中 B 解引用 A | free 和 deref 跨函数边界 | 高 |
| 回调注册后释放上下文 | 回调函数签名含 void *ctx | 中 |
| 信号处理器访问全局指针 | 全局指针 + free 在另一函数 | 中（需确认信号屏蔽） |
| 事件队列中的悬挂指针 | free 后仍能从队列索引访问 | 高 |
| 容器/列表中的悬挂节点 | 节点 free 后仍通过 prev/next 遍历 | 高 |

## 常见跨函数 UAF 模式（已有）

1. **回调函数**: 释放后注册的回调被调用，使用已释放上下文
2. **事件循环**: free(event) 后事件处理中的 event->data 解引用
3. **函数指针表**: 释放后函数表项仍可被调度调用

## CWE 参考

- **CWE-416**: Use After Free — 核心覆盖
- **CWE-825**: Expired Pointer Dereference — 跨函数传递悬挂指针
- **CWE-364**: Signal Handler Race Condition — 信号处理器竞态 UAF

## SEI CERT C 参考

- **SIG31-C**: Do not access shared objects in signal handlers — 信号处理器中避免访问共享数据
- **MEM30-C**: Do not access freed memory — 跨函数边界同样适用
- **MEM01-C**: Store a new value in pointers immediately after free() — 跨函数传递前确保 NULL
