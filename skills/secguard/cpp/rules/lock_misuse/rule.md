---
name: secguard-cpp-lock_misuse
description: "Detect unmatched lock/unlock pairs, double-lock, unlock-before-lock, and signal-handler deadlock risks in pthread mutex usage"
category: language-specific
language: cpp
topic: [concurrency]
skill_id: concurrency.lock
signal_filter: concurrency.lock*
signal_source: call_sites[cat="concurrency"]
severity: high
cwe: [CWE-667]
---

# lock_misuse 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `concurrency.lock` |
| signal_filter | `concurrency.lock*`（供 `secguard ./src c concurrency.lock` 过滤匹配） |
| signal_source | `call_sites[cat="concurrency"]` |
| 默认严重度 | High |

---

## Scenario 1: 锁获取/释放配对不完整（CWE-667）

### 威胁定义

`pthread_mutex_lock`/`pthread_mutex_unlock`（或等效平台锁 API）的获取-释放配对不完整，映射 CWE-667（Improper Locking）。具体包括三种子类型：(a) **只锁不解**（lock without unlock）——任一路径缺少 unlock 导致其他线程永久阻塞；(b) **重复加锁**（double lock）——同一线程连续两次 lock 非递归互斥锁，造成自死锁；(c) **解锁未持有锁**（unlock without lock）——对未锁定或已释放的 mutex 调用 unlock，行为未定义。不同于 Scenario 2（信号处理器）和 Scenario 3（锁序死锁），本场景聚焦于**单个锁对象的获取/释放配对完整性**。

**核心原则：lock 和 unlock 必须一一配对，所有退出路径（return/break/continue/goto/throw）都必须在 unlock 之后。**

### 检测逻辑

**Step 1: 定位锁操作点**

在函数体内搜索 `pthread_mutex_lock()` / `pthread_mutex_unlock()`（以及各平台等价 API：`EnterCriticalSection`/`LeaveCriticalSection`、`mutex_lock`/`mutex_unlock`、`mtx_lock`/`mtx_unlock`），记录每个锁操作的 mutex 对象和行号。

**Step 2: 配对分析**

对每次 `lock(m)` 调用，在函数体内搜索下一个对同一 `m` 的 `lock()` 调用（double lock 检测）以及对应的 `unlock(m)` 调用。构建 lock→unlock 配对，考虑所有退出路径（包括 `return`、`break`、`continue`、`goto`、C++ `throw`）。

**Step 3: 逐路径验证**

```c
// BAD: 错误路径只锁不解
pthread_mutex_lock(&m);
if (error) {
    return -1;                       // m 未解锁！其他线程永久阻塞
}
do_work();
pthread_mutex_unlock(&m);

// BAD: 重复加锁（非递归 mutex → self-deadlock）
pthread_mutex_lock(&m);
pthread_mutex_lock(&m);              // 第二次 lock：自死锁！
do_work();
pthread_mutex_unlock(&m);

// BAD: 循环中不解锁即 continue
pthread_mutex_lock(&m);
while (condition) {
    if (skip) continue;              // m 未解锁即跳回循环头！
    do_work();
}
pthread_mutex_unlock(&m);

// BAD: goto 跳过 unlock
pthread_mutex_lock(&m);
if (error) goto error_exit;
pthread_mutex_unlock(&m);
return 0;
error_exit:
    return -1;                       // 跳过了 unlock!

// BAD: unlock without prior lock
void early_exit_error(struct shared_data *d) {
    if (d == NULL) {
        pthread_mutex_unlock(&d->mtx);  // BUG: 从未锁定就释放
        return;
    }
    pthread_mutex_lock(&d->mtx);
    // ...
    pthread_mutex_unlock(&d->mtx);
}

// BAD: 连续两次 lock 同一 non-recursive mutex（跨函数）
void helper() {
    pthread_mutex_lock(&m);          // 调用者已持有 m → deadlock
    do_work();
    pthread_mutex_unlock(&m);
}
void caller() {
    pthread_mutex_lock(&m);
    helper();                        // 重入 lock → 死锁
    pthread_mutex_unlock(&m);
}

// GOOD: goto cleanup 统一解锁
pthread_mutex_lock(&m);
if (error1) goto cleanup;
ret = do_work();
if (error2) goto cleanup;
cleanup:
    pthread_mutex_unlock(&m);
    return ret;

// GOOD: 所有退出路径均有 unlock
pthread_mutex_lock(&m);
if (error) {
    pthread_mutex_unlock(&m);        // 错误路径显式解锁
    return -1;
}
pthread_mutex_unlock(&m);
return 0;

// GOOD (C++): RAII lock_guard 自动释放
{
    std::lock_guard<std::mutex> guard(m);
    // ... critical section ...
}
```

### 检测模式

```
# MATCH（触发检测）
pthread_mutex_lock(&m) 后存在缺少 pthread_mutex_unlock(&m) 的退出路径
                                 # → MUST: code_context（lock/unlock 配对 + 退出路径标注）
                                 # → SHOULD: data_flow_path（获取→使用→释放）

同一函数内两次 pthread_mutex_lock(&m) 且中间无 unlock（非递归锁）
                                 # → MUST: judgment_rationale（两次 lock 行号 + mutex 类型）
                                 # → SHOULD: data_flow_path

pthread_mutex_lock(&m) 后存在 continue/break/goto 跳过对应 unlock
                                 # → MUST: code_context（跳转目标不在 unlock 之后）
                                 # → SHOULD: call_stack（如跨函数）

跨函数重复 lock：caller lock(m) → callee lock(m)（非递归锁）
                                 # → MUST: call_stack + 两次 lock 的调用链
                                 # → SHOULD: variable_state（mutex type）

pthread_mutex_unlock(&m) 时从未持有 m（unlock without lock）
                                 # → MUST: code_context（证明之前无 lock(m)）
                                 # → SHOULD: judgment_rationale（unlock 时的锁状态）

# EXCLUDE（不报告）
→ 所有退出路径上均存在对应的 unlock()（含 goto cleanup 汇聚）   # 锁配对完整
→ 使用 std::lock_guard / std::scoped_lock / std::unique_lock       # RAII 自动管理
→ mutex 类型为 PTHREAD_MUTEX_RECURSIVE 且 lock/unlock 计数匹配    # 递归锁合法可重入
→ 位于 test/ 或 *_test.c 文件                                     # 测试辅助代码
→ pthread_mutex_trylock 返回非零后不执行 unlock（未持锁）          # 未进入临界区
→ exit()/abort()/_exit() 前的 unlock 缺失                         # 进程终止时 OS 会清理
```

### 修复指引

1. **首选**（C++）：使用 `std::lock_guard<std::mutex>` 或 `std::scoped_lock`，利用 RAII 确保任何退出路径（包括异常）自动释放锁
2. **次选**（C）：采用 `goto cleanup` 模式，将所有退出路径汇聚到函数尾部，在 cleanup 处统一执行 `pthread_mutex_unlock(&m)`
3. **最低要求**：在每个 return/break/continue/goto 之前显式调用 `pthread_mutex_unlock(&m)`，并添加注释说明配对关系。如使用递归锁，确保每次 lock 有对应次数的 unlock

---

## Scenario 2: 信号处理器中调用 lock 函数（CWE-479）

### 威胁定义

信号处理器中调用了非异步信号安全的函数（如 `pthread_mutex_lock`），在信号到达时如果程序正处于这些函数的执行中，可能造成死锁或数据损坏。POSIX 标准明确限定了信号安全函数列表。

**核心原则：信号处理器中只能调用 `write()`/`_exit()`/`signal()` 等 POSIX 明确列为 async-signal-safe 的函数，不得调用 `pthread_mutex_lock`。**

### 检测逻辑

**Step 1: 识别信号处理函数**

```c
signal(SIGINT, handler);
sigaction(SIGINT, &sa, NULL);
```

**Step 2: 检查信号处理函数内容**

**非信号安全的高危调用：**

```c
// BAD: 信号处理器调用 lock 导致死锁风险
pthread_mutex_t global_mtx = PTHREAD_MUTEX_INITIALIZER;

void sigint_handler(int sig) {
    pthread_mutex_lock(&global_mtx);  // BUG: 若信号发生在持有锁的线程中 → 死锁
    write_log("received SIGINT");
    pthread_mutex_unlock(&global_mtx);
}

// GOOD: 使用 sig_atomic_t 标志位
volatile sig_atomic_t g_shutdown = 0;

void sigint_handler(int sig) {
    g_shutdown = 1;              // 仅设置标志
    // 不调用任何非 async-signal-safe 函数
}
```

### 检测模式

```
# MATCH（触发检测）
signal(|sigaction(                              # → MUST: code_context（handler 函数体）
void.*handler.*int|void.*sig_handler             # 信号处理函数签名
→ pthread_mutex_lock(|pthread_mutex_trylock(    # handler 内调用 lock → 异步信号不安全
                                                # → MUST: judgment_rationale（说明非安全原因）

# EXCLUDE（不报告）
→ volatile sig_atomic_t =                       # POSIX 保证原子性，仅设置标志位
→ write(STDERR_FILENO|write(STDOUT_FILENO       # write() 在 POSIX async-signal-safe 清单中
→ _exit(                                         # _exit() 在信号安全清单中
→ handler 为空体或仅含 return                    # 无操作，无风险
```

### 修复指引

1. 只使用安全函数：`write()`/`_exit()`/`signal()`/`sig_atomic_t` 变量
2. 设置标志位模式：信号处理器仅设置 `volatile sig_atomic_t flag = 1`，主循环检查标志
3. 使用 signalfd (Linux) 或 kqueue (BSD) 替代信号处理器

---

## Scenario 3: 锁顺序反转导致的死锁（CWE-833）

### 威胁定义

两个或多个线程互相等待对方持有的锁，导致所有相关线程永久阻塞。在服务端程序中，死锁可导致整个服务不可用。本场景关注跨函数锁顺序反转问题。

**核心原则：多锁获取必须遵循全局一致的顺序，持锁期间不得调用外部回调。**

### 检测逻辑

**Step 1: 识别多锁获取**

```c
// 函数 A: lock(m1) → lock(m2) ← 顺序: m1, m2
// 函数 B: lock(m2) → lock(m1) ← 顺序: m2, m1 → 报告：顺序反转！
```

**Step 2: 锁顺序反转检测**

```c
// BAD: 锁顺序反转
// Thread A:
void transfer_a_to_b(struct account *a, struct account *b, int amt) {
    pthread_mutex_lock(&a->mtx);
    pthread_mutex_lock(&b->mtx);  // 顺序: a → b
    a->balance -= amt;
    b->balance += amt;
    pthread_mutex_unlock(&b->mtx);
    pthread_mutex_unlock(&a->mtx);
}

// Thread B:
void transfer_b_to_a(struct account *b, struct account *a, int amt) {
    pthread_mutex_lock(&b->mtx);
    pthread_mutex_lock(&a->mtx);  // 顺序: b → a（与上面相反）
    a->balance += amt;
    b->balance -= amt;
    pthread_mutex_unlock(&a->mtx);
    pthread_mutex_unlock(&b->mtx);
}

// GOOD: 按地址排序强制一致顺序
void transfer(struct account *from, struct account *to, int amt) {
    pthread_mutex_t *first  = &from->mtx < &to->mtx ? &from->mtx : &to->mtx;
    pthread_mutex_t *second = &from->mtx < &to->mtx ? &to->mtx : &from->mtx;
    pthread_mutex_lock(first);
    pthread_mutex_lock(second);
    from->balance -= amt;
    to->balance += amt;
    pthread_mutex_unlock(second);
    pthread_mutex_unlock(first);
}
```

**Step 3: 持锁期间调用外部函数检测**

```c
lock(m);
callback(user_fn);  // user_fn 可能尝试 lock(m) → 重入/死锁
unlock(m);
```

### 检测模式

```
# MATCH（触发检测）
# func_a: lock(A) → lock(B)
# func_b: lock(B) → lock(A)     ← 跨函数锁顺序反转
                                 # → MUST: code_context（两个函数的锁序列）
                                 # → MUST: judgment_rationale（锁依赖图+循环环）

pthread_mutex_lock(&m1)
→ callback|user_fn|函数指针(     # 持锁期间调用外部代码
→ 回调中 pthread_mutex_lock(&m1) # ← 潜在重入/死锁
                                 # → SHOULD: call_stack（加锁→回调→反向加锁）

# EXCLUDE（不报告）
→ std::scoped_lock|std::lock(    # C++17/11 死锁避免算法（同时获取）
→ PTHREAD_MUTEX_RECURSIVE        # 声明式递归锁
→ pthread_mutex_trylock.*!=\s*0.*pthread_mutex_unlock(已有锁)  # trylock失败+回退
→ 整个函数仅一个 mutex 操作      # 单锁无循环等待条件
→ __attribute__((constructor))|main(.*{[^}]*pthread_create  # 单线程初始化阶段
```

### 修复指引

1. **统一锁顺序**：所有代码路径按相同顺序获取多把锁（如始终先 m1 后 m2）
2. **C++17**：使用 `std::scoped_lock(m1, m2, m3)` 自动避免死锁
3. **减少持锁范围**：不在锁内调用外部/未知代码
4. **使用 try_lock 模式**：尝试获取，失败则释放已有锁后重试

---

## Worker 检视协议

### Step 1: 信号确认

参考本文档 [Scenario 1](#scenario-1-锁获取释放配对不完整cwe-667)、[Scenario 2](#scenario-2-信号处理器中调用-lock-函数cwe-479)、[Scenario 3](#scenario-3-锁顺序反转导致的死锁cwe-833) 的检测逻辑。
通过 `symbols.functions` 定位 `pthread_mutex_lock` / `pthread_mutex_unlock` 出现的位置。优先直接读取 `lock_graph.mutexes` 获取预解析的 lock/unlock 配对数据。

### Step 2: 证据链（Source→Propagate→Sink）

按场景分类处理信号，检查以下五种误用模式：

| 信号模式 | 所属场景 | 证据链构建 |
|---------|---------|-----------|
| 未匹配的 lock/unlock | Scenario 1 | 函数内 lock 后所有退出路径的 unlock 存在性 |
| double-lock（非递归锁） | Scenario 1 | 同一 mutex 连续两次 lock 且中间无 unlock |
| unlock without lock | Scenario 1 | unlock 调用前未对应 lock |
| signal-handler 中的 lock | Scenario 2 | 信号处理函数体中的 lock 调用 |
| lock order inversion | Scenario 3 | 跨函数多个 mutex 的获取顺序一致性 |

### Step 3: 参数审计

参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

每个 lock/unlock 调用的参数检查：
- mutex 指针有效性（非 NULL）
- 是否对同一个 mutex 变量进行操作（lock 和 unlock 引用同一地址）
- `pthread_mutex_trylock` 的返回值是否被检查（`trylock` 可能返回 `EBUSY`）

### Step 4: 跨函数补证（max depth 1）

参考 [cross-function.md](references/cross-function.md) 跨函数追踪规则。

通过 `call_graph.edges` 查调用图：
- 如果 lock 函数调用另一个函数（callee 也操作同一 mutex）→ 检查 callee 是否持有锁
- 如果 unlock 函数被包装 → 检查所有 caller 是否都正确地先 lock 后 unlock
- 如果 lock/unlock 跨函数边界（lock 在 foo, unlock 在 bar）→ 标记但 confidence: medium（可能是有效 RAII 或状态机）

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 `cross_signal_analysis: true`

### Step 5: 事实锚定反思（3 问判定矩阵）

参考 [exceptions.md](references/exceptions.md) 确认边界情况。
参考 [false-positive.md](references/false-positive.md) 触发抑制。

必须回答 3 个域专用事实问题，答案必须基于源码证据链中的行号引用。

**Q1**: 所有退出路径都有 unlock?
**Q2**: 存在 unlock 调用?
**Q3**: 子函数能释放此锁?

判定矩阵规则：
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：包含 lock/unlock 操作的完整函数体，标注每对 lock→unlock 及所有退出路径的解锁状态；对 Scenario 2 须包含信号处理函数的完整代码体；对 Scenario 3 须包含涉及死锁风险的所有函数的完整加锁/解锁序列
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：具体列出缺少 unlock 的退出路径（行号 + 退出方式），或 double lock 的两个 lock 位置（行号 + 是否递归锁），说明死锁/行为未定义的后果；对 Scenario 3 须绘制锁依赖图（Lock Dependency Graph），标注循环等待环
      → `findings.evidence.judgment_rationale`

### 建议收集（SHOULD）
- [ ] **data_flow_path**：mutex 获取 → 临界区操作 → 释放的完整执行路径，标注每条分支的 lock/unlock 状态
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当锁操作跨函数时（如 caller lock → callee 再次 lock），追踪完整调用链；对 Scenario 2 追踪 signal/sigaction 注册点 → handler 的调用链；对 Scenario 3 追踪各加锁函数的完整调用路径以及持锁期间调用的外部/回调函数
      → `findings.evidence.call_stack`

### 可选收集（MAY）
- [ ] **variable_state**：锁的当前状态（已锁定/未锁定）、锁类型（普通/递归/读写锁）、持锁线程信息、各线程当前的锁持有集合、信号处理函数中修改的全局变量列表
      → `findings.evidence.variable_state`
- [ ] **sanitizer_analysis**：ThreadSanitizer (TSan)、Helgrind 报告，或编译时 `-fsanitize=thread` 检测标志启用情况；是否使用 `PTHREAD_MUTEX_ERRORCHECK` 检测重入
      → `findings.evidence.sanitizer_analysis`

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {
      "description": "pthread_mutex_lock(&d->mtx) 在函数入口加锁",
      "file": "src/worker.c",
      "line": 25
    },
    "propagate": {
      "description": "错误路径 return -1 跳过 pthread_mutex_unlock",
      "file": "src/worker.c",
      "line": 28
    },
    "sink": {
      "description": "d->mtx 在函数返回后仍处于锁定状态，其他线程永久阻塞",
      "file": "src/worker.c",
      "line": 28
    }
  },
  "scenario": "Scenario 1: 锁获取/释放配对不完整",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```

### 场景标注

| 场景 | evidence_chain.scenario 值 | 典型证据类型 |
|------|--------------------------|-------------|
| Scenario 1 | `Scenario 1: 锁获取/释放配对不完整` | code_context + judgment_rationale + data_flow_path |
| Scenario 2 | `Scenario 2: 信号处理器中调用 lock 函数` | code_context + judgment_rationale + call_stack |
| Scenario 3 | `Scenario 3: 锁顺序反转导致的死锁` | code_context + judgment_rationale + call_stack |
