# EPIC-009: LLM Reliability Engine — From Read-Driven to Protocol-Driven Detection

> **状态**: Draft
> **创建**: 2026-07-09
> **目标版本**: v0.19.0
> **来源**: Brainstorm 2026-07-09 — LLM 依赖陷阱 + stripped 设计失败 + 架构约束缺失

---

## 1. 问题陈述

### 1.1 生产扫描 0 findings（P0）

v0.18.0 扫描生产 C/C++ 项目 secfwd，索引器正确提取 1358 个信号，但 LLM 将所有信号标记为"(安全采样)"并全部抑制：

| 检测器 | 信号数 | 结果 |
|--------|-------|------|
| buffer_overflow | 866 | 全部(安全采样) |
| null_dereference | 412 | 全部(安全采样) |
| double_free | 53 | 全部(安全采样) |
| memory_leak | 27 | 全部(安全采样) |
| command_injection | 0 | 无信号（可能是匹配缺失） |
| hardcoded_secrets | 0 | 无信号 |

同时 demo 项目全部正常检出漏洞。

### 1.2 根本原因：架构设计假设错误

当前架构（docs/architecture/security-engine.md §2.4）设计假设：
> 索引器不独立检测漏洞——它只基于模式识别候选。语义分析是 LLM 的职责。

这个假设对 demo 项目成立（信号少、特征明显、数量级小），但对生产项目完全失效（信号数量大、同质性强、表面安全）。

**引擎是"阅读理解驱动"而非"协议驱动"：**

```
当前实际流程:
源码 → 索引器 → 866 raw signals → LLM 阅读理解 → 如果觉得"明显漏洞"就分析 → 否则短路
                                       ↑ 受注释、函数名、代码整洁度影响
                                       ↑ 866 个信号没有终止条件，必然走捷径

应该的流程:
源码 → 索引器 → 866 raw → 确定性预筛 → ~50 可疑 → LLM 对每个信号严格走 W1-W5 → 判定矩阵裁决
                        ↑ 不受注释影响           ↑ W5 三问是硬终止条件，不走完不行
```

根本问题链：

| 层 | 问题 | 后果 |
|----|------|------|
| 架构 | 索引器只做 pattern matching，不做语义分析 | 全部判定依赖 LLM |
| 索引器 | 不区分 `strcpy_s(dst,sizeof(dst),src)`（安全）和 `strcpy(dst,src)`（高危） | 866 个信号淹没 LLM |
| LLM | 面对大量同质信号批量推理而非逐条分析 | 全部被标记"安全采样" |
| 协议 | W5 判定矩阵可被跳过（LLM 决定不执行） | 引擎无终止条件 |
| 工具 | strip-answer-cards.py 无条件全量复制源码 | 几千个文件被拷贝 |

### 1.3 三个命令全部受害

| 命令 | 信号数（secfwd 估算） | 预计症状 |
|------|---------------------|---------|
| secguard | 1358 | 已确认：0 findings |
| secaudit | ~2000+（S1-S6 全信号） | 信号更多，问题更严重 |
| secreview | ~500+（控制流信号） | 稍好但本质相同 |

---

## 2. 设计目标

| ID | 目标 | 度量标准 | 优先级 |
|----|------|---------|--------|
| DG-01 | **消除批量抑制** | LLM 接收的信号量 ≤ 每 Batch 50，LLM 必须逐信号走 W1-W5 | P0 |
| DG-02 | **信号量可控** | 索引器预筛后，可疑信号数 ≤ 原始信号数的 20%（buffer_overflow 866→≤150） | P0 |
| DG-03 | **协议驱动非阅读驱动** | LLM 不能跳过 W1→W2→W3→W4→W5 任何一步 | P0 |
| DG-04 | **终止条件强制** | W5 判定矩阵必须执行，不得输出非终止状态 | P0 |
| DG-05 | **纯净输出** | 扫描产物不包含源码副本、临时文件 | P0 |
| DG-06 | **三命令一致** | secguard/secaudit/secreview 使用同一信号管道 | P1 |
| DG-07 | **架构约束可验证** | PB-01~PB-09 违规能被 CI 或代码结构发现 | P1 |

---

## 3. 需求规格

### REQ-001: 索引器预筛器模块

| 属性 | 值 |
|------|-----|
| 优先级 | P0 |
| 改动文件 | 新增 `internal/indexer/prescreener.go` |
| 依赖 | `internal/parser/types.go` (CallSite, Declaration, AllocFreePair) |

**行为**：索引器在完成信号提取后（Phase 2.5 in main.go），对 allCallSites 运行预筛器。预筛器对每个信号输出一个判定：

| 判定 | 含义 | 处理方式 |
|------|------|---------|
| `suspect` | 有足够证据表明此信号可疑 | 保留在 LLM 输入中 |
| `unknown` | 无法确定性判断 | 保留在 LLM 输入中（保守处理） |
| `safe` | 有足够证据表明此信号是安全的 | 从 LLM 输入中移除 |

**安全策略**：保守，只有高置信度的才能标记 safe。不确定的全部标记 unknown（保留给 LLM）。

### REQ-002: buffer_overflow prescreening

| 属性 | 值 |
|------|-----|
| 优先级 | P0 |
| 预期过滤 | 866→~100（~88% 降低） |
| 置信度 | 高 |

**预筛规则**：

当 call_site 满足以下**全部**条件时标记 safe：

1. callee 是 `strcpy_s`/`strcat_s`/`sprintf_s`/`memcpy_s`/`gets_s`/`snprintf`
2. 第一个参数（目标缓冲区）可以在 Declarations 中找到，且是 `ArraySize > 0` 的栈数组
3. 存在一个参数以 `sizeof(dst_name)` 形式出现
4. `sizeof(dst_name)` 的计算值 **等于** `Declarations[dst_name].ArraySize`
5. 源参数不是 `malloc()`/`calloc()` 的返回值（即不是同函数内动态分配）

判定：

| 条件 | safe | suspect |
|------|------|---------|
| 1-4 全满足 | ✅ | — |
| 条件 5 不满足（源是动态分配） | — | ✅ suspect |
| 目标缓冲区不在 Declarations 中（可能是全局/指针参数） | — | ✅ unknown |
| callee 是 unsafe 变体（strcpy/memcpy 无 _s） | — | ✅ suspect |

### REQ-003: null_dereference prescreening

| 属性 | 值 |
|------|-----|
| 优先级 | P1（第二阶段） |
| 预期过滤 | 412→~80 |
| 置信度 | 中 |

**预筛规则**：

当 call_site 满足以下**全部**条件时标记 safe：

1. callee 是 `malloc`/`calloc`/`realloc`
2. 其返回值被赋给一个变量 `ptr`
3. 同一函数内，在首次解引用 `ptr` **之前**，存在 `if (ptr == NULL) return;` 或 `if (!ptr) return;` 或 `if (ptr == NULL) goto cleanup;` 形式的 NULL 检查
4. 检查后的使用路径中使用了 `ptr`

**实现方法**：利用 parser_ts.go 的 AST 节点，在 `function_definition` 的 compound_statement 内搜索匹配模式。

判定：

| 条件 | safe | suspect |
|------|------|---------|
| 1-4 全部满足 | ✅ | — |
| 满足 1-2，无 NULL 检查 | — | ✅ suspect |
| 检查存在但在首次使用之后（延迟检查） | — | ✅ suspect |
| 检查是 `assert(ptr != NULL)` | — | ✅ suspect（assert 在 NDEBUG 下无效） |

### REQ-004: double_free prescreening

| 属性 | 值 |
|------|-----|
| 优先级 | P1（第二阶段） |
| 预期过滤 | 53→~15 |
| 置信度 | 中 |

**预筛规则**：

当 alloc_free.pairs 中的一条记录有多个 free_sites 时检查：

1. 两条 `free_sites` 记录
2. 它们之间（同一函数内）是否存在 `ptr = NULL` / `ptr = nullptr` 或重新赋值
3. 存在置 NULL → safe

### REQ-005: 废弃 strip-answer-cards.py

| 属性 | 值 |
|------|-----|
| 优先级 | P0 |
| 改动文件 | 删除 `scripts/strip-answer-cards.py` |

**实现方式**：

1. 将所有 demo 项目的源码转换为 no-answers 格式——删除 `// VULNERABILITY [CWE-xxx]`、`// BAD:`、`// TP-xx:` 等标注
2. 验证：对每个 demo 项目运行 `grep -r "VULNERABILITY\|// BAD:\|# BAD:"` 确保返回 0 匹配
3. 从 secguard.md/secaudit.md/secreview.md 中删除：
   - strip-answer-cards.py 调用步骤（Phase 1 的脱敏步骤）
   - `$STRIPPED_DIR` / `$STRIPPED_ROOT` 路径变量
   - 所有 strippe 相关约束
4. Worker 直接从用户源码目录读取

### REQ-006: 架构约束注入

| 属性 | 值 |
|------|-----|
| 优先级 | P1 |
| 改动文件 | AGENTS.md（新增 §架构约束 + §禁止行为） |

在 AGENTS.md 新增章节：
- **Architecture Invariants**（AC-01~AC-08）
- **Prohibited Behaviors**（PB-01~PB-09）

同时将 AC 和 PB 的关键条款嵌入到各命令协议文件中：
- `commands/*/secguard.md` — per_signal_analysis 强制
- `commands/*/secaudit.md` — 同上
- `commands/*/secreview.md` — 同上

### REQ-007: per_signal_analysis 协议强制

| 属性 | 值 |
|------|-----|
| 优先级 | P0 |
| 改动文件 | `commands/*/secguard.md`, `commands/*/secaudit.md`, `commands/*/secreview.md` |

每个 Blindspot/batch 的 blindspot.json 输出必须包含 `per_signal_analysis` 数组：

```json
{
  "blindsight": {
    "signal_count": 50,
    "per_signal_analysis": [
      {
        "index": 0,
        "callee": "strcpy_s",
        "file": "src/main.c",
        "line": 142,
        "prescreen_verdict": "safe",
        "prescreen_reason": "sizeof(dst)=64 matches char dst[64]"
      }
    ]
  }
}
```

Batch 的输出也必须包含且长度匹配信号数。Aggregator 在合并时检查完整性。

### REQ-008: C/C++ command_injection 信号缺失修复

| 属性 | 值 |
|------|-----|
| 优先级 | P1 |
| 类型 | 调查 + 修复 |

secfwd 扫描中 command_injection 信号为 0。可能是：
- knownLibFuncs 缺少匹配（如使用 `execvp`/`execl` 而非 `system`/`popen`/`exec`）
- 生产代码使用包装函数（如 `run_shell(cmd)` 而非 `system(cmd)`）
- parser 未匹配到 exec 类函数调用

需要调查 secfwd 源码后决定修复方案。

---

## 4. 范围边界

| 包含 | 不包含 |
|------|--------|
| buffer_overflow prescreening（Go 索引器） | memory_leak prescreening（需要完整 CFG，延后） |
| null_dereference prescreening | 跨函数数据流分析 |
| double_free prescreening | 跨文件类型继承分析 |
| strip-answer-cards.py 废弃 | 索引器超时保护（已在 EPIC-006） |
| per_signal_analysis 协议强制 | 非 C/C++ 语言的 prescreening |
| 三命令协议同步 | knownLibFuncs 扩充（单独 FEATURE） |
| 架构约束文档 + 嵌入 | BATCH_SIZE 动态调整 |

---

## 5. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| 预筛器假阴性（safe 标错了） | 低 | 高 | 保守策略：只有高置信度才标记 safe；所有 unknown 放行 |
| 预筛器假阳性（suspect 标错了） | — | 低 | 即使误标 suspect，W1-W5 仍会正常抑制 |
| 预筛器在 CI 中与测试预期不一致 | 中 | 中 | 测试覆盖边界情况：不定大小、动态分配、全局变量 |
| 废弃 stripped 后，有人恢复旧 demo 带答案卡 | 低 | 低 | CI 加 grep 检查禁止模式 |
| 三命令同步遗漏 | 中 | 中 | 每个协议修改必须三平台同步（见 Plan） |

---

## 6. 交付阶段

### Phase 1（v0.19.0）— 核心修复

| 交付物 | 对应 REQ | 工作量 |
|--------|---------|--------|
| buffer_overflow prescreening | REQ-002 | 3 天（含测试） |
| strip-answer-cards.py 废弃 | REQ-005 | 1 天 |
| per_signal_analysis 协议 | REQ-007 | 1 天 |
| 三命令协议同步 | REQ-006 (部分) | 1 天 |

### Phase 2（v0.19.x）— 扩展预筛 + 架构约束

| 交付物 | 对应 REQ | 工作量 |
|--------|---------|--------|
| null_dereference prescreening | REQ-003 | 3 天（含测试） |
| double_free prescreening | REQ-004 | 2 天（含测试） |
| 架构约束文档 | REQ-006 | 0.5 天 |
| command_injection 修复 | REQ-008 | 调查后定 |

### Phase 3（v0.20.0）— 跨命令适配

| 交付物 | 对应 REQ | 工作量 |
|--------|---------|--------|
| secaudit 适配新管道 | DG-06 | 2 天 |
| secreview 适配新管道 | DG-06 | 1 天 |
| memory_leak prescreening（可选） | 延后 | — |

---

## 7. 验证标准

| # | 验证项 | 命令 | 验证方法 |
|---|--------|------|---------|
| V-01 | buffer_overflow 预筛后信号 ≤ 原始 20% | `secguard ./src cpp` | 生产项目 secfwd 实测 |
| V-02 | Buffer overflow 预筛无假阴性 | `go test ./internal/indexer/...` | 已知 safe 和 unsafe 的测试用例全部通过 |
| V-03 | strip-answer-cards.py 已删除 | `ls scripts/strip-answer-cards.py 2>&1` | 返回无此文件 |
| V-04 | 无 demo 项目含答案卡 | `grep -r "VULNERABILITY\|// BAD:" examples/` | 0 匹配 |
| V-05 | 三命令协议无 stripped 引用 | `grep -r "stripped" commands/` | 0 匹配 |
| V-06 | LLM 接收信号量 | 生产项目实测 | 每一 Batch ≤ BATCH_SIZE |
| V-07 | per_signal_analysis 完整性 | Aggregator 检查 | 长度匹配信号数 |
| V-08 | 三命令全部通过 | /secguard, /secaudit, /secreview | demo 项目端到端验证 |
