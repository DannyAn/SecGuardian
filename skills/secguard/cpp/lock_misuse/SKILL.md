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

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 所有退出路径都有 unlock?
**Q2**: 存在 unlock 调用?
**Q3**: 子函数能释放此锁?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

