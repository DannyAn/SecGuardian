---
name: secguard-cpp-must_check
description: "Detect unchecked return values from allocation, I/O, and system functions"
category: language-specific
language: cpp
topic: [memory, io]
signal_source: call_sites[category="memory|io"]
---

# Must-Check 检视算子

## 元数据

- id: memory.must_check
- severity: high
- cwe: CWE-252
- category: memory + io
- signal_source: call_sites[category="memory|io"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: `malloc`, `calloc`, `realloc`, `fopen`, `socket`, `accept`, `setenv`, `snprintf`, `vsnprintf`, `fgets`, `fread`, `fwrite`, `read`, `write`, `mmap`, `reallocarray`
- 按信号分组: 优先处理分配函数（malloc/calloc/realloc），其次是 IO 函数（fopen/socket），最后是数据操作（snprintf/fread/fwrite）

## 检视协议

### Step 1: 信号确认
对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在于扫描范围内
3. 确认该函数属于已知的 must-check 函数集合

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: 分配/IO 函数的返回值
- Propagate: 返回值被赋给变量后，该变量在后续代码中是否被检查（NULL 比较、错误值比较、返回值检查）
- Sink: 未检查的返回值被直接用于解引用、条件分支或第二条语句执行 — 意味着返回值被丢弃或未验证

### Step 3: 安全变体参数审计
对每个预筛信号，按函数类型检查：

1. **分配函数（malloc/calloc/realloc/mmap/reallocarray）**:
   - 检查返回值是否立即与 NULL 比较: `if (ptr == NULL) return ERROR;`
   - 检查返回值是否立即用于解引用: `malloc(100)->field = 1;` // BAD
   - 对于 realloc: 检查是否使用了临时指针: `void *newptr = realloc(ptr, size); if (!newptr) ERROR;` // GOOD — `ptr = realloc(ptr, size);` 为分配失败时原指针泄漏

2. **IO 打开函数（fopen/socket/accept）**:
   - fopen: 检查返回值是否与 NULL 比较；是否 `if (!fp) return ERROR;`
   - socket/accept: 检查返回值是否与 `-1` 或 `INVALID_SOCKET` 比较；是否 `if (fd < 0) return ERROR;`

3. **snprintf/vsnprintf**:
   - 检查返回值是否与缓冲区大小比较: `if (n < sizeof(buf))` 确保输出完整
   - 仅检查 `n > 0` 不够 — 应检查 `n >= sizeof(buf)` 表示截断

4. **fgets**:
   - 检查返回值是否与 NULL 比较: `if (!fgets(buf, size, fp)) return;`
   - fgets 返回 NULL 表示 EOF 或错误，必须处理

5. **fread/fwrite**:
   - 检查返回值是否等于期望字节数: `if (fread(buf, 1, len, fp) < len) return ERROR;`
   - 部分读取也需要处理

6. **read/write**:
   - 检查返回值是否 `== -1` 错误，以及是否为部分字节
   - 短写入（short write）必须处理: `written < len` 需要继续写入

7. **setenv**:
   - 检查返回值是否为 `-1`（环境变量已满）

### Step 4: 跨函数补证
Max depth 1, beyond → downgrade to suspicious
- 检查调用点所在函数是否在被调用前或后返回该指针、或检查该返回值
- 如果返回值被传递给另一个函数，检查被调用方是否做了检查 — 且仅当被调用方放弃检查时才追溯
- 如果调用点所在函数本身返回该指针，且调用方可能检查，则当前层标记为 `suspicious` 而非 `confirmed`

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 函数返回值被赋值或使用?
**Q2**: 返回值被检查（if/assert/三元/RAII）?
**Q3**: 不检查返回值有补偿（如同一地址前次已检查）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

