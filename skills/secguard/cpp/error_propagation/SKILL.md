---
name: secguard-cpp-error-propagation
description: "Detect silently ignored error returns — fopen NULL consumed, malloc unchecked, unwrapped failure-returning calls in void context"
category: language-specific
language: cpp
topic: [contract]
signal_source: call_sites[category="*"]
---

# 错误传播检视算子

## 元数据

- id: contract.error_propagation
- severity: medium
- cwe: CWE-390
- category: \* (all)
- signal_source: call_sites[category="\*"]

## 信号预筛

- callee 匹配: fopen, malloc, calloc, realloc, strdup, mmap, read, write, accept, connect, socket, open, close, fread, fwrite, fseek, ftell, fgets, fscanf, fgetc, pthread_create, pthread_mutex_lock, pthread_mutex_trylock
- 分组: medium priority (error handling correctness)
- 注意: 本检测器不是 call_site 驱动，而是**函数调用模式**驱动 — 在调用可能返回错误标志的函数时，检查后续代码是否在未验证返回值的情况下直接使用结果。

## 检视协议

### Step 1: 信号确认

扫描符号表中的以下模式（不分语言—适用于 C 和 C++）：

- **直接解引用**: `fopen()` → 返回值在 NULL 检查前就被 `fread()`/`fwrite()` 等使用
- **NULL 缺失检查**: `malloc()` → 返回值未经 NULL 检查就被解引用
- **void 上下文消耗**: 返回错误码的函数被调用在 void 上下文中（`func_returning_error();` 后无事）
- **链式调用缩短**: `if (!(fp = fopen(...)))` 安全；`fp = fopen(...); fclose(fp);` 不安全且会 crash

### Step 2: 证据链 (Source→Propagate→Sink)

对每个匹配的调用点，追踪：

1. **Source**: 错误返回函数（fopen, malloc 等）的调用位置
2. **Propagate**: 返回值是否经过了 NULL 判断、错误检查或 assert
3. **Sink**: 返回值被如何使用（解引用、传递给另一个函数、作为条件分支）

**检查矩阵**:

```
fp = fopen(...);           → Source
if (!fp) { ... }           → 这是正确的 Propagation（检查 NULL）
fp = fopen(...);           → Source
fread(buf, 1, n, fp);     → Sink — 未检查 fp 是否为 NULL（Sink 直接使用且无检查）

ptr = malloc(n);           → Source
*ptr = 0;                  → Sink — 未检查 ptr 是否为 NULL（直接解引用）

ret = write(fd, buf, n);   → Source（ssize_t 返回 < 0 表示错误）
(void)ret;                 → Sink — 返回值被显式丢弃（更差的模式）
```

### Step 3: 参数审计

对 Source 函数的参数语义进行检查：

- `fopen(path, mode)`: path 是否来自用户输入？如果不是则风险较低（但仍然需要 NULL 检查）
- `malloc(n)`: n 是否为 0 或极端值？如果 n 来自用户且可能很大，NULL 可能性更高
- `read(fd, buf, n)`: fd 有效性（来自 open 还是 socket？）

### Step 4: 跨函数补证 (max depth 1)

如果检测到调用点在该函数内直接使用返回值前缺乏检查，但上层 caller 在调用前已经验证了前置条件（传参前提是文件已打开、内存已分配），则 Step 4 可以补充证据。具体处理见 `references/cross-function.md`。

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 错误码被函数返回值正确传播（包括中间函数）?
**Q2**: 错误路径有日志/处理/清理?
**Q3**: 错误码不会被后续操作覆盖（多错误路径串联）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

