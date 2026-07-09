---
name: secguard-cpp-null_dereference
description: "检测 C/C++ 代码中动态内存分配后未判空直接解引用导致的空指针解引用漏洞"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.null
signal_filter: memory.null*
signal_source: call_sites[cat="memory"]
severity: critical
cwe: [CWE-476]
---

# null_dereference 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.null` |
| signal_filter | `memory.null*`（供 `secguard ./src c memory.null` 过滤匹配） |
| signal_source | `call_sites[cat="memory"]` |
| 默认严重度 | Critical |

---

## Scenario 1: 动态内存分配后未判空直接解引用（CWE-476）

### 威胁定义

程序对值为 NULL 的指针进行解引用操作，导致段错误崩溃或（在特定条件下）可被利用的未定义行为。C/C++ 中 malloc/fopen/getenv 等函数可能返回 NULL，如果未检查直接使用就是高危。

**核心原则：任何可能返回 NULL 的函数调用后，返回值必须在使用前检查。** 但需区分"直接检查"和"通过调用链保证"——调用者已检查的场景不重复报告。

### 检测逻辑

**Step 1: 识别可能返回 NULL 的调用**

| 函数类别 | 示例 | 检测条件 |
|---------|------|---------|
| 内存分配 | `malloc`/`calloc`/`realloc` | 返回值被解引用且无 NULL 检查 |
| 文件操作 | `fopen`/`opendir` | 同上 |
| 环境变量 | `getenv` | 同上 |
| 字符串查找 | `strchr`/`strstr`/`strtok` | 同上 |
| 自定义分配器 | `xxx_malloc`/`xxx_alloc`/`xxx_new` | 同上，需匹配命名约定 |
| C++ new (std::nothrow) | `new(std::nothrow) T` | 返回 nullptr |
| C++ dynamic_cast (指针) | `dynamic_cast<T*>(ptr)` | 失败返回 nullptr |

**Step 2: 确认"检查"存在**

有效检查模式（**不报告**）：
```c
if (ptr == NULL) return ERROR;       // 显式检查
if (!ptr) goto cleanup;              // 逻辑非检查
if (ptr) { use(ptr); }               // 条件使用
```

**报告**模式：
```c
ptr = malloc(n);
ptr->field = value;                  // 无中间检查 ← 报告

// assert 不算检查（release 构建中 NDEBUG 定义后 assert 为空操作）
ptr = malloc(n);
assert(ptr != NULL);                 // 这不是真正的检查 ← 报告
ptr->field = value;
```

### 漏洞模式

**模式 1: 完全无检查**
```c
// VULNERABLE: 无 NULL 检查
char *buf = (char*)malloc(1024);
buf[0] = 'a';       // 若 malloc 返回 NULL，此处崩溃
read(fd, buf, 100);

// SAFE
char *buf = (char*)malloc(1024);
if (buf == NULL) {
    return -1;
}
buf[0] = 'a';
```

**模式 2: 延迟检查**
```c
// VULNERABLE: 检查在解引用之后
char *buf = (char*)malloc(1024);
buf[0] = 'a';       // 崩溃先于检查
if (buf == NULL) {
    return -1;
}

// SAFE
char *buf = (char*)malloc(1024);
if (buf == NULL) {
    return -1;
}
buf[0] = 'a';
```

**模式 3: 条件编译下的分配**
```c
// VULNERABLE
#ifdef DEBUG
    char *buf = (char*)malloc(1024);
#endif
    buf[0] = 'a';  // DEBUG 未定义时 buf 未声明

// SAFE
#ifdef DEBUG
    char *buf = (char*)malloc(1024);
    if (buf == NULL) return -1;
    buf[0] = 'a';
#endif
```

### 检测模式

```
# === MATCH（触发检测）===

# malloc/calloc/realloc 后无 NULL 检查直接使用
(malloc|calloc|realloc)\(
                                                       # → MUST: code_context (分配+解引用代码块)
→ 下一非空行不是 if\s*\(.*NULL|if\s*\(!|goto\s+cleanup|return.*NULL
→ 同作用域内指针被解引用 (->|[*\[\]])
                                                       # → MUST: judgment_rationale (NULL检查存在性分析)

# assert 作为唯一检查
(malloc|calloc)\([^)]*\)
→ assert\(.*!=.*NULL\)
→ 同作用域后使用指针

# === EXCLUDE（不报告）===

# C++ new (throw 版本) — 不返回 nullptr
new\s+(?!\(std::nothrow\))

# GCC returns_nonnull 标注
__attribute__\(\(returns_nonnull\)\)

# 显式 NULL 检查
if\s*\(.*==\s*NULL\)|if\s*\(!ptr\)
# std 智能指针管理
std::unique_ptr|std::shared_ptr
# alloca/栈分配
\balloca\(
```

### 修复指引

1. **分配后立即检查**：`if (!ptr) return ERR_NOMEM;`
2. **C++ 优先使用 throw 版本**：`new T` 失败抛 `std::bad_alloc`，无需手动 NULL 检查
3. **使用 RAII 包装**：`std::unique_ptr<T>` 自动管理生命周期
4. **禁止用 assert 做 NULL 检查**：release 构建中 assert 被移除

---

## Scenario 2: 库函数（getenv/fopen/strchr）返回值未检查（CWE-476）

### 威胁定义

标准库函数如 `getenv`、`fopen`、`strchr`、`strstr`、`strtok` 等在某些条件下返回 NULL。未检查直接使用导致空指针解引用。

**核心原则：所有可能返回 NULL 的非分配类库函数调用后，返回值同样必须在使用前检查。** 环境变量不存在时 getenv 返回 NULL，文件不存在时 fopen 返回 NULL，字符串中无目标字符时 strchr 返回 NULL。

### 检测逻辑

确认上述函数的返回值被赋值给指针变量后，是否有 NULL 检查再使用。

**有效检查：**
```c
char *env = getenv("PATH");
if (env == NULL) {
    // 使用默认路径
}
// 安全使用 env
```

**无效检查（报告）：**
```c
char *env = getenv("HOME");
printf("HOME=%s\n", env);  // env 可为 NULL，无检查
```

### 检测模式

```
# === MATCH（触发检测）===

# getenv/fopen/strchr 返回值未检查
(getenv|fopen|strchr|strstr)\(
→ 返回值赋值
→ 无 if.*NULL 直接使用
```

### 修复指引

1. 标准库函数返回值一律检查 NULL
2. 使用可选/默认值包装：`getenv("VAR") ?: "default"`
3. C++ 使用 `std::optional` 封装可能失败的操作

---

## Scenario 3: realloc 覆盖原指针与特殊分配模式（CWE-476）

### 威胁定义

`realloc` 返回 NULL 时，原指针的分配仍然存在但如果直接 `ptr = realloc(ptr, size)` 会覆盖原指针导致内存泄漏。`calloc(n, size)` 的乘法溢出可能导致分配小于预期，配合 NULL 检查失效产生越界。

**核心原则：realloc 必须使用临时变量接收返回值；calloc 的参数必须验证无乘法溢出。**

### 检测逻辑

**realloc 模式：**
1. 检查是否使用临时指针接收 realloc 返回值
2. 检查返回值是否为 NULL
3. 检查失败时是否释放了原指针

**calloc 溢出模式：**
1. 检查 calloc 参数 n 和 sizeof(T) 的乘积是否可能溢出
2. 检查 n 是否来自外部输入

### 漏洞模式

**realloc 丢失原指针：**
```c
// VULNERABLE: realloc 返回 NULL 时原指针丢失且内存泄漏
ptr = (int*)realloc(ptr, new_size * sizeof(int));
ptr[0] = 42;  // realloc 失败 → 崩溃

// SAFE
int *tmp = (int*)realloc(ptr, new_size * sizeof(int));
if (tmp == NULL) {
    free(ptr);
    return -1;
}
ptr = tmp;
ptr[0] = 42;
```

**calloc 乘法溢出：**
```c
// VULNERABLE: n * sizeof(T) 可能溢出
struct Large *arr = (struct Large*)calloc(n, sizeof(struct Large));
if (arr == NULL) return -1;
arr[n-1].value = 42;  // 若 calloc 因溢出返回小内存，arr[n-1] 越界

// SAFE: 检查乘法是否溢出 + NULL 检查
if (n > SIZE_MAX / sizeof(struct Large)) return -1;
struct Large *arr = (struct Large*)calloc(n, sizeof(struct Large));
if (arr == NULL) return -1;
```

### 检测模式

```
# === MATCH（触发检测）===

# realloc 覆盖原始指针（泄漏 + 空指针双重风险）
\w+\s*=\s*realloc\(\1,
```

### 修复指引

1. **realloc**：始终使用临时变量 + NULL 检查 + 失败时释放原指针
2. **calloc 防溢出**：使用前验证 `n <= SIZE_MAX / sizeof(T)`
3. 考虑 C++ RAII 容器（`std::vector`）自动管理重分配

---

## 已知安全模式

```c
// SAFE: xmalloc 封装（abort on OOM）
static inline void *xmalloc(size_t n) {
    void *p = malloc(n);
    if (p == NULL) abort();
    return p;
}
void *p = xmalloc(1024);  // 永远非 NULL
p[0] = 'a';               // 安全

// SAFE: calloc + assert
void *p = calloc(n, size);
assert(p != NULL);
p[0] = 'a';               // debug 模式下安全

// SAFE: return on NULL + else 块
p = malloc(n);
if (p == NULL) return -1;
p[0] = 'a';               // 安全
```

## Worker 检视协议

### Step 1: 信号确认

对每个预筛信号：
1. 读取分配点源码（±10 行）
2. 确认分配点的返回值有变量接收（`T *p = malloc(...)`）
3. 识别分配点后面的第一个分支结构（if / switch / ternary / assert）

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链：
- **Source**: 分配函数的返回值（哪个指针变量）
- **Propagate**: 分配点后紧接着的控制流
- **Sink**: 第一个解引用点（`p->field`、`p[0]`、`*p`、`func(p)`）

### Step 3: 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

**直接 NULL 检查（安全）**:
```c
p = malloc(n);
if (p == NULL) {
    return -1;  // 正确处理
}
p->field = 42;  // 安全使用
```

**无 NULL 检查（不安全）**:
```c
p = malloc(n);
p->field = 42;  // p 可为 NULL → 空指针解引用
```

**inline if 模式**:
```c
// 安全：xmalloc 封装确保非 NULL 或 abort
p = xmalloc(n);
// 若 xmalloc = malloc + assert(p) → 安全
// 若 xmalloc = malloc（无检查）→ 不安全

// 安全：条件分支包含赋值
if ((p = malloc(n)) == NULL) return -1;
// 使用在 if 之后 → 安全
```

**realloc 特殊审计**:
```c
// 不安全：realloc 返回 NULL 时原指针丢失
p = realloc(p, new_size);
p[0] = 1;  // realloc 失败时 p=NULL → 崩溃 + 原内存泄漏

// 安全：临时指针 + NULL 检查
tmp = realloc(p, new_size);
if (tmp == NULL) {
    free(p);
    return -1;
}
p = tmp;
```

**calloc 溢出审计**:
```c
// 即使有 NULL 检查，calloc(n, size) 的乘法溢出也需要关注
p = calloc(n, sizeof(large_struct));  // 若 n * sizeof 溢出 → 返回小分配
if (p != NULL) {
    p[n-1] = ...;  // 溢出检查点
}
```

### Step 4: 跨函数补证

> 参考 [cross-function.md](references/cross-function.md) 跨函数追踪规则。

当分配的指针传入子函数使用：
- 追踪深度=1，检查被调函数是否在入口做 NULL 检查
- 若子函数无条件解引用 → 确认漏洞（前提：子函数在任何路径下都会解引用）
- 若子函数有 NULL 检查 → 安全

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 `cross_signal_analysis: true`

### Step 5: 事实锚定反思（3 问判定矩阵）

> 参考 [exceptions.md](references/exceptions.md) 确认边界情况。
> 参考 [false-positive.md](references/false-positive.md) 触发抑制。

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: malloc/calloc/realloc 返回值已检查 NULL?
**Q2**: 检查后使用路径中仍可能为 NULL?
**Q3**: 使用前有赋值操作（覆盖了 NULL 风险）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：包含可能返回 NULL 的函数调用（malloc/calloc/realloc/fopen/getenv/strchr 等）及其后续解引用操作的完整代码块，标注返回值赋值变量和首次解引用的行号
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析从 NULL 返回函数调用到指针解引用之间是否存在 NULL 检查——逐行验证是否有 if(ptr==NULL)/if(!ptr) 分支保护，确认检查是否为有效检查（排除 assert/NDEBUG 场景），以及调用链上是否有调用者已做保证
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：指针从分配函数返回值 → 赋值 → （可能的检查）→ 解引用的完整数据流，标注检查点的存在性和有效性
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若涉及跨函数传递，记录调用者→被调用者的完整调用链，确认调用者在传递指针前是否已做 NULL 检查
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：指针变量在分配后的值（NULL/非NULL）、是否被重新赋值、函数签名中是否有 __attribute__((nonnull)) 标注
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：编译选项中是否启用 -fsanitize=null（UBSan 空指针检测）、是否有静态分析器标注（__attribute__((returns_nonnull))）
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "malloc(1024) 返回值赋给 buf", "file": "src/reader.c", "line": 20},
    "propagate": {"description": "无 NULL 检查分支，直接使用 buf", "file": "src/reader.c", "line": 21},
    "sink": {"description": "buf[0] = getchar() 在 buf 可能为 NULL 时解引用", "file": "src/reader.c", "line": 22}
  },
  "scenario": "Scenario 1: 动态内存分配后未判空直接解引用",
  "references_applied": ["cross-function.md", "false-positive.md", "exceptions.md"]
}
```
