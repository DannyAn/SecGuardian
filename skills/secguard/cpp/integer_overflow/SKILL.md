---
name: secguard-cpp-integer_overflow
description: "Detect integer overflow/wraparound in allocation-size arithmetic and boundary checks"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# Integer Overflow 检视算子

## 元数据

- id: memory.integer_overflow
- severity: critical
- cwe: CWE-190
- category: memory
- signal_source: call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: `malloc`, `calloc`, `realloc`, `aligned_alloc`, `memcpy`, `memmove`, `memset`, `new`
- 按信号分组: 优先处理 callee 参数中包含 `*` 或 `+` 算术表达式的分配调用，其次是 callee 参数为有符号变量的分配调用

## 检视协议

### Step 1: 信号确认
对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在，且第三个参数或参数中包含乘法/加法/减法运算

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: 用户输入、网络数据、文件大小、循环索引、配置值等外部可控的整数值
- Propagate: 算术运算（`a * b`, `a + b`, `a - b`, `a << b`）将上述值传播到分配大小或边界检查
- Sink: 分配函数（malloc/calloc/realloc/new）的参数、memcpy 的 size 参数、数组索引、边界检查的右值

### Step 3: 安全变体参数审计
1. 检查乘法操作数是否均为编译期常量或 sizeof 表达式 — 如是则不报告
2. 检查算术表达式前是否存在溢出防护: `if (a > SIZE_MAX / b)` 或 `__builtin_mul_overflow` 等
3. 检查有符号变量在用于 size 参数前是否已做非负验证: `if (n < 0) return ERROR;`
4. 检查无符号整型参与运算时可能产生回绕的路径
5. 确认溢出结果不会绕过安全检查: `if (total > MAX) return ERROR;` — 如果 total 已回绕则为假安全

### Step 4: 跨函数补证
Max depth 1, beyond → downgrade to suspicious
- 追踪分配大小的源变量是否从被调用函数返回
- 检查被调用函数中是否存在溢出防护
- 如果数据流跨越更多层且无显式保护，标记为 suspicious 而非 confirmed

### Step 5: 5 轮反思
1. **事实校对**: 确认算术运算的两侧操作数类型、来源、可能取值范围
2. **因果闭环**: 该溢出的确会影响分配大小或安全检查的有效性
3. **寻找豁免**: 上游是否已做范围限定（如 `if (size > 1000) return`）或使用 checked 函数
4. **根因归并**: 同函数内多个溢出是否由同一个未检查的输入变量导致
5. **保守定性**: 确认报告为 critical，除非有明确的防护屏障
