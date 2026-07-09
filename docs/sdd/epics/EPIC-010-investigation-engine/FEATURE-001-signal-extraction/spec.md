# FEATURE-001: Signal Extraction Dispatcher

> **Epic**: EPIC-010 (Investigation Engine)
> **对标 Guide**: Phase 1 — Dispatcher 重构 (§4)
> **状态**: Spec Draft
> **创建**: 2026-07-09

---

## 1. 问题陈述

当前的 Dispatcher（在各命令的 `secguard.md`/`secaudit.md`/`secreview.md` 中实现）做三件事：

1. 解析用户输入（`/secguard ./src cpp`）
2. 运行索引器获取上下文
3. **选择 Skill 并分派给 Worker**

第 3 步是核心问题。Dispatcher 在分派阶段就做了漏洞类型的假设——选择 `buffer_overflow` Skill 意味着 "我认为这个项目中存在 buffer overflow 漏洞"。

这导致三个问题：

1. 过早锁定推理方向（只查一种漏洞，不管其他类型）
2. Signal 被直接映射为 Conclusion（`malloc` → "可能是 null dereference"）
3. 无法跨 Skill 推理（整数溢出和 buffer overflow 在独立 Skill 中，不会联合调查）

---

## 2. 设计目标

| ID | 目标 | 度量 | 优先级 |
|----|------|------|--------|
| DG-01 | Dispatcher 不判定漏洞类型 | Dispatcher 输出是 Signal + 上下文，不是 Skill 选择 | P0 |
| DG-02 | Dispatcher 禁止 Suppress/Confirm | Dispatcher 协议中无 Suppress/Confirm 操作 | P0 |
| DG-03 | Dispatcher 禁止限制调查方向 | Dispatcher 不指定"只看什么漏洞" | P0 |
| DG-04 | Dispatcher 提供完整上下文 | 包括调用图、符号表、alloc/free 配对、锁图、源码上下文字段 | P0 |
| DG-05 | Signal 是调查入口，不是结论 | 新的 Signal schema 不含 `category` 字段 | P0 |
| DG-06 | 三命令一致 | secguard/secaudit/secreview 使用同一 Signal 输出格式 | P1 |

---

## 3. 需求规格

### REQ-001: Signal 数据结构重定义

当前（旧）Signal 格式：

```json
{
  "callee": "malloc",
  "category": "memory",
  "safe_variant": true,
  "file": "src/main.c",
  "line": 42
}
```

新 Signal 格式：

```json
{
  "signal_id": "sig-001",
  "type": "memory_allocation",
  "callee": "malloc",
  "callee_signature": "void* malloc(size_t size)",
  "file": "src/main.c",
  "line": 42,
  "args": [
    {"name": "size", "value": "256", "resolved": true}
  ],
  "context": {
    "function": "handle_request",
    "function_line": 30,
    "source_before": "  // ...\n  int len = parse_len(data);",
    "source_after": "  if (!ptr) return -1;\n  // ..."
  },
  "prescreen_verdict": "unknown",
  "prescreen_reason": ""
}
```

**关键变化**：

- 删除 `category` 字段（Dispatcher/Worker 不再有漏洞类型预判）
- 删除 `safe_variant` 布尔值（改为 `prescreen_verdict: safe/unknown`）
- 新增 `signal_id`（跨假设追踪）
- 新增 `callee_signature`（帮助 Investigator 理解 API）
- 新增 `args`（参数值 + 是否可解析）
- 新增 `context`（函数名 + 源码上下文，Investigator 不需要额外读源码）
- Signal `type` 只描述操作类型，不暗示漏洞: `memory_allocation`、`memory_copy`、`string_copy`、`user_input`、`lock_operation`

### REQ-002: Dispatcher 输出变更

当前 Dispatcher 输出：

```
Dispatched Skill:
  - secguard/cpp/buffer_overflow
  - secguard/cpp/null_dereference
```

新 Dispatcher 输出：

```
Signal Summary:
  - Memory Allocation: 47 signals (malloc, calloc, realloc)
  - Memory Copy: 312 signals (memcpy, memcpy_s, memmove)
  - String Copy: 554 signals (strcpy, strcpy_s, strncpy, snprintf)
  - User Input: 23 signals (getenv, scanf, fgets)
  - Lock Operation: 89 signals (pthread_mutex_lock, pthread_mutex_unlock)
  - Exec: 5 signals (system, popen, execvp)

Total Signals: 1030 (after prescreen: ~150 suspect + unknown)
```

### REQ-003: Pipeline Owner 转移

Dispatcher 不再拥有 Pipeline。Pipeline Ownership 转移到 **Hypothesis Generator + Investigator Pool**。

| 当前 | 新 |
|------|-----|
| Dispatcher 选择 Skill | Dispatcher 输出 Signal |
| Skill 拥有 Worker Pipeline | Hypothesis Generator 创建 Hypothesis |
| Worker 验证 Rule | Investigator 拥有调查 Pipeline |

### REQ-004: 错误信号示例定义

在命令中显式写入 Guide §4 的错误/正确示例：

错误示例：

```
malloc → Null Dereference Skill
memcpy → Buffer Overflow Skill
```

正确示例：

```
malloc → Signal(memory allocation)
memcpy → Signal(memory copy)
```

### REQ-005: 上下文完整性

Dispatcher 必须提供 Investigator 不需要额外读源码的上下文量：

- 每个 Signal 至少 ±3 行源码上下文
- 每个 Signal 关联的 function 必须有索引器中的完整信息
- Dispatcher 可选的上下文扩展：调用链（caller → callee）、数据流片段

### REQ-006: 命令范围

| 命令 | 当前行为 | 新行为 |
|------|---------|--------|
| `/secguard` | 分派 Skill + Worker 执行 | 输出 Signal → 走完整 Investigation Pipeline |
| `/secaudit` | 分派 Audit Rule + 逐条审计 | 输出全量 Signal → Hypothesis Generator 按审计深度运行 |
| `/secreview` | 分派 Code Review Skill | 同上，但 Hypothesis 聚焦 PR 变更 |

---

## 4. 设计方案

### 4.1 新 Architecture Flow

```
User Input  →  Indexer  →  Signal Extraction  →  Hypothesis Generator
                                                      ↓
                                          Investigator Pool (每个 Hypothesis 一个)
                                                      ↓
                                          Evidence + Counter Evidence
                                                      ↓
                                                   Judge
                                                      ↓
                                                 Finding
```

### 4.2 Dispatcher 命令文件结构

新 `secguard.md` 结构：

```
1. 前置检查（索引器 health、路径验证）
2. 建立索引（secguardian-index --path ... --output ...）
3. 信号提取（读取 index.json → 分类 → 添加上下文）
4. 输出 Signal Summary → 交给 Hypothesis Generator（在 SKILL.md 中）
5. Investigator → Evidence → Counter → Judge（在 SKILL.md 中）
6. 渲染输出（render-report.py）
```

Step 1-3 是 Dispatcher 的职责。
Step 4-5 是 Investigation Pipeline 的职责（FEATURE-003 中详细定义）。

### 4.3 Signal Type 映射

当前 indexer 的 `knownLibFuncs` 匹配到 Signal Type 的映射：

| Indexer 发现 | Signal Type | 示例 |
|-------------|------------|------|
| malloc/calloc/realloc | memory_allocation | malloc(256) |
| memcpy/memmove/memcpy_s | memory_copy | memcpy(dst,src,n) |
| strcpy/strcat/sprintf/gets | string_copy | strcpy(dst,src) |
| getenv/scanf/read/recv | user_input | getenv("PATH") |
| pthread_mutex_lock/spin_lock | lock_operation | mutex_lock(&m) |
| system/popen/exec | exec_operation | system(cmd) |
| free/delete | memory_deallocation | free(ptr) |
| fopen/open/socket/connect | resource_acquire | fopen(path,"r") |

---

## 5. 风险与约束

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 删除 category 后 Investigator 失去线索 | 高 | 高 | Investigator 不靠 category 查——靠自己生成 Hypothesis |
| 源码上下文增加 JSON 体积 | 中 | 低 | 每 Signal ~300 bytes，150 个 ~45KB |
| Signal 数量仍然很大 | 中 | 中 | 这是 FEATURE-003 的问题——Hypothesis Generator 负责 |

---

## 6. 范围边界

| 不包含 | 理由 |
|--------|------|
| Hypothesis Generator 实现 | FEATURE-003 的职责 |
| Investigator 框架 | FEATURE-003 的职责 |
| Judge 实现 | FEATURE-003 的职责 |
| Evidence Graph schema | FEATURE-004 的职责 |
| 全部 Rule 瘦身 | FEATURE-002 的职责 |
| 全部 Skill 重构 | FEATURE-002 的职责 |
| Go 代码修改 | Dispatcher 是 Prompt 重构，不涉及索引器代码 |
