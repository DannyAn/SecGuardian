---
detector: deadlock
severity: medium
cwe: CWE-833
language: [c, cpp]
tags: [concurrency, threading, lock-ordering]
precision: medium
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "concurrency.deadlock",
  "type": "guard-rule",
  "namespace": "concurrency",
  "severity": "Medium",
  "cwe": "CWE-833",
  "cvss": 5.5,
  "confidence": "dynamic",
  "precision": "medium",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "call_stack",
    "callback",
    "code_context",
    "judgment_rationale",
    "lock",
    "pthread_mutex_lock",
    "std",
    "unlock"
  ],
  "match_patterns": [
    "(pthread_mutex_lock|std::mutex.*lock|EnterCriticalSection)\\(&?\\w+\\)  # 锁获取",
    "pthread_mutex_init\\([^)]*NULL\\)                                        # 默认非递归"
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

两个或多个线程互相等待对方持有的锁，导致所有相关线程永久阻塞。在服务端程序中，死锁可导致整个服务不可用。

**核心原则：多锁获取必须遵循全局一致的顺序，持锁期间不得调用外部回调。**

## 检测逻辑 (Detection Logic)

### Step 1: 跨函数锁定顺序不一致 — 报告 (Inconsistent Lock Ordering)

```
// 函数 A: lock(m1) → lock(m2) ← 顺序: m1, m2
// 函数 B: lock(m2) → lock(m1) ← 顺序: m2, m1  → 报告：顺序反转！
```

### Step 2: 持锁期间调用外部函数 — 报告 (Lock-Holding Callback)

```
lock(m);
callback(user_fn);  // user_fn 可能尝试 lock(m) → 重入/死锁
unlock(m);
```

### Step 3: 不报告的场景 (Safe Patterns)

| 场景 | 原因 |
|------|------|
| `std::scoped_lock(m1, m2)` | C++17 死锁避免算法（同时获取） |
| `std::lock(m1, m2)` | C++11 死锁避免 |
| `pthread_mutex_trylock()` + 回退 | 非阻塞尝试，失败后释放已有锁 |
| `PTHREAD_MUTEX_RECURSIVE` 类型 | 允许同线程重入 |
| 单锁操作 | 一把锁不会造成死锁（但可能持锁时间过长） |

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：涉及死锁风险的所有函数的完整加锁/解锁序列，标注每个锁获取点的mutex变量名和获取顺序
      → findings.evidence.code_context
- [ ] **judgment_rationale**：绘制锁依赖图（Lock Dependency Graph），标注循环等待环中的节点（函数→锁→函数）以及形成死锁的四个必要条件均满足的论证
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：N/A — 死锁为时序逻辑错误，非数据流问题；关注控制流中的锁获取顺序而非数据流转
      → findings.evidence.data_flow_path
- [ ] **call_stack**：每个加锁函数 → 持锁期间调用的外部/回调函数 → 回调中可能的反向加锁路径
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：各 mutex 的类型（NORMAL/RECURSIVE/ERRORCHECK）、持锁线程 ID、各线程当前的锁持有集合
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用 ThreadSanitizer（-fsanitize=thread）、是否使用 `PTHREAD_MUTEX_ERRORCHECK` 检测重入
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **统一锁顺序**：所有代码路径按相同顺序获取多把锁（如始终先 m1 后 m2）
2. **C++17**：使用 `std::scoped_lock(m1, m2, m3)` 自动避免死锁
3. **减少持锁范围**：不在锁内调用外部/未知代码
4. **使用 try_lock 模式**：尝试获取，失败则释放已有锁后重试

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `std::scoped_lock` / `std::lock` 同时获取 | C++ 标准库使用 deadlock avoidance 算法（同时锁定或有序回退），不会形成循环等待 | 确认所有锁在同一个 scoped_lock/lock 调用中获取 |
| `PTHREAD_MUTEX_RECURSIVE` | 递归锁允许同一线程重复获取，消除了同线程重入死锁条件 | 确认 pthread_mutexattr_settype 设置为 PTHREAD_MUTEX_RECURSIVE |
| `pthread_mutex_trylock` 失败后释放已有锁 | 非阻塞模式 + 回退策略避免了"持有并等待"条件 | 确认 trylock 失败分支中有 unlock 已持有的锁并重试逻辑 |
| 单锁或无锁代码 | 死锁需要至少两把锁形成循环等待，单锁不存在此条件 | 确认代码路径中仅操作一个 mutex |
| 初始化阶段（单线程） | 无并发竞争，不可能发生死锁 | 确认代码在 main() 启动阶段、无其他线程创建前执行 |
| 锁顺序有显式文档且已验证 | 团队编码规范强制统一锁顺序，并经代码审查验证 | 确认存在锁顺序文档（如注释 "Always lock A before B"）且所有路径遵循 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 不同函数中锁获取顺序反转（需跨函数分析）
# func_a: lock(A) → lock(B)
# func_b: lock(B) → lock(A)    ← 报告：顺序反转
                                 # → MUST: code_context (两个函数的锁序列)
                                 # → MUST: judgment_rationale (锁依赖图+循环环)

# 持锁回调
(pthread_mutex_lock|std::mutex.*lock|EnterCriticalSection)\(&?\w+\)  # 锁获取
→ 同一函数内调用: 函数指针|虚函数|外部回调|callback|fn\(             # 持锁期间调用外部代码
→ (回调中同锁): lock(同一变量)                                        # ← 潜在重入/死锁
                                                                      # → SHOULD: call_stack (加锁→回调→反向加锁)

# 普通 mutex 递归获取
pthread_mutex_init\([^)]*NULL\)                                        # 默认非递归
→ 函数内再次 pthread_mutex_lock(同一 mutex)                           # 重入非递归锁 → 死锁

# === EXCLUDE (不报告) ===
→ std::scoped_lock|std::lock\(                                         # C++17/11 死锁避免算法
→ PTHREAD_MUTEX_RECURSIVE                                              # 声明式递归锁
→ pthread_mutex_trylock.*!=\s*0.*pthread_mutex_unlock\(已有的锁\)      # trylock失败 + 回退
→ 整个函数仅一个 mutex 操作                                            # 单锁无循环等待
→ __attribute__\(\(constructor\)\)|main\(.*{[^}]*pthread_create        # 单线程初始化阶段
```
