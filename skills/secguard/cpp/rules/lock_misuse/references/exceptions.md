# 锁误用 — 边缘情况抑制

## 抑制条件

以下情况应降低 confidence 或标记为 intentional：

| 条件 | 误用模式 | 处理 |
|------|---------|------|
| RAII 包装 (`lock_guard`/`unique_lock`) | 未匹配 unlock | unlock 由析构函数自动调用 → 不标记 |
| 递归 mutex (`PTHREAD_MUTEX_RECURSIVE`) | double-lock | 同一线程可多次 lock → 需要确认识别为递归 mutex |
| trylock+失败路径 | unlock without lock | trylock 返回非 0 时不应 unlock → 代码模式正确则不标记 |
| 信号仅从其他线程发送 (`pthread_kill`) | 信号处理器 lock | 需证明不会在持有锁的线程中触发 → 做不到证明时仍标记但 confidence: medium |
| 退出路径无 unlock 但错误处理直接 exit | 未匹配 unlock | `exit()`/`abort()` 在 unlock 前调用 → 进程终止时不需 unlock，且 OS 会清理 |

## 递归 mutex 的特殊处理

递归 mutex 允许同一线程多次 lock，但要求 unlock 次数等于 lock 次数：

```c
pthread_mutexattr_t attr;
pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
pthread_mutex_t mtx;
pthread_mutex_init(&mtx, &attr);

// 递归锁的下述代码安全:
pthread_mutex_lock(&mtx);
pthread_mutex_lock(&mtx);  // 递归锁: 同一线程允许
pthread_mutex_unlock(&mtx);
pthread_mutex_unlock(&mtx);
```

检测器需要根据 `pthread_mutexattr_settype` 的类型参数判断是否为递归锁。缺省类型 `PTHREAD_MUTEX_DEFAULT` / `PTHREAD_MUTEX_NORMAL` 时，double-lock 为真正的误用。

## trylock 引发的假阳性

当 lock 使用 trylock 时，后续代码需要在 trylock 成功和失败两个分支中分别处理 lock/unlock：

```c
if (pthread_mutex_trylock(&mtx) == 0) {
    // 持有锁... 临界区内代码
    pthread_mutex_unlock(&mtx);
} else {
    // 未获得锁 — 不能 unlock
}
```

在这类 pattern 中：
- trylock 分支内必须有 unlock 配对
- else 分支内不应有 unlock
- trylock 分支外（if 之外）不应 unlock 除非明确知道锁已被持有

## 条件变量的 edge case

条件变量与互斥锁配合时，`pthread_cond_wait` 会自动释放锁并在返回前锁，因此是特殊正确模式：

```c
pthread_mutex_lock(&mtx);
while (!ready) {
    pthread_cond_wait(&cond, &mtx);  // 自动 unlock → wait → relock
}
// 此处已持有 mtx
pthread_mutex_unlock(&mtx);
```

检测器应了解 `pthread_cond_wait` / `pthread_cond_timedwait` 的语义：它们在调用时 unlock 互斥锁，在返回时 re-lock。因此 cond_wait 前后的 lock/unlock 匹配需要降灵敏度。

## 检测器忽略指令

```c
// secguard:lock-misuse-ignore
// secguard:ignore[double-lock]
// secguard:ignore[unlock-without-lock]
// NOLINTNEXTLINE(concurrency-*)
```
