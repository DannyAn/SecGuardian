---
detector: race-condition
severity: high
cwe: CWE-362
language: [c, cpp]
tags: [concurrency, threading, toctou]
---

# 竞态条件 (Race Condition)

## 检测概要

检查多线程/多进程代码中对共享资源的访问是否未正确同步，导致执行结果依赖于线程调度顺序。

## 检测逻辑

### Step 1: 搜索共享资源访问

识别跨线程访问的变量、文件、套接字等：
- 全局变量
- `static` 局部变量
- 堆上分配并通过指针共享的内存
- 文件描述符

### Step 2: 检查同步机制缺失

**模式 1：无保护的共享变量**
```c
// BAD: counter 无保护
int counter = 0;
void increment() {
    counter++;                     // 非原子操作，多线程不安全！
}
```

**模式 2：TOCTOU (Time-of-Check Time-of-Use)**
```c
// BAD: 检查和使用之间存在窗口
if (access(filename, F_OK) == 0) {
    fd = open(filename, O_RDONLY); // TOCTOU：中间文件可能被替换
}
```

**模式 3：双重检查锁定缺陷**
```cpp
// BAD: 双重检查锁定在 C++ 中需要原子操作
if (instance == nullptr) {
    lock();
    if (instance == nullptr) {
        instance = new Singleton();  // 非原子！可能看到部分构造的对象
    }
    unlock();
}
```

**模式 4：signal handler 中的非安全操作**
```c
// BAD: signal handler 中使用非信号安全函数
void handler(int sig) {
    printf("caught signal\n");     // printf 不是信号安全的！
    free(global_ptr);              // 极度危险
}
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::atomic<T>` | 原子操作，硬件保证 |
| `std::mutex`/`std::lock_guard` | RAII 锁管理 |
| `pthread_mutex_lock`/`unlock` | POSIX 线程同步 |
| 单线程上下文 | `main()` 中无 pthread 创建 |
| 初始化阶段（单线程） | `main()` 开头或 `__attribute__((constructor))` |

## 检测模式汇总

```
# 全局变量在无锁函数中被修改
int|long|char \*g_... = ...
→ 函数内修改 (无 mutex|lock|atomic)

# access/open TOCTOU
access|stat|lstat
→ open|fopen (同一文件，无 O_NOFOLLOW)

# 信号处理函数中的不安全调用
void.*handler.*int sig
→ printf|malloc|free|fopen|pthread
```