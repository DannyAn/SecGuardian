---
detector: deadlock
severity: medium
cwe: CWE-833
language: [c, cpp]
tags: [concurrency, threading, lock-ordering]
---

# 死锁 (Deadlock)

## 检测概要

检查多个锁的获取顺序是否一致，防止循环等待导致的死锁。

## 检测逻辑

### Step 1: 搜索锁获取操作

```c
pthread_mutex_lock(&m1);
pthread_mutex_lock(&m2);
// critical section
pthread_mutex_unlock(&m2);
pthread_mutex_unlock(&m1);
```

C++ 中：
```cpp
std::lock_guard<std::mutex> lk1(m1);
std::lock_guard<std::mutex> lk2(m2);
std::scoped_lock lk(m1, m2);  // C++17: 死锁安全
```

### Step 2: 检查锁定顺序

**模式 1：不一致的锁定顺序**
```c
// 函数 A: 先 m1 后 m2
void func_a() {
    lock(m1); lock(m2);
    // ...
    unlock(m2); unlock(m1);
}

// 函数 B: 先 m2 后 m1 — 可能死锁！
void func_b() {
    lock(m2); lock(m1);
    // ...
    unlock(m1); unlock(m2);
}
```

**模式 2：递归锁缺失**
```c
// BAD: 普通 mutex 重入导致死锁
void recursive_func() {
    pthread_mutex_lock(&m);    // 已在上层调用中锁定！
    do_work();
    pthread_mutex_unlock(&m);
}
```

**模式 3：回调中的锁**
```c
// BAD: 持锁期间调用外部回调
lock(&m);
callback(user_fn);              // user_fn 可能尝试获取同一把锁 — 死锁！
unlock(&m);
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::scoped_lock(m1, m2)` | C++17 死锁避免算法 |
| `pthread_mutex_trylock` + 回退 | 非阻塞尝试 |
| `PTHREAD_MUTEX_RECURSIVE` | 支持重入 |
| 同一函数内成对获取 | 多个锁在函数入口统一获取 |

## 检测模式汇总

```
# 跨函数的锁获取顺序不一致
func_a: lock(A) → lock(B)
func_b: lock(B) → lock(A)      # 反转顺序！

# 持锁回调
lock(X)
→ 调用函数指针/虚函数/外部回调
→ (回调中) lock(X)              # 潜在重入死锁

# 普通 mutex 递归获取
pthread_mutex_lock (非 RECURSIVE)
→ 同函数/调用链中再次 pthread_mutex_lock
```