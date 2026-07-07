---
detector: uninitialized-memory
severity: medium
cwe: CWE-457
cvss: 5.5
language: [c, cpp]
tags: [memory, stack, heap, undefined-behavior]
precision: high
confidence: dynamic
target_functions: [bzero, calloc, code_context, data_flow_path, double, float, judgment_rationale, malloc, memset, operator, variable_state]
match_patterns: [int|char|float|double ... ;                     # 声明未初始化, malloc|operator new                              # 未初始化堆分配, struct S var;                                    # 未初始化 struct]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

变量/缓冲区在使用前未被初始化，其内容为栈/堆的残留数据。攻击者可利用此漏洞读取残留的敏感信息（密钥、令牌）或导致不确定的控制流（函数指针为残留值）。

**核心原则：所有变量声明时必须初始化。`memset`/`= {0}` 确保使用前清零。区分 `calloc`（清零分配）和 `malloc`（未初始化）。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索未初始化的局部变量 (Uninitialized Local Variables)

```c
// BAD: 使用未初始化的变量
int x;
if (x > 0) { ... }              // x 的值未定义
```

### Step 2: 搜索未初始化的堆分配 (Uninitialized Heap Allocations)

```c
// BAD: malloc 后直接读取
char *buf = malloc(100);
printf("%s", buf);              // buf 内容是垃圾数据
```

### Step 3: 部分初始化 (Partial Initialization)

```c
// BAD: struct 部分初始化
struct Point { int x, y; };
struct Point p;
p.x = 10;
printf("%d", p.y);              // p.y 未初始化

// BAD: 数组部分初始化
int arr[10];
arr[0] = 1;
int sum = arr[5];               // arr[5] 未初始化
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：未初始化变量的声明行 + 首次读取/使用行，标注两者之间是否存在赋值操作，以及变量的类型和存储期（auto/static/allocated）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：区分"确定未初始化"vs"条件未初始化"——分析所有到达读取点的控制流路径，确认是否存在某条路径上变量未被赋值；标注编译器警告诊断（如 -Wuninitialized 输出）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：变量从声明点 → 可能的赋值点 → 读取点之间的控制流路径，特别关注 if/else 分支中仅在部分分支赋值的场景
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若变量作为输出参数传递给函数，追踪被调用函数是否保证初始化（通过文档或源码分析）
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：变量存储期（static/auto/allocated）、类型（POD/非POD）、大小；对于 struct 标注已初始化 vs 未初始化的字段
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：MSan (MemorySanitizer) 或 Valgrind 输出、编译器 -Wuninitialized / -Wsometimes-uninitialized 诊断
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **声明即初始化**：`int x = 0;` / `char buf[256] = {0};`
2. **使用 calloc**：`calloc(n, size)` 自动清零（且防乘法溢出）
3. **编译器检测**：启用 `-Wuninitialized` / `-Wall`（GCC/Clang）
4. **C++**：使用值初始化 `T obj{};` / `std::vector` 自动清零

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 全局/静态变量 | C/C++ 标准保证静态存储期变量自动零初始化（.bss 段） | 确认变量为文件作用域或 static 修饰，非局部自动变量 |
| `calloc` 分配 | calloc 保证分配的内存全部清零，与 malloc 不同 | 确认内存分配使用 calloc(nmemb, size) 而非 malloc |
| `{}` 值初始化 (C++) | C++ 值初始化语法保证标量类型零初始化、类类型调用默认构造函数 | 确认使用 T obj{}; 或 T obj = {}; 语法 |
| `memset`/`bzero` 后使用 | 显式清零操作确保内存内容确定 | 确认 memset/bzero 覆盖所有后续读取的字节范围 |
| 作为输出参数传递 | 被调用函数文档明确保证初始化该参数（如 POSIX 函数的传出参数） | 确认函数签名中参数为非 const 指针/引用，且文档注明 "on success, value is set" |
| 声明后立即赋值（下一行） | 无控制流分支，变量在读取前必然被赋值 | 确认声明语句紧接着赋值语句，中间无 if/goto/label |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 局部变量声明后直接读取（无中间赋值）
int|char|float|double ... ;                     # 声明未初始化
                                                # → MUST: code_context (声明行+读取行)
→ (中间无赋值)                                    # → MUST: judgment_rationale (所有路径分析)
→ if|printf|return 使用该变量                     # 读取未初始化值 → UB

# malloc 后无 memset/calloc
malloc|operator new                              # 未初始化堆分配
→ (无 memset|bzero|calloc)                       # 缺少清零操作
→ 读取分配的内存                                    # → SHOULD: data_flow_path (分配→读取路径)
→ 无 NULL 检查直接读取                              # 双重风险

# struct/array 部分使用
struct S var;                                    # 未初始化 struct
→ 对部分字段赋值                                   # 仅初始化部分成员
→ 读取未赋值字段                                    # → MAY: variable_state (初始化vs未初始化字段)

# === EXCLUDE (不报告) ===
→ static|extern 存储期变量                         # 标准保证零初始化
→ calloc\(                                       # 自动清零分配
→ = {}|= {0}|= T{}|= T()                         # 值初始化/零初始化
→ memset\(.*,\s*0|bzero\(                        # 显式清零
→ 声明行后紧跟 = 赋值（无控制流分支）                   # 必然初始化
→ 作为非const指针传入已知初始化函数                    # 输出参数由被调用函数初始化（需验证函数文档）
→ new T()|new T{}                                # C++带初始化器的new
```
