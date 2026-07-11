---
name: secguard-cpp-double_free
description: "检测 C/C++ 代码中同一指针被多次释放导致的双重释放漏洞，包括错误处理路径和别名指针的双重释放"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.double
signal_filter: memory.double*
signal_source: call_sites[callee="free|delete"]
severity: critical
cwe: [CWE-415]
---

# double_free 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.double` |
| signal_filter | `memory.double*`（供 `secguard ./src c memory.double*` 过滤匹配） |
| signal_source | `call_sites[cat="memory"]` |
| 默认严重度 | Critical |

---

## Scenario 1: 同路径/条件分支双重释放（CWE-415）

### 威胁定义

同一块内存被 `free()`/`delete` 两次，导致堆分配器内部数据结构损坏。攻击者可利用此漏洞实现任意写。自定义释放函数（`xxx_free`/`xxx_destroy`）的重复调用同样危险。

**核心原则：每次分配对应恰好一次释放。释放后立即置 NULL 防止重复释放。**

### 检测逻辑

**Step 1: 搜索释放操作**

搜索所有内存释放点，包括标准函数和自定义分配器：

```c
// 标准 C 库
free(ptr);

// C++
delete ptr;
delete[] ptr;

// 自定义分配器（大厂常见模式）
xxx_free(ptr);           // 如 my_free, pool_free, Z_FREE, obj_release
xxx_destroy(ptr);        // 如 object_destroy
FREE_xxx(ptr);           // 宏包装的释放
```

**自定义分配器识别规则**：在目标代码中搜索匹配 `*_free`、`*_destroy`、`*_release`、`FREE_*` 模式的函数名，这些应被视作 `free()` 的语义等价物。

**Step 2: 控制流分析**

对每个释放点，检查是否存在第二次释放同地址的路径。

**模式 1A：简单连续释放**
```c
// BAD: 同一个函数内两次 free
free(ptr);
// ... 无中间赋值 ...
free(ptr);                    // Double Free!
```

**模式 1B：条件分支后重复释放**
```c
// BAD: 条件路径中释放后未置 NULL
void func(int flag) {
    if (flag) {
        free(ptr);
        return;               // 释放，但未置 NULL
    }
    // ...
    free(ptr);                // flag 为真时 → double-free
}
```

**模式 1C：goto cleanup 双重命中**
```c
// 需要仔细判断：goto cleanup + return 路径是否重叠
int init() {
    char *buf = malloc(1024);
    if (step1() < 0) goto cleanup;
    if (step2() < 0) {
        free(buf);
        return -1;            // 正确跳过 cleanup
    }
    return 0;
cleanup:
    free(buf);                // 仅 step1 失败时执行 → 安全
    return -1;
}
```

### 检测模式

```
# MATCH（触发检测）

# 同一函数内两次 free/delete（排除中间有赋值）
free|delete|xxx_free|xxx_destroy
→ (中间无 ptr = NULL|ptr = nullptr)
→ free|delete|xxx_free|xxx_destroy (同一变量)

# free 无后续 NULL 赋值
free|xxx_free(ptr)
→ (无 ptr = NULL)
→ 函数内后续代码仍使用 ptr 或再次 free|xxx_free(ptr)


# EXCLUDE（不报告）
→ free.*\);\s*(p\w*|ptr\w*)\s*=\s*(NULL|nullptr)      # 释放后置空
→ std::unique_ptr|std::shared_ptr                       # 智能指针 RAII
→ if\s*\(.*\)\s*\{.*free.*\}.*else                     # 互斥分支
→ realloc\(.*,\s*0\)                                    # realloc 归零（语义等同 free）
→ pool_free_all|pool_destroy|alloc_destroy              # 内存池批量释放
→ safe_free\(&                                          # 封装的安全释放函数
```

### 修复指引

1. **释放后置 NULL**：`free(ptr); ptr = NULL;` — 对 NULL 调用 free 是安全的
2. **错误路径置 NULL**：在错误处理 `free(p)` 后立即 `p = NULL`
3. **goto cleanup 模式**：确保 cleanup 标签只在唯一路径执行，或在 cleanup 前置 NULL

---

## Scenario 2: 指针别名双重释放（CWE-415）

### 威胁定义

同一块内存被两个或多个指针引用，其中一个释放后另一指针相同地址再次释放。别名关系可能来自直接赋值、结构体嵌套或函数参数传递。

**核心原则：每个分配地址只能释放一次。别名指针释放前必须确认目标地址未被释放。**

### 检测逻辑

**模式 2A：直接指针别名**
```c
// BAD: 别名指向同一内存
char *alias = buf;
free(buf);
free(alias);                   // Double Free! 别名指向同一地址
```

**模式 2B：结构体嵌套**
```c
// BAD: 结构体内部指针别名
free(d->inner);
free(d);                       // 如果 free(d) 内部也释放 d->inner 则为 double-free
```

### 检测模式

```
# MATCH
p2 = p1
→ free|xxx_free(p1)
→ free|xxx_free(p2)


# EXCLUDE（不报告）
→ p2\s*=\s*NULL               # 别名已指向 NULL
→ std::unique_ptr|std::shared_ptr   # 智能指针
```

### 修复指引

1. **避免别名**：确保释放前没有其他指针指向同一内存
2. **释放后立即置 NULL**：`free(buf); buf = NULL;` — 即使存在别名，原指针可安全重复释放
3. **统一释放语义**：明确所有权 — 只有一个函数/模块负责释放

---

## Scenario 3: 跨函数双重释放（CWE-415）

### 威胁定义

同一指针在多个函数中被释放，通过调用图确认可达路径触发两次释放。常见于初始化失败 + 析构路径重叠、或所有权语义不明确的代码。

**核心原则：跨函数传递指针时必须明确释放责任。所有权转移后调用方不得再释放。**

### 检测逻辑

**模式 3A：多次调用清理函数**
```c
// BAD: 清理函数可被多次调用
void free_data(struct Data *d) {
    free(d->ptr);
}

void process() {
    struct Data d = {.ptr = malloc(100)};
    free_data(&d);
    free_data(&d);   // 第二次调用 → double-free
}

// SAFE: 清理后置 NULL
void free_data(struct Data *d) {
    free(d->ptr);
    d->ptr = NULL;
}
```

**模式 3B：跨函数释放 + 调用者再释放**
```c
// BAD: cleanup 已释放，调用者再次释放
void cleanup(char *p) {
    free(p);
}
void process() {
    char *buf = malloc(100);
    cleanup(buf);
    free(buf);                  // Double Free! cleanup 已经释放
}
```

**跨函数追踪规则**：

- 当 free(p) 在函数 A 和函数 B 中、且 A 调用 B 时 → 深度 1
- 深度超过 1 层（A→B→C）→ 降级为 suspicious
- 查调用图确认是否存在调用关系
- 若函数 A 调用函数 B，且 A 和 B 都对同一指针调用了 free → 确认

> 完整跨函数分析参见 [cross-function.md](references/cross-function.md)

### 检测模式

```
# MATCH
call cleanup(p)               # 函数内调用释放函数
→ free(p)                     # 调用点后续再次释放

# 同指针在不同函数中释放
函数 A 内 free(ptr)
函数 B 内 free(ptr)
A 可到达 B (通过调用图)       # → 可达路径 double-free
```

### 修复指引

1. **所有权文档化**：明确每个函数是否拥有指针所有权
2. **释放后置空**：`free(p); p = NULL;` 在所有释放点执行
3. **统一释放入口**：使用 `safe_free(&ptr)` 封装释放 + 置空
4. **RAII**：C++ 优先使用 `std::unique_ptr`/`std::shared_ptr`

---

## 已知安全模式（所有 Scenario 通用）

```c
// SAFE: 置 NULL 后 free
free(p);
p = NULL;
free(p);           // free(NULL) 安全

// SAFE: 互斥分支
if (mode == A) {
    free(p);
} else {
    // p 只在 A 路径释放
}

// SAFE: 重新分配
free(p);
p = malloc(512);
free(p);           // 释放新分配，非双重释放

// SAFE: 引用计数控制释放
if (--refcount == 0) {
    free(p);       // 引用计数保证只释放一次
}
```

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

**路径不可达（不构成 double-free）**：

**路径可达（double-free）**：

**指针重新赋值后**：

**NULL 重置模式**：

**错误处理路径**：


---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: {存在性 — 同一指针是否被释放 (free/delete) 两次?}

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: {可利用性 — 两次释放之间是否存在路径混淆 (不同分支/循环/跨函数)?}

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: {缓解 — 指针在释放后是否被置为 NULL (ptr = NULL after free)?}

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
    "Q1_dfree_exist": true|false,
    "Q2_dfree_exploit": true|false,
    "Q3_dfree_mitigate": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：两次释放操作的完整代码块，包含第一次释放（free/delete/xxx_free）和第二次释放（同一指针变量），标注两次释放之间的代码路径（包括条件分支和 goto 跳转）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析两次释放之间是否存在 ptr=NULL 赋值——如果没有置空且存在代码路径可到达第二次释放，则为 Double Free；若涉及指针别名，确认两个别名变量是否指向同一分配地址；检查是否有条件分支导致互斥路径下的重复释放
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：指针从 malloc 分配 → 第一次释放 → （可能置 NULL/重新赋值）→ 第二次释放的完整生命周期数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若为跨函数双释放，记录分配函数 → 第一次释放函数 → 第二次释放函数的完整调用链
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：指针值在每次释放前后的状态、是否存在别名变量、两次释放之间的条件分支条件值
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了 std::unique_ptr 自动管理生命周期、是否有 safe_free(&ptr) 封装函数、是否配置了 MALLOC_CHECK_ 环境变量
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "第一次 free(p) 在 shutdown()", "file": "src/cleanup.c", "line": 42},
    "propagate": {"description": "p 未重新赋值，控制流可通过 return 路径到达第二次 free", "file": "src/cleanup.c", "line": 43},
    "sink": {"description": "第二次 free(p) 在 cleanup() → 同一指针释放两次", "file": "src/cleanup.c", "line": 55}
  },
  "scenario": "Scenario 1: 同路径/条件分支双重释放",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
