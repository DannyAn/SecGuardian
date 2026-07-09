# 锁误用 — 误报抑制

## 信号级误报抑制

### 1. RAII 造成的"未匹配 unlock"

```cpp
void process(struct shared *d) {
    std::lock_guard<std::mutex> lk(d->mtx);
    if (d->state == INVALID) return -1;
    d->counter++;
    // lock_guard 析构在此函数末尾自动 unlock
}
```

**检测**: 检查调用点是否位于构造函数/析构函数代码中，或者 `lock_guard`/`unique_lock`/`scoped_lock` 的类型定义。如果是 RAII → 跳过信号。

### 2. pthread_cond_wait 的特殊语义

```c
void consumer() {
    pthread_mutex_lock(&mtx);
    while (!ready) {
        pthread_cond_wait(&cond, &mtx);  // 内部 unlock, wait, relock
    }
    // cond_wait 返回时已持有 mtx
    pthread_mutex_unlock(&mtx);
}
```

**检测**: 如果触发信号的非预期 unlock 位于 `pthread_cond_wait`/`pthread_cond_timedwait` 的参数位置（cond_wait 第二个参数是 mutex）→ 这是条件变量的标准用法，跳过该信号点。

### 3. 递归 mutex 的 double-lock

```c
pthread_mutexattr_t attr;
pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
pthread_mutex_init(&mtx, &attr);
// ...
pthread_mutex_lock(&mtx);
pthread_mutex_lock(&mtx);   // 递归锁: 同一线程允许二次 lock
pthread_mutex_unlock(&mtx);
pthread_mutex_unlock(&mtx);
```

**检测**: 从 `lock_graph.mutexes` 或 mutex 初始化路径回溯，如果 mutex 的类型属性为 `PTHREAD_MUTEX_RECURSIVE` → 对同一 mutex 的 double-lock 不标记。

### 4. 进程终止路径

```c
void fatal_error() {
    pthread_mutex_lock(&log_mtx);
    fprintf(stderr, "Fatal: out of memory\n");
    // 没有 unlock — 因为下面立即 exit
    exit(EXIT_FAILURE);
}
```

**检测**: 如果函数中最后的退出路径（不返回的那个）调用了 `exit()`/`_exit()`/`abort()` → 该路径上的 unlock 缺失不标记。但需确认其他路径也有 unlock。

### 5. 静态初始化 mutex 与全局锁表

```c
// 锁表惯用语: 用一个数组管理多个锁
pthread_mutex_t lock_table[64];

int acquire_lock(int id) {
    return pthread_mutex_lock(&lock_table[id]);
}

int release_lock(int id) {
    return pthread_mutex_unlock(&lock_table[id]);
}
```

**检测**: 当 lock 和 unlock 位于不同函数或动态间接位置时，检测器的配对检查能力受限。这种模式下，跟踪引用同一 `lock_table` 数组的 acquire/release 配对只能通过调用图分析。如果代码通过 id 间接引用 → 标记但 confidence: low（配对方式合法但本检测器无法证明正确性）。

### 6. 标记为单线程的代码段

```c
#pragma omp single
{
    // 单线程区域 — 不需要锁
    shared_var = compute();
}
```

**检测**: 如果 lock/unlock 位于 OpenMP `single`/`critical`/`ordered` 区段搭配正确的线程化环境 → 降低 confidence。

## 项目级抑制

在 `.secguard.json` 中配置：

```json
{
  "detectors": {
    "lock_misuse": {
      "severity_cap": "medium",
      "suppress": ["signal-handler-lock", "recursive-mutex-double-lock"]
    }
  }
}
```

## 信噪比统计

| 模式 | 真实检出的估计 FP 率 | 说明 |
|------|--------------------|------|
| 未匹配 unlock | ~5% | 大多数路径问题是真实的 |
| double-lock | ~20% | 递归 mutex 和 RAII 导致常见 FP |
| unlock without lock | ~10% | trylock 失败路径和错误处理路径导致 |
| 信号处理器 lock | ~50% | 已知仅从其他线程发信号时安全 |
| lock order inversion | ~25% | 需要完整的跨函数分析才能低 FP |
