---
category: standards
standard: SEI CERT C
version: "2016"
rules_count: 120+
mapped_detectors: 28
---

# SEI CERT C 编码标准 → SecGuardian Detector 映射

> 来源: [SEI CERT C Coding Standard](https://wiki.sei.cmu.edu/confluence/display/c/SEI+CERT+C+Coding+Standard)

## 映射策略

SEI CERT C 规则分为 Rec. (建议) 和 Rule (必遵)。本映射优先覆盖 Rule 级别、与 SecGuardian 5-topic 体系对应的规则。

## 规则映射

### 01. 预处理器 (PRE)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| PRE00-C | 使用 `#include` 保护宏替换 | resource-exhaustion | ⚠️ 部分 |
| PRE30-C | 不要在类函数宏中多次求值参数 | — | ❌ 未覆盖 |
| PRE31-C | 避免不安全宏的参数副作用 | — | ❌ 未覆盖 |

### 03. 声明和初始化 (DCL)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| DCL30-C | 声明具有正确链接的对象 | — | ❌ 未覆盖 |

### 04. 表达式 (EXP)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| EXP33-C | 不要读取未初始化的内存 | uninitialized-memory | ✅ 完全 |
| EXP34-C | 不要对空指针解引用 | null-dereference | ✅ 完全 |
| EXP35-C | 不要修改字符串字面量 | — | ❌ 未覆盖 |
| EXP36-C | 不要在指针和更严格对齐的类型之间转换 | bad-cast | ⚠️ 部分 |
| EXP37-C | 使用正确的参数个数调用函数 | — | ❌ 未覆盖 |
| EXP39-C | 不要通过不兼容类型的指针访问变量 | bad-cast | ✅ 完全 |
| EXP40-C | 不要修改 const 对象 | — | ❌ 未覆盖 |
| EXP42-C | 不要比较未关联的指针 | — | ❌ 未覆盖 |
| EXP43-C | 避免在 `sizeof` 中使用副作用 | — | ❌ 未覆盖 |
| EXP44-C | 不要将 `sizeof` 用于指针求长度 | buffer-overflow | ✅ 完全 |

### 05. 整数 (INT)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| INT30-C | 确保无符号整数运算不回绕 | integer-overflow | ✅ 完全 |
| INT31-C | 确保整数转换不会丢失数据 | integer-overflow | ⚠️ 部分 |
| INT32-C | 确保有符号整数运算不溢出 | integer-overflow | ✅ 完全 |
| INT33-C | 确保除法和取余不导致除零错误 | — | ❌ 未覆盖 |
| INT34-C | 不要将有符号和无符号混合运算 | integer-overflow | ⚠️ 部分 |
| INT35-C | 使用正确的整数类型 | — | ❌ 未覆盖 |
| INT36-C | 将指针转为整数或反之 | — | ❌ 未覆盖 |

### 06. 浮点 (FLP)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| FLP30-C | 不要将浮点用于循环计数 | — | ❌ 未覆盖 |

### 07. 数组 (ARR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| ARR30-C | 不要形成或使用越界的指针/数组下标 | buffer-overflow, oob-read | ✅ 完全 |
| ARR32-C | 确保变长数组的大小参数在有效范围内 | buffer-overflow | ⚠️ 部分 |
| ARR36-C | 不要用 `sizeof` 运算符在函数参数中求数组长度 | buffer-overflow | ✅ 完全 |
| ARR37-C | 不要对非数组对象使用指针算术 | — | ❌ 未覆盖 |
| ARR38-C | 保证对数组参数进行边界检查 | buffer-overflow | ✅ 完全 |
| ARR39-C | 不要对可能为空的指针进行加减操作 | null-dereference | ⚠️ 部分 |

### 08. 字符和字符串 (STR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| STR30-C | 不要试图修改字符串字面量 | — | ❌ 未覆盖 |
| STR31-C | 保证字符串存储有足够空间容纳字符数据和终止符 | buffer-overflow | ✅ 完全 |
| STR32-C | 不要将非空终止的字符序列传递给要求字符串的函数 | buffer-overflow | ⚠️ 部分 |
| STR34-C | 在字符数据类型之间进行转换 | integer-overflow | ⚠️ 部分 |
| STR38-C | 不要将格式化函数用于非字面量字符串 | format-string | ✅ 完全 |

### 09. 内存管理 (MEM)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| MEM30-C | 不要访问已释放的内存 | use-after-free | ✅ 完全 |
| MEM31-C | 只释放动态分配的内存 | mismatched-free | ✅ 完全 |
| MEM33-C | 灵活数组成员正确分配 | buffer-overflow | ⚠️ 部分 |
| MEM34-C | 只释放一次内存 | double-free | ✅ 完全 |
| MEM35-C | 在对齐边界分配内存 | — | ❌ 未覆盖 |
| MEM36-C | 不要使用不可重入的 `malloc`/`free` 在信号处理器中 | thread-unsafe-signal | ✅ 完全 |

### 10. 输入输出 (FIO)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| FIO30-C | 不要使用格式字符串输入函数 | format-string | ✅ 完全 |
| FIO32-C | 不要对文件执行操作时不检查返回值 | resource-exhaustion | ⚠️ 部分 |
| FIO34-C | 以文本模式打开文件 | — | ❌ 未覆盖 |
| FIO37-C | 不要假设 `fgets()` 或 `fgetws()` 返回非空字符串 | — | ❌ 未覆盖 |
| FIO38-C | 不要使用已被废弃或不可重入的 I/O 函数 | — | ❌ 未覆盖 |
| FIO39-C | 不要以写模式打开共享文件 | toctou | ✅ 完全 |
| FIO42-C | 确保在不再需要时关闭文件 | memory-leak | ⚠️ 部分 |
| FIO45-C | 避免 TOCTOU 竞态条件 | toctou | ✅ 完全 |
| FIO47-C | 使用有效格式字符串 | format-string | ✅ 完全 |

### 11. 环境 (ENV)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| ENV30-C | 不要修改 `getenv()` 返回的字符串 | — | ❌ 未覆盖 |
| ENV32-C | 所有 `exit` 处理程序必须返回 | — | ❌ 未覆盖 |
| ENV33-C | 不要调用 `system()` | command-injection | ✅ 完全 |

### 覆盖统计

| 类别 | 规则数 | 已映射 | 覆盖率 |
|------|--------|--------|--------|
| PRE | 4 | 1 | 25% |
| EXP | 11 | 4 | 36% |
| INT | 7 | 3 | 43% |
| ARR | 6 | 4 | 67% |
| STR | 5 | 4 | 80% |
| MEM | 6 | 5 | 83% |
| FIO | 9 | 6 | 67% |
| ENV | 3 | 1 | 33% |

**总计: 28/51 核心规则已映射 (55%)**
