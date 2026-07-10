---
name: secguard-cpp
description: 对 C/C++ 代码进行安全加固检视，编排 15 个子 skill，覆盖 API 调用检测、语义模式匹配、契约验证 (must-check/ownership) 等多个维度。当用户请求 C/C++ 安全扫描、内存安全检测、缓冲区溢出、C++ 代码审计、指针安全时使用。
category: language-specific
language: cpp
topic: [memory, concurrency, system, io, security, semantics]
---

# C/C++ 安全加固排查 — 检视算子索引

本文件是 `skills/secguard-cpp/` 下 15 个检视算子 skill 的主索引 / 派发表。
每个算子对应 `rules/` 下的一个规则目录，包含自己的 `rule.md` + `references/`。

> **执行流程由 `commands/claude/secguard.md` 的 Dispatcher 协议调度。**
> 本文件只做三件事：(1) 查表选 skill；(2) 按信号分类；(3) 引用 Dispatcher。

---

## 1. 检视算子一览

| # | Rule (目录名) | Severity | CWE | `signal_source` | `id` | Status |
|---|---------------|----------|-----|-----------------|------|--------|
| 1 | [`buffer_overflow/`](./rules/buffer_overflow/) | 🔴 Critical | CWE-120 | `call_sites[cat="string", cat="memory"]` | `memory.buffer-overflow` | ✅ |
| 2 | [`null_dereference/`](./rules/null_dereference/) | 🔴 Critical | CWE-476 | `call_sites[cat="memory"]` | `memory.null-dereference` | ✅ |
| 3 | [`memory_leak/`](./rules/memory_leak/) | 🟠 High | CWE-401 | `call_sites[cat="memory"]` | `memory.memory-leak` | ✅ |
| 4 | [`double_free/`](./rules/double_free/) | 🔴 Critical | CWE-415 | `call_sites[cat="memory"]` | `memory.double-free` | ✅ |
| 5 | [`use_after_free/`](./rules/use_after_free/) | 🔴 Critical | CWE-416 | `call_sites[cat="memory"]` | `memory.use-after-free` | ✅ |
| 6 | [`integer_overflow/`](./rules/integer_overflow/) | 🔴 Critical | CWE-190 | `call_sites[cat="memory"]` | `memory.integer-overflow` | ✅ |
| 7 | [`resource_leak/`](./rules/resource_leak/) | 🟠 High | CWE-404 | `call_sites[cat="io"]` | `resource.resource-leak` | ✅ |
| 8 | [`command_injection/`](./rules/command_injection/) | 🔴 Critical | CWE-78 | `call_sites[cat="exec"]` | `injection.command-injection` | ✅ |
| 9 | [`input_validation/`](./rules/input_validation/) | 🟠 High | CWE-20 | `call_sites[cat="exec"]` | `validation.input-validation` | ✅ |
| 10 | [`hardcoded_secrets/`](./rules/hardcoded_secrets/) | 🟠 High | CWE-798 | `call_sites[cat="crypto"]` | `crypto.hardcoded-secrets` | ✅ |
| 11 | [`must_check/`](./rules/must_check/) | 🟠 High | CWE-252 | `call_sites[cat="memory\|io"]` | `memory.must-check` | ✅ |
| 12 | [`mismatched_free/`](./rules/mismatched_free/) | 🟠 High | CWE-762 | `call_sites[cat="memory"]` | `memory.mismatched-free` | ✅ |
| 13 | [`api_semantic_misuse/`](./rules/api_semantic_misuse/) | 🟠 High | CWE-628 | `call_sites[cat="*"]` | `semantics.api-semantic-misuse` | ✅ |
| 14 | [`lock_misuse/`](./rules/lock_misuse/) | 🟠 High | CWE-667 | `call_sites[cat="concurrency"]` | `concurrency.lock-misuse` | ✅ |
| 15 | [`error_propagation/`](./rules/error_propagation/) | 🟡 Medium | CWE-390 | `call_sites[cat="error"]` | `error.error-propagation` | ✅ |

**Status**: 全部 15 个 skill 已完成实现，含事实锚定反思 + 多信号归并协议。

**按严重度排序执行**:

```
Critical (6)  → High (8)  → Medium (1)
```

---

## 2. 信号源分类 → Skill 映射

`index.json` 的 `call_sites[].category` 字段决定触发哪些算子：

| call_sites Category | 触发的 Skill 目录 | 信号函数（示例） |
|--------------------|------------------|-----------------|
| `"memory"` | `buffer_overflow`, `null_dereference`, `memory_leak`, `double_free`, `use_after_free`, `integer_overflow`, `must_check`, `mismatched_free` | `malloc`, `free`, `strcpy`, `strcat`, `sprintf`, `memcpy`, `gets` |
| `"string"` | `buffer_overflow` | `strcpy`, `strcat`, `sprintf`, `snprintf`, `gets`, `memcpy` |
| `"io"` | `resource_leak`, `must_check` | `fopen`, `open`, `socket`, `accept`, `fclose`, `close`, `fread`, `fwrite` |
| `"exec"` | `command_injection`, `input_validation` | `system`, `popen`, `exec*`, `fork` |
| `"crypto"` | `hardcoded_secrets` | `DES_set_key_unchecked`, `RAND_bytes`, `EVP_*`, `openssl/*` |
| `"concurrency"` | `lock_misuse` | `pthread_mutex_lock`, `pthread_mutex_unlock`, `lock_guard` |
| `"error"` | `error_propagation` | 函数返回错误码后被忽略的路径 |
| `"*"` | `api_semantic_misuse` | `realloc(p,0)`, `memmove` overlap, `snprintf` ignored return, `sizeof(ptr)` vs `sizeof(*ptr)` |
| `"memory\|io"` | `must_check` | 分配 & IO 函数的返回值检查 |

---

## 3. 信号 → Skill 派发逻辑

C/C++ 使用**符号表精确匹配**预筛（区别于 OO 语言的全量加载）：

```
对 index.json.call_sites 中的每条记录:
  1. 遍历 call_sites:
     - 按 category 匹配「信号源分类 → Skill 映射」(§2)
     - 若 category 命中多个 skill → 全部加入候选集
  2. 对候选集逐个 skill:
     - 从 index.json.symbols.functions 查询该 skill 声明的 callee 列表
     - callee 存在于符号表中 → 激活（读取 `rules.md` 检测规则）
     - callee 不存在 → 跳过（记录 "Skipped: no matching symbol"）
  3. 补充信号源（不依赖 call_sites）:
     - alloc_free.pairs → 内存类 skill（memory_leak, double_free, use_after_free）
     - lock_graph.mutexes → lock_misuse
  4. 排序: Critical → High → Medium（按 §1 表）
  5. 执行: 依序读取 skill `rules.md` → 执行检视协议 → `record-finding.py`
```

**alloc_free.pairs 补充触发**:

即使 call_sites 中无显式 free/delete 调用，`alloc_free.pairs` 中不平衡的分配/释放对也会触发：
- pair 无 `free_sites[]` → `memory_leak`
- `free_sites[].length > 1` → `double_free`
- 释放后同行再引用 → `use_after_free`

---

## 4. 执行流程（引用 Dispatcher 协议）

> **完整执行流水线见 [`commands/claude/secguard.md`](../../../commands/claude/secguard.md)。**
> 此处仅摘要与 skill 派发相关的步骤：

| Step | 职责 | 归属层 |
|------|------|--------|
| Step 1 | 初始化 + 索引构建 | Command |
| Step 2 | 读取 index.json（symbols / call_graph / alloc_free / lock_graph） | Command |
| Step 2.5 | 脱敏 + 扫描范围确定 | Command |
| Step 3a-3c | 语言匹配 + filter 裁剪 + 预筛 | Command |
| **Step 3c.5** | **C/C++ 符号表精确匹配 → 激活候选 skill** | **Skill (本文件 §3)** |
| **Step 3d** | **加载激活 skill 的 SKILL.md → 执行检视协议** | **Skill (各算子目录)** |
| Step 3.5 | 三轮验证管道（P1-P3） | Command |
| Step 4 | record-finding.py 持久化 + render-report.py | Command |
| Step 5 | 输出摘要 | Command |

各算子的检视协议遵循统一的 6 步模式：

1. **信号确认** — 验证 callee 真实存在（排除注释/宏/条件编译）
2. **证据链构建** — Source → Propagate → Sink 数据流追踪
3. **参数审计** — 按 callee 类型执行差异化检查
4. **跨函数补证** — 深度 1（超出降级为 suspicious）
4.5 **多信号归并** — 同一函数的多个信号聚合分析（如 line53 memcpy 安全的 + line60 memcpy 危险 → 整合分析）
5. **事实锚定反思** — 3 个域专用 Yes/No 事实问题 + 判定矩阵（替代旧 5 轮反思）

### 域专用 Q Schema（每个 skill 在 SKILL.md 中定义各自的 Q1-Q2-Q3）

判定矩阵规则：
- **三绿灯**（Q1=Yes, Q2=Yes, Q3=Yes，且全安全）→ SUPPRESS
- **两绿灯+单黄灯**（大概率安全，有条件抑制）→ downgrade to informational
- **两红灯+单绿灯**（大概率确认）→ CONFIRMED
- **三红灯**（全否定）→ CONFIRMED
- **混合模式**（Yes/No 不一致）→ 强制详细分析

### 与旧 5 轮反思的区别

| 方面 | 旧（5 轮反思） | 新（事实锚定反思） |
|------|---------------|-------------------|
| 调用次数 | 5 轮 LLM 调用 | 1 轮 LLM 调用 |
| 收敛性 | 同 LLM 同上下文 → 同质化结论（已被实验证伪） | 事实锚定问题迫使从不同角度检查 |
| 防遗漏 | 依赖 LLM 主动性 | 每个域有专用问题（如密钥初始化?）强制检查 |
| Δ 值 | Test C 证明 5 轮反射遗漏密钥初始化问题 | Test C 中 Q2 直接发现密钥未初始化 |

---

## 5. 参考文件

| 文件 | 内容 |
|------|------|
| [`references/cpp-security-cheatsheet.md`](./references/cpp-security-cheatsheet.md) | 快速参考：Top 10 信号 + 安全替代函数 |
| [`references/examples/`](./references/examples/) | CWE 示例代码片段 |
| [`references/language-features.md`](./references/language-features.md) | 自定义分配器识别、编译器标志、C++ 特定问题 |
