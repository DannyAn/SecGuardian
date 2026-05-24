---
detector: data-race
severity: high
cwe: CWE-366
language: [c, cpp]
tags: [concurrency, threading, undefined-behavior]
---

# 数据竞争 (Data Race)

## 检测概要

检查两个或多个线程同时访问同一内存位置，且至少一个是写操作，而没有任何同步机制。

## 检测逻辑

### Step 1: 搜索非同步的并发写

```c
// BAD: 数据竞争
int shared_flag = 0;
// Thread 1: shared_flag = 1;
// Thread 2: if (shared_flag) { ... }  // 未同步读

// GOOD: 原子操作
std::atomic<int> shared_flag{0};
```

### Step 2: 危险模式

**模式 1：非原子标志位**
```c
// BAD: volatile 不提供原子性！
volatile int done = 0;
void worker() {
    while (!done) { ... }        // 数据竞争！
}
void finisher() {
    done = 1;                    // 数据竞争！
}
```

**模式 2：复合操作的非原子性**
```c
// BAD: 读-改-写三步非原子
if (flags & MASK) {
    flags &= ~MASK;              // 中间可能被其他线程修改
}
```

**模式 3：位域 (Bitfield) 竞争**
```c
// BAD: 位域的非原子访问
struct Flags {
    unsigned int a:1;
    unsigned int b:1;            // a 和 b 可能在同一个机器字内
};
// Thread 1: flags.a = 1;       // 写整个字
// Thread 2: flags.b = 1;       // 可能覆盖 Thread 1 的写
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::atomic<T>` | 原子操作 |
| `std::mutex`/`std::lock_guard` 保护 | 互斥同步 |
| `pthread_mutex_lock` 保护 | POSIX 同步 |
| 单线程程序 | 无并发 |
| 初始化阶段只写一次 | 后续只读无需同步 |
| `__sync_*` / `__atomic_*` builtins | 原子内置函数 |

## 检测模式汇总

```
# volatile 误用为同步
volatile int.*=.*0;
→ while.*!volatile_var     # 非原子读取
→ volatile_var = 1         # 在另一线程

# 多线程共享变量无保护
(全局/静态变量 或 堆指针)
→ pthread_create|std::thread 上下文
→ 写入操作 无 mutex|atomic|lock

# 位域结构体多线程访问
struct.*{.*unsigned int.*:.*;
→ pthread_create 上下文中修改位域
```