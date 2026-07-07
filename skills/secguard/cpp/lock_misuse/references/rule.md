# 锁误用 — 脆弱模式与安全模式

## 模式 1: 未匹配的 lock/unlock

**脆弱模式** — 退出路径缺 unlock:

```c
void process(struct shared_data *d) {
    pthread_mutex_lock(&d->mtx);
    if (d->state == INVALID) {
        return -1;  // BUG: unlock 被跳过
    }
    d->counter++;
    pthread_mutex_unlock(&d->mtx);
    return 0;
}
```

**安全模式**:

```c
void process(struct shared_data *d) {
    pthread_mutex_lock(&d->mtx);
    int ret = 0;
    if (d->state == INVALID) {
        ret = -1;
        goto cleanup;   // 统一退出路径
    }
    d->counter++;
cleanup:
    pthread_mutex_unlock(&d->mtx);
    return ret;
}
```

**或使用作用域锁 (C++17)**:

```cpp
void process(struct shared_data &d) {
    std::lock_guard<std::mutex> lk(d.mtx);
    if (d.state == INVALID) return -1;  // 析构时自动 unlock
    d.counter++;
    return 0;
}
```

## 模式 2: double-lock

**脆弱模式**:

```c
void update(struct shared_data *d) {
    pthread_mutex_lock(&d->mtx);
    d->value_a++;
    pthread_mutex_lock(&d->mtx);  // BUG: 再次锁定同一 mutex → 死锁 (self-deadlock)
    d->value_b++;
    pthread_mutex_unlock(&d->mtx);
    pthread_mutex_unlock(&d->mtx);
}
```

## 模式 3: unlock without prior lock

**脆弱模式**:

```c
void early_exit_error(struct shared_data *d) {
    if (d == NULL) {
        pthread_mutex_unlock(&d->mtx);  // BUG: 从未锁定就释放
        return;
    }
    pthread_mutex_lock(&d->mtx);
    // ...
    pthread_mutex_unlock(&d->mtx);
}
```

## 模式 4: 信号处理器中的 lock

**脆弱模式** — 信号处理器调用 lock:

```c
pthread_mutex_t global_mtx = PTHREAD_MUTEX_INITIALIZER;

void sigint_handler(int sig) {
    pthread_mutex_lock(&global_mtx);  // BUG: 若信号发生在持有锁的线程中 → 死锁
    write_log("received SIGINT");
    pthread_mutex_unlock(&global_mtx);
}
```

**安全模式**:

```c
// 使用 self-pipe trick 或 volatile sig_atomic_t
volatile sig_atomic_t g_shutdown = 0;

void sigint_handler(int sig) {
    g_shutdown = 1;              // 仅设置标志
    // 不调用任何非 async-signal-safe 函数
}
```

## 模式 5: lock order inversion

**脆弱模式**:

```c
// Thread A:
void transfer_a_to_b(struct account *a, struct account *b, int amt) {
    pthread_mutex_lock(&a->mtx);
    pthread_mutex_lock(&b->mtx);  // 顺序: a → b
    a->balance -= amt;
    b->balance += amt;
    pthread_mutex_unlock(&b->mtx);
    pthread_mutex_unlock(&a->mtx);
}

// Thread B:
void transfer_b_to_a(struct account *b, struct account *a, int amt) {
    pthread_mutex_lock(&b->mtx);
    pthread_mutex_lock(&a->mtx);  // 顺序: b → a (与上面相反)
    a->balance += amt;
    b->balance -= amt;
    pthread_mutex_unlock(&a->mtx);
    pthread_mutex_unlock(&b->mtx);
}
```

**安全模式**:

```c
// 强制一致的锁顺序 (如按地址排序)
void transfer(struct account *from, struct account *to, int amt) {
    pthread_mutex_t *first  = &from->mtx < &to->mtx ? &from->mtx : &to->mtx;
    pthread_mutex_t *second = &from->mtx < &to->mtx ? &to->mtx : &from->mtx;
    pthread_mutex_lock(first);
    pthread_mutex_lock(second);
    from->balance -= amt;
    to->balance += amt;
    pthread_mutex_unlock(second);
    pthread_mutex_unlock(first);
}
```

## PTHREAD_MUTEX_INITIALIZER vs 动态初始化

```c
// 静态初始化 (编译期)
pthread_mutex_t g_mtx = PTHREAD_MUTEX_INITIALIZER;

// 动态初始化 (运行时) — 需要检查是否配对 pthread_mutex_destroy
pthread_mutex_t *mtx = malloc(sizeof(*mtx));
pthread_mutex_init(mtx, NULL);
```

静态初始化的 mutex 不需要 destroy。动态初始化的 mutex 必须在所有线程使用完毕后 destroy，否则有资源泄漏风险（某些实现中分配了内核资源）。
