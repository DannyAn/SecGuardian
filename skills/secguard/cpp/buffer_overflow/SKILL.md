---
name: secguard-cpp-buffer-overflow
description: "检测 C/C++ 代码中通过不安全字符串操作函数导致的缓冲区溢出漏洞，包括 strcpy/strcat/sprintf/memcpy/gets 及安全变体参数误用"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="string", category="memory"]
---

# 缓冲区溢出检视算子

## 元数据

- id: memory.buffer-overflow
- severity: critical
- cwe: CWE-120
- category: string + memory
- signal_source: call_sites[category="string", category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: strcpy, strcpy_s, strcat, strcat_s, sprintf, sprintf_s, memcpy, memcpy_s, gets, gets_s, snprintf
- 按信号分组:
  - unsafe 组（无 _s 后缀）: strcpy, strcat, sprintf, memcpy, gets → 高优先级
  - safe 组（有 _s 后缀）: strcpy_s, strcat_s, sprintf_s, memcpy_s, gets_s → 参数审计优先
  - snprintf → 返回值检查优先

## 检视协议

### Step 1: 信号确认

对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在（排除注释/宏/条件编译）
3. 判断调用点属于 unsafe 组还是 safe 组

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链:
- Source: 源缓冲区的来源（栈数组/堆分配/函数参数/用户输入）
- Propagate: 数据流转路径中是否有任何长度计算或安全检查
- Sink: 目标缓冲区的大小与源数据长度的关系

### Step 3: 安全变体参数审计

对 `_s` 后缀函数变体执行参数审计：

**strcpy_s(dst, dsize, src)**:
- 检查 `dsize` 是否等于 `sizeof(dst)`
- 若 `dst` 是栈数组: `dsize == sizeof(dst)` → 安全；`dsize < sizeof(dst)` → 截断风险；`dsize > sizeof(dst)` → 逻辑错误
- 若 `dst` 是指针: 检查 `dsize` 参数来源

**memcpy_s(dst, dsize, src, n)**:
- 检查 `dsize >= n`
- `dsize < n` → 缓冲区溢出（违反安全契约）
- 确认 `dsize` 不超过 `dst` 的实际分配大小

**sprintf_s(buf, size, fmt, ...)**:
- 检查 `size == sizeof(buf)`（栈目标）
- 检查 `size >= strlen(fmt)` + 扩展参数长度

**snprintf(buf, size, fmt, ...)**:
- 检查返回值是否 >= size → 截断（非溢出，但数据丢失）

### Step 4: 跨函数补证

当目标缓冲区或源数据来自函数参数时，查询调用图查调用者：
- 深度=1 调用者 → 确认实际传入参数的大小关系
- 深度 > 1 → 降级为 "suspicious"，标记 confidence: medium

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 目标缓冲区大小 ≥ 拷贝大小?
**Q2**: 拷贝大小是编译期常量?
**Q3**: 源缓冲区至少有 n 字节可读?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "64 字节栈缓冲区 buf 分配于函数入口", "file": "src/parser.c", "line": 40},
    "propagate": {"description": "strcpy 无长度限制，从 user_input 复制", "file": "src/parser.c", "line": 42},
    "sink": {"description": "user_input 可能超过 63 字节导致栈缓冲区溢出", "file": "src/parser.c", "line": 42}
  }
}
```
