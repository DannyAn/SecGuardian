---
detector: race-condition
severity: high
cwe: CWE-362
language: [c, cpp]
tags: [concurrency, threading, toctou]
precision: medium
confidence: dynamic
---

# 竞态条件 (Race Condition)

## 威胁定义 (Threat Definition)

多线程/多进程代码中对共享资源（全局变量、静态变量、堆共享内存、文件描述符）的访问未正确同步，导致执行结果依赖线程调度顺序。在安全场景中，TOCTOU 竞态可导致权限检查绕过。

**核心原则：跨线程共享的可变数据必须用锁/原子操作保护。** 检测时需区分"真正跨线程共享"和"单线程/初始化阶段"——前者报告，后者不报告。

## 检测逻辑 (Detection Logic)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：共享变量/资源的声明和并发访问代码块，包含全局变量/静态变量的声明、修改操作（++/--/=/+=/.成员修改）、以及周边线程创建（pthread_create/std::thread）代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析共享资源的并发访问是否受保护——是否存在 mutex/pthread_mutex_lock/atomic 操作；是否在 pthread_create 之后才发生修改；变量是否为 thread_local/const 等线程安全类型
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：共享变量从声明 → 线程创建 → 并发读写的完整数据流，标注同步原语的存在位置
      → findings.evidence.data_flow_path
- [ ] **call_stack**：pthread_create → 线程入口函数 → 共享变量访问的调用链，以及主线程中访问同一变量的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：共享变量的类型（int/long/pointer/struct）、是否声明为 volatile、pthread_create 的调用位置和线程入口函数
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用 ThreadSanitizer（-fsanitize=thread）运行时检测、是否有锁注解（__attribute__((guarded_by))）静态检查
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **简单计数器**：使用 `std::atomic<int>` 或 `_Atomic int`
2. **复杂数据结构**：使用 `std::mutex` / `pthread_mutex_lock`
3. **文件 TOCTOU**：使用 `fstat()` + 文件描述符操作，而非路径操作
4. **初始化**：使用 `std::call_once` / `pthread_once`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `std::atomic<T>` | 硬件保证原子性 | 确认变量声明为 std::atomic<T> 或 _Atomic T，所有读写均通过原子操作 |
| `std::mutex` / `pthread_mutex_lock` 保护 | 正确同步 | 确认所有访问同一共享变量的代码路径均在 lock/unlock 块内 |
| `thread_local` / `_Thread_local` | 线程独立副本 | 确认变量声明包含 thread_local/_Thread_local/__thread 关键字 |
| `const` / `constexpr` 全局变量 | 只读，无需同步 | 确认变量声明为 const/constexpr 且在初始化后无写操作 |
| `pthread_create` 之前的所有代码 | 单线程阶段 | 确认 pthread_create 调用在共享变量修改之后，中间无并发窗口 |
| `__attribute__((constructor))` | 单线程初始化 | 确认函数仅在进程启动时被 .init 段调用一次 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 全局/static 变量在并发上下文中无保护修改
(^int|^long|^char|^bool)\s+g_\w+\s*=
                                                       # → MUST: code_context (共享变量声明+修改代码)
→ 函数内 g_\w+\s*(\+\+|\-\-|\+=|\=|\.)
→ 同一函数内无 (mutex|lock|atomic|pthread_mutex)
                                                       # → MUST: judgment_rationale (同步保护存在性分析)

# access/open TOCTOU
access\(|stat\(|lstat\(
→ (同作用域) open\(|fopen\(
→ 使用相同文件名/路径变量
→ 无 O_NOFOLLOW 标志

# 信号处理器中的不安全调用
void\s+\w+\s*\(\s*int\s+sig\s*\)
→ (printf|malloc|free|fopen|pthread|lock)\s*\(

# === EXCLUDE (不报告) ===

# 原子操作
std::atomic|_Atomic|__atomic|std::call_once|pthread_once

# 线程局部存储
thread_local|_Thread_local|__thread

# main() 中 pthread_create 之前的代码
# (需要流程分析确认)

# 初始化后只读
const\s+\w+\s+g_|static\s+const

# 同步原语保护
pthread_mutex_lock|std::lock_guard|std::unique_lock|std::scoped_lock
\bmtx\.lock\(\)|\bmu\.lock\(\)|\block\.lock\(\)
```
