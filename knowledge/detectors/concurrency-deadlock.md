---
detector: deadlock
severity: medium
cwe: CWE-833
language: [c, cpp]
tags: [concurrency, threading, lock-ordering]
---

# 死锁 (Deadlock)

## 威胁定义

两个或多个线程互相等待对方持有的锁，导致所有相关线程永久阻塞。在服务端程序中，死锁可导致整个服务不可用。

**核心原则：多锁获取必须遵循全局一致的顺序，持锁期间不得调用外部回调。**

## 检测逻辑

### Step 1: 跨函数锁定顺序不一致 — 报告

```
// 函数 A: lock(m1) → lock(m2) ← 顺序: m1, m2
// 函数 B: lock(m2) → lock(m1) ← 顺序: m2, m1  → 报告：顺序反转！
```

### Step 2: 持锁期间调用外部函数 — 报告

```
lock(m);
callback(user_fn);  // user_fn 可能尝试 lock(m) → 重入/死锁
unlock(m);
```

### Step 3: 不报告的场景

| 场景 | 原因 |
|------|------|
| `std::scoped_lock(m1, m2)` | C++17 死锁避免算法（同时获取） |
| `std::lock(m1, m2)` | C++11 死锁避免 |
| `pthread_mutex_trylock()` + 回退 | 非阻塞尝试，失败后释放已有锁 |
| `PTHREAD_MUTEX_RECURSIVE` 类型 | 允许同线程重入 |
| 单锁操作 | 一把锁不会造成死锁（但可能持锁时间过长） |

## 修复指引

1. **统一锁顺序**：所有代码路径按相同顺序获取多把锁（如始终先 m1 后 m2）
2. **C++17**：使用 `std::scoped_lock(m1, m2, m3)` 自动避免死锁
3. **减少持锁范围**：不在锁内调用外部/未知代码
4. **使用 try_lock 模式**：尝试获取，失败则释放已有锁后重试

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::scoped_lock` / `std::lock` 同时获取 | 标准库死锁避免 |
| `PTHREAD_MUTEX_RECURSIVE` | 支持同线程重入 |
| `pthread_mutex_trylock` 失败后释放已有锁 | 非阻塞模式 |
| 单锁或无锁代码 | 无循环等待条件 |
| 初始化阶段（单线程） | 无竞争 |

## 检测模式汇总

```
# === MUST REPORT ===

# 不同函数中锁获取顺序反转（需跨函数分析）
# func_a: lock(A) → lock(B)
# func_b: lock(B) → lock(A)    ← 报告

# 持锁回调
(pthread_mutex_lock|std::mutex.*lock|EnterCriticalSection)\(&?\w+\)
→ 同一函数内调用: 函数指针|虚函数|外部回调|callback|fn\(
→ (回调中同锁): lock(同一变量)  ← 潜在重入/死锁

# 普通 mutex 递归获取
pthread_mutex_init\([^)]*NULL\)  # 默认非递归
→ 函数内再次 pthread_mutex_lock(同一 mutex)

# === MUST NOT REPORT ===

std::scoped_lock|std::lock\(   # 标准库死锁避免
PTHREAD_MUTEX_RECURSIVE        # 递归锁
pthread_mutex_trylock          # 非阻塞
```
