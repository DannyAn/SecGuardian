---
detector: resource.lock-misuse
severity: high
cwe: CWE-667
language: [c, cpp]
tags: [resource, lock, mutex, pthread, deadlock, concurrency]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "resource.resource.lock-misuse",
  "type": "guard-rule",
  "namespace": "resource",
  "severity": "High",
  "cwe": "CWE-667",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "caller",
    "do_work",
    "guard",
    "helper",
    "lock",
    "pthread_mutex_lock",
    "pthread_mutex_unlock"
  ],
  "match_patterns": [
    "pthread_mutex_lock(&m) 后存在缺少 pthread_mutex_unlock(&m) 的退出路径",
    "同一函数内两次 pthread_mutex_lock(&m) 且中间无 unlock（非递归锁）",
    "pthread_mutex_lock(&m) 后存在 continue/break/goto 跳过对应 unlock",
    "跨函数重复 lock：caller lock(m) → callee lock(m)（非递归锁）"
  ],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

`pthread_mutex_lock`/`pthread_mutex_unlock`（或等效平台锁 API）的获取-释放配对不完整，映射 CWE-667（Improper Locking）。具体包括三种子类型：(a) **只锁不解**（lock without unlock）——任一路径缺少 unlock 导致其他线程永久阻塞；(b) **重复加锁**（double lock）——同一线程连续两次 lock 非递归互斥锁，造成自死锁；(c) **解锁未持有锁**（unlock without lock）——对未锁定或已释放的 mutex 调用 unlock，行为未定义（Pthreads 返回 EPERM，但程序逻辑已出错）。不同于 `concurrency.race-condition`（数据竞争）和 `concurrency.deadlock`（锁序死锁），本检测器聚焦于**单个锁对象的获取/释放配对完整性**。

## 检测逻辑 (Detection Logic)

### Step 1 — 定位锁操作点

在函数体内搜索 `pthread_mutex_lock()` / `pthread_mutex_unlock()`（以及各平台等价 API：`EnterCriticalSection`/`LeaveCriticalSection`、`mutex_lock`/`mutex_unlock`、`mtx_lock`/`mtx_unlock`），记录每个锁操作的 mutex 对象和行号。

### Step 2 — 配对分析

对每次 `lock(m)` 调用，在函数体内搜索下一个对同一 `m` 的 `lock()` 调用（——double lock 检测）以及对应的 `unlock(m)` 调用。构建 lock→unlock 配对，考虑所有退出路径（包括 `return`、`break`、`continue`、`goto`、C++ `throw`）。

### Step 3 — 逐路径验证

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

// BAD: 连续两次 lock 同一 non-recursive mutex（不同函数间）
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
}                                    // guard 析构自动 unlock
```

### Step 4 — 跨函数锁追踪

当锁操作分散在多个函数中时（如 `acquire_lock()` → `helper()` → `release_lock()`），追踪调用链确认配对完整性。标记通过函数边界传递的锁状态。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含 lock/unlock 操作的完整函数体，标注每对 lock→unlock 及所有退出路径的解锁状态
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：具体列出缺少 unlock 的退出路径（行号 + 退出方式），或 double lock 的两个 lock 位置（行号 + 是否递归锁），说明死锁/行为未定义的后果
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：mutex 获取 → 临界区操作 → 释放的完整执行路径，标注每条分支的 lock/unlock 状态
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当锁操作跨函数时（如 caller lock → callee 再次 lock），追踪完整调用链
      → `findings.evidence.call_stack`

### 可选收集 (MAY)
- [ ] **variable_state**：锁的当前状态（已锁定/未锁定）、锁类型（普通/递归/读写锁）、持锁线程信息
      → `findings.evidence.variable_state`
- [ ] **sanitizer_analysis**：ThreadSanitizer (TSan) 或 Helgrind 报告，提供运行时可验证证据
      → `findings.evidence.sanitizer_analysis`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| goto cleanup 统一释放 — 所有退出路径通过 goto 汇聚到 cleanup label 执行 unlock | `goto cleanup` 惯用法，cleanup 处包含 `pthread_mutex_unlock(&m)` | verify: 所有 goto 均指向包含 unlock 的 cleanup label，无跳过 cleanup 的路径 |
| RAII lock_guard / unique_lock — C++ 作用域守卫在析构时自动释放 | `std::lock_guard`/`std::unique_lock` 在作用域结束时自动调用 unlock，即使异常退出也保证释放 | 确认 lock_guard 对象生命周期覆盖整个临界区 |
| 递归锁 PTHREAD_MUTEX_RECURSIVE — 允许同一线程多次 lock | `pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)` 初始化的 mutex 支持可重入 lock，每次 lock 需对应一次 unlock | `pthread_mutex_init` 或属性设置代码确认 mutex type 为 RECURSIVE |
| trylock 非阻塞模式 — `pthread_mutex_trylock` 失败时不进入临界区 | trylock 返回非零时调用者不持锁，后续不应 unlock | 检查 trylock 返回值分支，失败路径不执行 unlock |

## 修复指引 (Remediation Guidance)

1. **首选**（C++）：使用 `std::lock_guard<std::mutex>` 或 `std::scoped_lock`，利用 RAII 确保任何退出路径（包括异常）自动释放锁。
2. **次选**（C）：采用 `goto cleanup` 模式，将所有退出路径汇聚到函数尾部，在 cleanup 处统一执行 `pthread_mutex_unlock(&m)`。
3. **最低要求**：在每个 return/break/continue/goto 之前显式调用 `pthread_mutex_unlock(&m)`，并添加注释说明配对关系。如使用递归锁，确保每次 lock 有对应次数的 unlock。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
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

# === EXCLUDE (不报告) ===
→ 所有退出路径上均存在对应的 unlock()（含 goto cleanup 汇聚）   # 锁配对完整
→ 使用 std::lock_guard / std::scoped_lock / std::unique_lock       # RAII 自动管理
→ mutex 类型为 PTHREAD_MUTEX_RECURSIVE 且 lock/unlock 计数匹配    # 递归锁合法可重入
→ 位于 test/ 或 *_test.c 文件                                     # 测试辅助代码
→ pthread_mutex_trylock 返回非零后不执行 unlock（未持锁）          # 未进入临界区
```
