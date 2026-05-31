---
detector: race-condition
severity: high
cwe: CWE-362
language: [c, cpp]
tags: [concurrency, threading, toctou]
---

# 竞态条件 (Race Condition)

## 威胁定义

多线程/多进程代码中对共享资源（全局变量、静态变量、堆共享内存、文件描述符）的访问未正确同步，导致执行结果依赖线程调度顺序。在安全场景中，TOCTOU 竞态可导致权限检查绕过。

**核心原则：跨线程共享的可变数据必须用锁/原子操作保护。** 检测时需区分"真正跨线程共享"和"单线程/初始化阶段"——前者报告，后者不报告。

## 检测逻辑

### Step 1: 确认"跨线程共享" — 前置条件

**不报告**的场景（必须先排除）：

| 场景 | 判断方法 |
|------|---------|
| `main()` 中，在 `pthread_create` 之前 | 线程尚未创建 |
| `__attribute__((constructor))` | 单线程初始化 |
| `static` 变量仅在初始化函数中修改 | 初始化后再无写操作 |
| `_Thread_local` / `thread_local` 变量 | 每个线程独立副本 |
| `const` 全局变量 | 只读，无需同步 |

**报告**的场景：

| 场景 | 判断方法 |
|------|---------|
| 全局变量在 `pthread_create` 之后的函数中修改 | 跨线程共享 |
| 同一文件描述符在多线程中使用 | 共享资源 |
| 函数在多个线程的回调/任务中被调用 | 并发执行 |

### Step 2: 无保护的共享变量修改 — 报告

```c
// 报告：全局变量无锁修改
int g_counter = 0;
void increment() { g_counter++; }  // 非原子！

// 报告：static 局部变量跨调用共享
void count_calls() {
    static int calls = 0;
    calls++;  // 多线程不安全
}
```

### Step 3: TOCTOU 文件操作 — 报告

```c
// 报告：access + open 时序窗口
if (access(file, R_OK) == 0) {
    fd = open(file, O_RDONLY);  // 中间文件可能被替换
}

// 不报告：使用 fstat + 文件描述符
fd = open(file, O_RDONLY);
fstat(fd, &st);  // 通过 fd 操作，无 TOCTOU
```

### Step 4: 双重检查锁定错误

```cpp
// 报告：C++ 中双重检查锁定需配合 std::atomic
if (instance == nullptr) {           // 非原子读取
    lock();
    if (instance == nullptr) {
        instance = new T();          // 可能看到部分构造对象
    }
    unlock();
}

// 不报告：C++11+ 正确使用 std::atomic + mutex
std::atomic<T*> instance;
```

## 修复指引

1. **简单计数器**：使用 `std::atomic<int>` 或 `_Atomic int`
2. **复杂数据结构**：使用 `std::mutex` / `pthread_mutex_lock`
3. **文件 TOCTOU**：使用 `fstat()` + 文件描述符操作，而非路径操作
4. **初始化**：使用 `std::call_once` / `pthread_once`

## 误报排除

| 场景 | 原因 |
|------|------|
| `std::atomic<T>` | 硬件保证原子性 |
| `std::mutex` / `pthread_mutex_lock` 保护 | 正确同步 |
| `thread_local` / `_Thread_local` | 线程独立副本 |
| `const` / `constexpr` 全局变量 | 只读，无需同步 |
| `pthread_create` 之前的所有代码 | 单线程阶段 |
| `__attribute__((constructor))` | 单线程初始化 |

## 检测模式汇总

```
# === MUST REPORT ===

# 全局/static 变量在并发上下文中无保护修改
(^int|^long|^char|^bool)\s+g_\w+\s*=
→ 函数内 g_\w+\s*(\+\+|\-\-|\+=|\=|\.)
→ 同一函数内无 (mutex|lock|atomic|pthread_mutex)

# access/open TOCTOU
access\(|stat\(|lstat\(
→ (同作用域) open\(|fopen\(
→ 使用相同文件名/路径变量
→ 无 O_NOFOLLOW 标志

# 信号处理器中的不安全调用
void\s+\w+\s*\(\s*int\s+sig\s*\)
→ (printf|malloc|free|fopen|pthread|lock)\s*\(

# === MUST NOT REPORT (白名单) ===

# 原子操作
std::atomic|_Atomic|__atomic|std::call_once|pthread_once

# 线程局部存储
thread_local|_Thread_local|__thread

# main() 中 pthread_create 之前的代码
# (需要流程分析确认)

# 初始化后只读
const\s+\w+\s+g_|static\s+const
```
