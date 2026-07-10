---
name: secguard-cpp-memory_leak
description: "检测 C/C++ 代码中动态分配内存后未释放导致的内存泄漏，包括分配-释放不匹配和异常路径泄漏"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.leak
signal_filter: memory.leak*
signal_source: call_sites[cat="memory"]
severity: high
cwe: [CWE-401]
---

# memory_leak 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | memory.leak |
| signal_filter | memory.leak* |
| signal_source | call_sites[cat="memory"] |
| severity | high |
| CWE | CWE-401 |

## 信号预筛

从 index.json 的 call_sites 和 alloc_free.pairs 中筛选：

- callee 匹配: malloc, calloc, realloc, free, strdup, new, new[]
- 配对数据源: alloc_free.pairs 中的每条记录
  - alloc_func / alloc_file / alloc_line / alloc_function
  - free_sites 数组（每个释放点的 file + line + free_func）
- 未配对分配: free_sites 为空的记录 → 高优先级疑似泄漏

---

## Scenario 1: 异常路径泄漏 (Error-Path Leak)

### Threat Definition

通过 `malloc`/`calloc`/`new` 分配的堆内存，在函数的中途退出路径（错误/异常处理路径）上没有释放，导致进程内存持续增长。C/C++ 无 GC，内存泄漏是常见但可防止的问题。

**真泄漏 vs 刻意不释放**：
- **真泄漏**：每个请求/迭代中分配但不释放 → 内存持续增长
- **非泄漏**：全局缓冲区、Arena 分配器、main() 中单次分配的 exit-time 回收

### Detection Logic

检查分配所在函数的所有退出路径上，每个 malloc/calloc/realloc 分配点要么被 free() 释放，要么所有权被明确转移给调用者。

**Step 1: 识别分配点（含自定义分配器）**

标准 C/C++ 和命名约定匹配的自定义分配器：
```
malloc / calloc / realloc / strdup
new / new[]
xxx_malloc / xxx_alloc / xxx_new / xxx_create / ALLOC_xxx
```

**Step 2: 追踪释放路径**

识别以下模式：

1. **错误路径未释放**（最常见）：
```c
// LEAK: 中间失败直接返回
char *load_file(const char *path) {
    FILE *f = fopen(path, "r");
    char *buf = malloc(4096);
    if (!f) return NULL;        // LEAK: buf 未释放
    if (fread(buf, 1, 4096, f) < 0) {
        fclose(f);
        return NULL;            // LEAK: buf 未释放
    }
    fclose(f);
    return buf;                 // 所有权转移给调用者
}

// SAFE: 所有路径都释放
char *load_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return NULL;
    char *buf = malloc(4096);
    if (!buf) { fclose(f); return NULL; }
    if (fread(buf, 1, 4096, f) < 0) {
        free(buf); fclose(f);
        return NULL;
    }
    fclose(f);
    return buf;                 // 所有权转移给调用者
}
```

2. **无条件不释放**（函数中永不释放）：
```c
// LEAK: 分配后永不释放
char *process(const char *input) {
    char *copy = strdup(input);
    return copy;
}
```
判定: 若函数名暗示返回新分配（如 `duplicate`、`copy`、`clone`），所有权转移 → 非泄漏。若函数名 `process`、`handle` → caller 可能不知道需释放。

3. **goto cleanup 模式（安全）**：
```c
char *p = malloc(1024);
char *q = malloc(512);
if (!p || !q) {
    free(p);
    free(q);
    return NULL;
}
// ... 使用 ...
cleanup:
    free(p);
    free(q);
    return ret;  // 统一释放点
```

### Detection Patterns

**MATCH**:
```
# 分配 + 中间 return 无释放
(malloc|calloc|new|ALLOC_|_alloc|_malloc)\(
→ (同一函数, 之后) return|goto.*(?!cleanup|error|fail)
→ (return 之前, 同路径) 无 free|delete|xxx_free|xxx_release
→ evidence: call_stack (记录从分配到提前返回的调用路径)
```

**EXCLUDE**:
```
# goto cleanup 模式 → evidence: code_context
goto\s+cleanup|goto\s+err|goto\s+fail  # 在标签处存在统一释放逻辑

# RAII 包装 → evidence: code_context
std::unique_ptr|std::shared_ptr|std::vector|std::string

# Arena/Zone 释放 → evidence: sanitizer_analysis
pool_free_all|zone_destroy|arena_reset|ALL_FREE
```

### Remediation Guide

1. **C++ 首选**：`std::unique_ptr<T>` / `std::shared_ptr<T>` / RAII
   ```cpp
   // SAFE: unique_ptr 自动释放
   std::unique_ptr<char[]> buf(new char[1024]);
   ```

2. **C 代码**：使用 `goto cleanup` 模式统一资源释放
   ```c
   char *buf = malloc(4096);
   if (!buf) goto cleanup;
   if (error_cond) goto cleanup;
   // ... 使用 ...
   cleanup:
       free(buf);
       return ret;
   ```

3. **Arena 分配（整体管理）**：
   ```c
   // SAFE: arena 在函数结束时整体释放
   void *arena = malloc(ARENA_SIZE);
   char *p1 = arena_alloc(arena, 100);
   // 无需单独释放 p1
   arena_free(arena);  // 一次性释放全部
   ```

4. **不报告的场景**（刻意不释放）：

   | 模式 | 原因 |
   |------|------|
   | `main()` 中单次分配直到程序退出 | OS 回收 |
   | Arena/Zone 分配器 `pool_alloc` + 批量 `pool_free_all` | 整体管理 |
   | `static` 变量初始化分配 | 生命周期 = 程序 |
   | `atexit()` 注册的释放回调 | 程序退出时执行 |

---

## Scenario 2: 循环分配泄漏 (Loop Allocation Leak)

### Threat Definition

在循环体内分配堆内存但每次迭代结束后没有释放，使得每次迭代分配的指针在下一次迭代时被覆盖，旧内存块永远无法释放。循环迭代次数越多，内存消耗越大，最终耗尽系统资源。

### Detection Logic

**Step 1: 识别循环内分配**

检查 for / while 循环体内是否存在 malloc / calloc / new 等分配调用。

**Step 2: 检查释放配对**

```c
// LEAK: 每次循环分配，退出时不清理
for (int i = 0; i < n; i++) {
    char *tmp = malloc(100);
    compute(tmp, i);
    // tmp 在下次迭代时丢失引用
}

// SAFE
for (int i = 0; i < n; i++) {
    char *tmp = malloc(100);
    compute(tmp, i);
    free(tmp);
}
```

**Step 3: 检查指针逃逸**

若分配后的指针被保存到循环外的作用域（如全局变量、传出参数、返回给调用者），则视为所有权转移，不报告。

```c
char *global_buf = NULL;

// SAFE: 指针保存在全局变量中，非泄漏
for (int i = 0; i < n; i++) {
    if (!global_buf) {
        global_buf = malloc(1024);
    }
}
```

### Detection Patterns

**MATCH**:
```
# 循环内分配无配对释放 → evidence: code_context
(for|while)\s*\(
→ 循环体内 (malloc|calloc|new)
→ 循环体内无 free|delete
→ 且指针未保存到循环外的作用域
→ evidence: variable_state (记录每次迭代分配的指针是否被覆盖)
```

**EXCLUDE**:
```
# 循环体内存在 free
循环体内有 free(tmp) / delete tmp

# 指针逃逸到循环外作用域
ptr 赋值给全局变量 / 传出参数 / return 值
```

### Remediation Guide

1. **循环内释放**：在循环体末尾释放分配的内存
2. **复用缓冲区**：在循环外分配一次，循环内复用
   ```c
   char *buf = malloc(1024);
   for (int i = 0; i < n; i++) {
       compute(buf, i);
   }
   free(buf);
   ```
3. **编译器辅助**：启用 `-fanalyzer` (GCC 10+) 或 clang static analyzer

---

## Scenario 3: 指针覆盖与 realloc 误用 (Pointer Overwrite & realloc Misuse)

### Threat Definition

已分配内存的指针变量在没有先释放的情况下被重新赋值为新分配的内存地址，导致原内存块永远不可达（泄漏）。realloc 返回 NULL 时的错误处理不当也会导致原内存地址丢失。

### Detection Logic

**Step 1: 检测指针覆盖**

```c
// LEAK: 原指针被覆盖，无法再释放
char *buf = malloc(1024);
buf = malloc(2048);     // 原 1024 字节泄漏
free(buf);             // 仅释放第二次分配

// SAFE
char *buf = malloc(1024);
// ... use buf ...
free(buf);
buf = malloc(2048);
```

**Step 2: 检测 realloc 误用**

```c
// LEAK: 使用自身 realloc，失败时原指针丢失
p = realloc(p, 2048);  // 若 realloc 返回 NULL，p=NULL 且原内存未释放

// SAFE
tmp = realloc(p, 2048);
if (tmp == NULL) {
    free(p);            // 释放原内存
    return -1;
}
p = tmp;
```

**Step 3: 检测多次覆盖**

```c
// NOT AN EXCEPTION: realloc 多次覆盖
p = malloc(1024);
p = malloc(2048);  // 1024 泄漏
p = malloc(4096);  // 2048 泄漏
free(p);           // 仅释放 4096
```

### Detection Patterns

**MATCH**:
```
# 指针重新赋值前未释放旧值 → evidence: variable_state
\w+\s*=\s*(malloc|calloc|new)
→ 同变量再次 \w+\s*=\s*(malloc|calloc|new)
→ 两次之间无 free|delete
→ evidence: data_flow_path (记录指针变量从首次分配到覆盖的路径)
```

**EXCLUDE**:
```
# 指针被置 NULL 后不再可达 → 释放标记
ptr = NULL 之后的重新赋值

# 赋值前存在 free 或 delete
```

### Remediation Guide

1. **先释放再赋值**：
   ```c
   free(buf);
   buf = malloc(2048);
   ```

2. **realloc 安全模式**：
   ```c
   char *tmp = realloc(p, new_size);
   if (tmp == NULL) {
       free(p);  // 保留原指针，手动释放
       return ENOMEM;
   }
   p = tmp;
   ```

3. **使用智能指针（C++）**：
   ```cpp
   auto buf = std::make_shared<std::vector<char>>(1024);
   // 重新赋值前自动释放旧内存
   buf = std::make_shared<std::vector<char>>(2048);
   ```

4. **启用编译器检查**：`-fanalyzer` (GCC 10+) 或 clang static analyzer

---

## 已知安全模式 (Known Safe Patterns)

以下模式中分配的内存不视为泄漏：

### RAII (C++)

```cpp
// SAFE: unique_ptr 自动释放
std::unique_ptr<char[]> buf(new char[1024]);

// SAFE: shared_ptr
auto buf = std::make_shared<std::vector<char>>(1024);

// SAFE: scoped_ptr / auto_ptr
boost::scoped_ptr<Foo> p(new Foo());
```

### Arena 分配（整体管理）

```c
// SAFE: arena 在函数结束时整体释放
void *arena = malloc(ARENA_SIZE);
char *p1 = arena_alloc(arena, 100);
char *p2 = arena_alloc(arena, 200);
// 无需单独释放 p1/p2
arena_free(arena);  // 一次性释放全部
```

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。




**简单函数（单一 return）**:

**多 return 函数**:

**goto cleanup 模式（安全）**:


---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: {存在性 — 分配路径 (malloc/calloc/realloc) 是否缺少对应的释放路径 (free)?}

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: {可利用性 — 错误路径或提前返回是否绕过了释放点?}

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: {缓解 — 是否存在 RAII 包装器、智能指针或 goto cleanup 模式管理生命周期?}

**Yes** = 存在有效的缓解措施消除了风险
**No**  = 不存在任何缓解措施

### 判定矩阵

| Q1 | Q2 | Q3 | 结论 |
|----|----|----|-----------|
| Yes | Yes | No | **CONFIRMED** — 漏洞存在且可利用，无缓解 |
| Yes | No | No | **CONFIRMED** — 存在但不可利用（降低严重度） |
| Yes | Yes | Yes | **SUPPRESS** — 缓解措施消除风险 |
| Yes | No | Yes | **SUPPRESS** — 缓解措施足够 |
| No | — | — | **SUPPRESS** — 此上下文漏洞不成立 |
| Unknown | — | — | **保留为 Unknown** — 降级为 informational |

### 输出整合

在 finding 的 evidence 中附加：
```json
"judgment_matrix": {
    "Q1_leak_exist": true|false,
    "Q2_leak_exploit": true|false,
    "Q3_leak_mitigate": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集 (MUST)

- [ ] **code_context**：分配点及所有释放路径代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：是否存在无条件释放的路径
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)

- [ ] **data_flow_path**：分配→使用→释放（或泄漏）的完整路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：分配函数到函数返回的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)

- [ ] **variable_state**：指针值/分配大小/引用计数
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用 LeakSanitizer 或 -fanalyzer
      → findings.evidence.sanitizer_analysis

---

## 误报排除汇总

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动释放 | 确认指针由智能指针管理，离开作用域时自动调用析构函数释放资源 |
| 自定义 Arena/Pool：`pool_alloc` + `pool_free_all()` | 批量释放 | 确认存在配对的 `pool_free_all`/`arena_reset`/`zone_destroy` 等批量释放调用 |
| 全局/static 变量 | 整个程序生命周期 | 确认分配发生在全局/static 变量初始化中，生命周期与程序一致 |
| `main()` 或单次入口分配且程序很快退出 | OS 回收 | 确认分配仅在 main() 或单次入口函数中，程序为短生命周期工具 |
| `alloca()` 栈分配 | 函数返回自动回收 | 确认使用的是 `alloca`/`_alloca` 栈分配，非堆分配 |
| `atexit(cleanup_func)` | 程序退出时执行 | 确认 `atexit` 注册的回调函数中存在配对的释放逻辑 |
| 分配后赋值给带 `__attribute__((cleanup))` 的变量 | 自动清理 | 确认变量声明带有 `__attribute__((cleanup(cleanup_func)))`，且清理函数执行释放 |

### 抑制决策树

```
发现 alloc (malloc/calloc) 在函数 F 中
├─ F 所属文件为 test_* 或 *_test → SUPPRESS (info) [测试允许小泄漏]
├─ 分配在 static/global init 路径上
│  ├─ 进程存续期有效 → SUPPRESS (info)
│  └─ 库的 init/cleanup 模式 → SUPPRESS (high)
├─ 分配在循环中 → 循环内必须有 free
│  ├─ 循环体末尾 free → SUPPRESS (high)
│  └─ 无 free → CONFIRM (high)
├─ 分配在非循环函数中
│  ├─ 函数所有 return 路径检查 free
│  │  ├─ 全部有 free → SUPPRESS (high)
│  │  ├─ 部分有 → 查缺少的路径
│  │  │  ├─ goto cleanup 模式 → SUPPRESS (high)
│  │  │  └─ 直接 return → CONFIRM (high)
│  │  └─ 全部无 free → 看所有权
│  │     ├─ return 该指针 → 查看调用者
│  │     │  ├─ 调用者 free → SUPPRESS
│  │     │  └─ 调用者无 free → CONFIRM (high)
│  │     └─ 不返回指针 → CONFIRM (high)
│  └─ RAII/智能指针 → SUPPRESS (high)
└─ 分配在函数入口，函数类成员
   ├─ 有析构函数释放 → SUPPRESS (high)
   └─ 无析构 / C 风格 → CONFIRM (high)
```

---

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "malloc(4096) 在 load_config() 中分配", "file": "src/config.c", "line": 30},
    "propagate": {"description": "在函数 3 个 return 路径中仅 1 个调用了 free()", "file": "src/config.c", "line": 30},
    "sink": {"description": "return -1 路径在 line:50，return NULL 路径在 line:65，均跳过 free", "file": "src/config.c", "line": 50}
  },
  "references_applied": ["rule.md", "cross-function.md", "false-positive.md", "exceptions.md"]
}
```
