---
name: secguard-cpp-uninitialized
description: "检测 C/C++ 代码中结构体部分初始化、局部变量读前未写等未初始化内存使用漏洞"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.uninitialized
signal_filter: memory.uninit*
signal_source: struct_inits[cat="partial_init|no_init"] | variable_writes[cat="read_before_write"]
severity: high
cwe: [CWE-457, CWE-908]
---

# uninitialized 检测规则

> **定位**: 本文件是 memory.uninitialized 规则的主检测规范。回答"检测什么、怎么检测"。
> **加载时机**: Phase 2a Hypothesis Generator | **消费方**: Investigator (Step 5) + Judge (Step 7)

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.uninitialized` |
| signal_filter | `memory.uninit*`（供 `secguard ./src c memory.uninitialized` 过滤匹配） |
| signal_source | `struct_inits[cat="partial_init\|no_init"]` + `variable_writes[cat="read_before_write"]` |
| 默认严重度 | High |

---

## Scenario 1: 堆结构体部分初始化（CWE-908）

### 威胁定义

通过 `malloc`/`calloc` 分配的结构体内存，部分字段被初始化但另一部分字段在首次读取时包含未定义值（malloc 不初始化，calloc 初始化为 0）。攻击者可通过未初始化字段读取残留的堆内存数据（信息泄露），或通过未初始化的函数指针/偏移量实现控制流劫持。

**核心原则：分配后必须显式初始化所有字段，或使用 memset/calloc 归零。**

### 高危代码模式

```c
// BAD: malloc 不归零，field2 包含堆残留数据
struct Config {
    char *path;
    int   flags;
    int   debug_level;
};
struct Config *cfg = (struct Config *)malloc(sizeof(struct Config));
cfg->path = strdup("/etc/app");
cfg->flags = O_RDONLY;
// cfg->debug_level 未初始化 — 使用前包含随机值
printf("debug=%d\n", cfg->debug_level);

// GOOD: calloc 归零所有字段
struct Config *cfg = (struct Config *)calloc(1, sizeof(struct Config));
cfg->path = strdup("/etc/app");
// debug_level = 0 (calloc 保证)

// GOOD: 显式初始化所有字段
struct Config *cfg = (struct Config *)malloc(sizeof(struct Config));
cfg->path = strdup("/etc/app");
cfg->flags = O_RDONLY;
cfg->debug_level = 0;
```

### 检测模式

```
# MATCH（触发检测）
malloc(sizeof(StructType)) → struct_inits[cat="partial_init"] → 未覆盖所有字段
malloc(n) + 类型转换为 struct * → struct_inits[cat="partial_init"]
calloc 后仅设置部分字段 → 虽然归零但未覆盖语义初始值

# EXCLUDE（不报告）
calloc 分配后字段全部显式覆盖 → struct_inits[cat="full_init"]
静态初始化的全局/静态变量（自动归零）→ 不报告
memset(buf, 0, sizeof(...))  → 不报告
```

---

## Scenario 2: 栈结构体部分初始化（CWE-457）

### 威胁定义

栈上声明的结构体变量，部分字段通过赋值初始化但另一部分从未写入。与堆不同，栈变量不会自动归零——未初始化字段包含栈残留数据（前一次函数调用的栈帧内容）。如果未初始化字段是指针或偏移量，可能导致任意内存读写。

**核心原则：所有字段必须在首次读取前显式赋值。**

### 高危代码模式

```c
// BAD: 栈结构体未全部初始化
void parse_request() {
    struct Request req;           // 栈变量，内存未定义
    req.client_ip = get_ip();    // 仅初始化一个字段
    // req.port, req.method, req.body 包含栈垃圾
    if (req.method == POST) {    // 使用未初始化的 method
        handle_post(&req);
    }
}

// GOOD: 声明时使用 = {0} 或 memset
void parse_request() {
    struct Request req = {0};    // 所有字段归零
    req.client_ip = get_ip();
}

// GOOD: C99 指定初始化器
void parse_request() {
    struct Request req = {
        .client_ip = get_ip(),
        .port = 8080,
        .method = GET,
    };
}
```

### 检测模式

```
# MATCH（触发检测）
Block/function scope struct var 声明 → struct_inits[cat="no_init"] → 后续字段读取
variable_writes[cat="read_before_write"] → struct field

# EXCLUDE（不报告）
= {0} / = {}  → struct_inits[cat="full_init"]
memset(&var, 0, sizeof(var)) → 不报告
全局/static 变量（.bss 归零）→ 不报告
```

---

## Scenario 3: 局部变量读前未写（CWE-457）

### 威胁定义

非结构体的局部变量（int、指针等）在赋值前被读取。栈变量不自动初始化，读取未写入的变量产生未定义行为——值取决于栈上的历史数据。

**核心原则：所有局部变量必须在首次读取前写入。**

### 高危代码模式

```c
// BAD: flag 未初始化就判断
int process_flag() {
    int flag;             // 未初始化
    if (flag == 1) {      // UB: 读取未定义值
        return 1;
    }
    return 0;
}

// GOOD: 声明时初始化
int process_flag() {
    int flag = 0;
    if (flag == 1) {
        return 1;
    }
    return 0;
}
```

### 检测模式

```
# MATCH（触发检测）
variable_writes[cat="read_before_write"] → first_read_line > 0 && first_write_line == 0

# EXCLUDE（不报告）
声明时含 = 初始化器
全局/static 变量（.bss 归零）
函数参数（调用者传递，非未初始化）
```

---

## 调查建议

### 结构体初始化分析

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

1. 从 `struct_inits` 信号中提取结构体类型和字段列表
2. 检查分配方式：malloc（不归零）vs calloc（归零）vs 栈声明（未定义）
3. 追踪字段赋值：记录每个字段的首次写入行号
4. 对比声明字段总数 vs 已初始化字段数
5. 如果仅缺少 1 个字段且不是指针/函数指针 → 降级为 informational

### 变量使用分析

1. 从 `variable_writes` 信号中提取变量声明和首次读/写信息
2. 检查声明行和首次读行之间是否有点用赋值
3. 确认声明时是否含有初始化器

---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: 存在性 — 是否确实有未初始化字段/变量被读取？

**Yes** = struct_inits 显示 total_fields > initialized_fields 且未初始化字段在后续代码中被读取；或 variable_writes 显示 category="read_before_write"
**No**  = 所有字段在使用前均已被写入；变量在首次读取前已被赋值

### Q2: 可利用性 — 未初始化的内存内容是否可被攻击者利用？

**Yes** = 未初始化的字段是指针、函数指针、数组索引或安全标志；或变量值影响控制流/内存操作
**No**  = 未初始化的字段仅用于日志输出、无安全影响

### Q3: 缓解 — 是否存在编译时或运行时保护？

**Yes** = 使用 calloc（归零）、memset 整体初始化、= {0} 声明、-ftrivial-auto-var-init=zero 编译选项
**No**  = 无任何保护措施

### 判定矩阵

| Q1 | Q2 | Q3 | 结论 |
|----|----|----|-----------|
| Yes | Yes | No | **CONFIRMED** — 未初始化内存存在且可利用，无缓解 |
| Yes | No | No | **CONFIRMED** — 存在但不可利用（降低严重度） |
| Yes | Yes | Yes | **SUPPRESS** — 缓解措施消除风险 |
| Yes | No | Yes | **SUPPRESS** — 缓解措施足够 |
| No | — | — | **SUPPRESS** — 此上下文漏洞不成立 |
| Unknown | — | — | **保留为 Unknown** — 降级为 informational |

### 输出整合

在 finding 的 evidence 中附加：
```json
"judgment_matrix": {
    "Q1_uninit_exists": true|false,
    "Q2_uninit_exploitable": true|false,
    "Q3_uninit_mitigated": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：结构体声明/分配 + 字段赋值语句的完整代码块
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析哪些字段未被初始化、是否在后续代码中被读取、值是否影响安全
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：声明行 → 字段赋值行 → 字段读取行的数据流路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：如有跨函数传递未初始化结构体，记录调用链
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：分配方式（malloc/calloc/栈）、归零状态、字段类型信息
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用 -fsanitize=memory (MSan) 或 valgrind
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "struct Config 在栈上声明，无初始化器", "file": "src/parser.c", "line": 56},
    "propagate": {"description": "仅 cfg->path 被赋值，cfg->debug_level 和 cfg->flags 未写入", "file": "src/parser.c", "line": 57},
    "sink": {"description": "未初始化的 cfg->debug_level 被 printf 读取", "file": "src/parser.c", "line": 69}
  },
  "scenario": "Scenario 2: 栈结构体部分初始化",
  "references_applied": ["false-positive.md", "exceptions.md", "cross-function.md"]
}
```
