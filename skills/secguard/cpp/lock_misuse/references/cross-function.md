# 锁误用 — 跨函数追踪

## 追踪规则

对 lock_misuse 检测器的 Step 4，最大深度为 1 级。重点追踪方向：

1. lock 后的函数调用中是否包含对同一 mutex 的 unlock
2. unlock 前调用的函数中是否有额外的 lock/unlock
3. RAII 包装类（lock 在构造函数、unlock 在析构函数）

## 方向 A: Lock→Callee 内 unlock

```c
void critical_section(struct shared *d) {
    pthread_mutex_lock(&d->mtx);
    do_work(d);          // Step 4: 查 do_work 内部
    update_stats(d);     // Step 4: 查 update_stats 内部
    pthread_mutex_unlock(&d->mtx);
}
```

对 `do_work` 和 `update_stats`，查 `call_graph.edges` 找到它们的定义，检查内部是否有 `pthread_mutex_unlock(&d->mtx)`：

```c
void do_work(struct shared *d) {
    // 内部如果没有 lock/unlock 操作 → 正常
    d->value += compute();
}

void update_stats(struct shared *d) {
    pthread_mutex_unlock(&d->mtx);    // BUG: 内部释放了 caller 持有的锁
    // ... 此时 d 不受保护 ...
    pthread_mutex_lock(&d->mtx);      // OK: 重新获取
}
```

这种模式标记：callee 内 unlock 了 caller 持有的锁 → 检查 callee 返回后 caller 是否安全。

## 方向 B: RAII 包装

C++ 风格的 RAII 包装是常见模式，跨函数追踪时需要识别：

```cpp
// 包装类
struct ScopedLock {
    pthread_mutex_t *m;
    ScopedLock(pthread_mutex_t *m) : m(m) { pthread_mutex_lock(m); }
    ~ScopedLock() { pthread_mutex_unlock(m); }
};

// 使用
void safe_func(struct shared *d) {
    ScopedLock lk(&d->mtx);   // 构造 = lock
    d->counter++;              // 受保护
}                              // 析构 = unlock
```

对 RAII 模式：
- 构造/析构函数的 lock/unlock 应该视为配对，不单独标记未匹配
- 但应检查 ScopedLock 内部构造函数与析构函数是否引用同一 mutex 变量
- 如果析构函数有异常路径（`~ScopedLock()` 中 `pthread_mutex_unlock` 被 `try-catch` 包裹），额外检查

## 方向 C: 条件编译嵌套

```c
// caller:
void func(struct shared *d) {
    pthread_mutex_lock(&d->mtx);
#ifdef DEBUG
    debug_check(d);        // debug 模式下调用内部也有 lock
#endif
    pthread_mutex_unlock(&d->mtx);
}

// debug_check:
void debug_check(struct shared *d) {
    pthread_mutex_lock(&d->mtx);    // 条件编译导致的 double-lock
    print_state(d);
    pthread_mutex_unlock(&d->mtx);
}
```

检查 callee 是否与 caller 在相同条件下编译。如果 `debug_check` 无 `#ifdef` 保护（即总是编译）→ double-lock 是真实的。如果两处都有 `#ifdef DEBUG` 保护 → 运行时会正常。

## 方向 D: 多 mutex 的 lock order 跨函数

```c
void transfer(struct account *a, struct account *b, int amt) {
    lock_pair(a, b);
    a->balance -= amt;
    b->balance += amt;
    unlock_pair(a, b);
}

void lock_pair(struct account *a, struct account *b) {
    pthread_mutex_lock(&a->mtx);       // 先锁 a
    pthread_mutex_lock(&b->mtx);       // 后锁 b
}

void unlock_pair(struct account *a, struct account *b) {
    pthread_mutex_unlock(&b->mtx);
    pthread_mutex_unlock(&a->mtx);
}
```

多 mutex 跨函数场景：检查 `call_graph` 是否所有 path 的 lock 顺序一致。如果有另一条路径：

```c
void reverse_transfer(struct account *a, struct account *b, int amt) {
    lock_pair(b, a);    // 虽然调用了同一个函数，但参数交换导致锁顺序反转
    // ...
}
```

此时需要检查 `lock_pair` 内部是否按参数顺序锁（是的），因此效果是锁顺序反转 → 标记 lock order inversion。
