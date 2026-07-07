---
name: secguard-cpp-lock-misuse
description: "Detect unmatched lock/unlock pairs, double-lock, unlock-before-lock, and signal-handler deadlock risks in pthread mutex usage"
category: language-specific
language: cpp
topic: [concurrency]
signal_source: call_sites[category="sync"]
---

# 锁误用检视算子

## 元数据

- id: concurrency.lock_misuse
- severity: high
- cwe: CWE-667
- category: sync
- signal_source: call_sites[category="sync"]

## 信号预筛

- callee 匹配: pthread_mutex_lock, pthread_mutex_unlock, pthread_mutex_trylock, pthread_mutex_timedlock
- 分组: high priority (concurrency correctness)
- 辅助数据: index.json -> lock_graph.mutexes（预生成的 lock/unlock 位置对）

## 检视协议

### Step 1: 信号确认

通过 `symbols.functions` 定位 `pthread_mutex_lock` / `pthread_mutex_unlock` 出现的位置。优先直接读取 `lock_graph.mutexes` 获取预解析的 lock/unlock 配对数据。

### Step 2: 证据链 (Source→Propagate→Sink)

检查以下五种误用模式：

1. **未匹配的 lock/unlock**: 函数内 lock 后部分退出路径缺少 unlock
2. **double-lock**: 已持有的 mutex 上再次调用 lock（未提前 unlock）→ 当前线程死锁
3. **unlock without lock**: 对未持有的 mutex 调用 unlock → 未定义行为
4. **signal-handler deadlock**: 信号处理器中调用 lock → 若信号发生在同一线程持有锁期间则死锁
5. **lock order inversion**: 多个 mutex 在不同函数中以不同顺序获取 → 死锁风险

### Step 3: 参数审计

每个 lock/unlock 调用的参数检查：

- mutex 指针有效性（非 NULL）
- 是否对同一个 mutex 变量进行操作（lock 和 unlock 引用同一地址）
- `pthread_mutex_trylock` 的返回值是否被检查（`trylock` 可能返回 `EBUSY`）

### Step 4: 跨函数补证 (max depth 1)

通过 `call_graph.edges` 查调用图：
- 如果 lock 函数调用另一个函数（callee 也操作同一 mutex）→ 检查 callee 是否持有锁
- 如果 unlock 函数被包装 → 检查所有 caller 是否都正确地先 lock 后 unlock
- 如果 lock/unlock 跨函数边界（lock 在 foo, unlock 在 bar）→ 标记但 confidence: medium（可能是有效 RAII 或状态机）

### Step 5: 5 轮反思

1. lock 和 unlock 是否位于同一个函数的对称位置（如函数开头 lock，所有 return 前 unlock）？不对称时标 confidence: high。
2. double-lock 是否来自条件编译宏导致的重复展开？（如 `#ifdef DEBUG` 块内再加锁）→ 若明显是宏展开则 confidence: low。
3. unlock without lock 是否对应于 `pthread_mutex_trylock` 返回 EBUSY 后的错误路径？若 trylock 失败则不调用 unlock → 正确。
4. 信号处理器中调用 lock 是否可以证实该信号只能由其他线程触发（`pthread_kill`）而非本线程（`raise`/`alarm`）？无法证实时标记 high confidence。
5. lock order inversion 是否同一函数内获取多个锁且顺序一致？跨函数检查调用图是否构成环形依赖（如 A→B→C→A）。
