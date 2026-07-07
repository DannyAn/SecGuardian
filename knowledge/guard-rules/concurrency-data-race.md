---
detector: data-race
description: Detects data races where multiple threads access the same memory without proper synchronization
severity: high
cwe: CWE-366
cvss: 7.5
language: [c, cpp]
tags: [concurrency, threading, undefined-behavior]
precision: medium
confidence: dynamic
target_functions: [finisher, worker]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

两个或多个线程同时访问同一内存位置且至少一个为写操作，无同步机制保护。在 C/C++ 中数据竞争是未定义行为，编译器可能做出破坏性的优化假设。

**核心原则：跨线程共享的可变数据必须用 `std::atomic`/互斥锁保护，或通过 `thread_local` 隔离。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. **简单类型**：`std::atomic<int>` / `_Atomic int`
2. **复杂结构**：`std::mutex` + `std::lock_guard` / `pthread_mutex_lock`
3. **只读共享**：`const` 全局变量无需同步
4. **线程隔离**：`thread_local` 变量每个线程独立副本
5. **工具检测**：启用 ThreadSanitizer（`-fsanitize=thread`）

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：共享变量声明及并发访问代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：是否缺少同步机制保护
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：多线程对共享变量的读写路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：线程创建到共享变量访问的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：互斥锁/原子变量状态
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用ThreadSanitizer检测结果
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| `std::atomic<T>` | 原子操作 | 确认变量声明为std::atomic或_Atomic类型 |
| `std::mutex`/`std::lock_guard` 保护 | 互斥同步 | 确认同一mutex在变量的所有访问点均被获取 |
| `pthread_mutex_lock` 保护 | POSIX 同步 | 确认pthread_mutex_lock覆盖变量的所有读写路径 |
| 单线程程序 | 无并发 | 确认程序无pthread_create/std::thread/fork调用 |
| 初始化阶段只写一次 | 后续只读无需同步 | 确认写入发生在任何线程创建之前（happens-before保证） |
| `__sync_*` / `__atomic_*` builtins | 原子内置函数 | 确认所有访问均使用原子内置函数而非裸访问 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# volatile 误用为同步
volatile int.*=.*0;
→ evidence: code_context (变量声明)
→ while.*!volatile_var     # 非原子读取
   → evidence: data_flow_path (读路径)
→ volatile_var = 1         # 在另一线程
   → evidence: data_flow_path (写路径)

# 多线程共享变量无保护
(全局/静态变量 或 堆指针)
→ evidence: code_context (共享变量声明)
→ pthread_create|std::thread 上下文
   → evidence: call_stack (线程创建点)
→ 写入操作 无 mutex|atomic|lock
   → evidence: variable_state (同步机制缺失)

# 位域结构体多线程访问
struct.*{.*unsigned int.*:.*;
→ evidence: code_context (位域定义)
→ pthread_create 上下文中修改位域
   → evidence: data_flow_path (并发写路径)
```

### 排除模式 (EXCLUDE)

```
std::atomic<|_Atomic|__atomic_
→ 原子类型已使用，无需报告
std::mutex|std::lock_guard|std::scoped_lock
→ C++互斥锁已使用，无需报告
pthread_mutex_lock|pthread_rwlock
→ POSIX同步原语已使用，无需报告
thread_local
→ 线程局部存储，无共享，无需报告
```
