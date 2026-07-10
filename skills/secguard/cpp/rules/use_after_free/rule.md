---
name: secguard-cpp-use-after-free
description: "检测 free 后继续使用指针导致的释放后使用（UAF）漏洞"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.use
signal_filter: memory.use*
signal_source: call_sites[cat="memory"]
severity: critical
cwe: [CWE-416]
---

# use_after_free 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | memory.use |
| signal_filter | memory.use* |
| signal_source | call_sites[cat="memory"] |
| severity | critical |
| cwe | CWE-416 |
| precision | very-high |
| confidence | dynamic |

## Scenario 1: 同函数内直接释放后使用

### 威胁定义

指针在 `free()`/`delete` 后继续被读写，导致访问已释放内存。已释放内存可能被分配器重新分配给其他对象，攻击者可通过堆风水（heap feng shui）实现代码执行。这是 CWE Top 25 中最危险的漏洞之一。

**核心原则**：释放后立即置 NULL，且后续代码不得悬空使用。检测时必须识别自定义分配器（`xxx_free`/`xxx_destroy`/`xxx_release`/`FREE_xxx`）—— 它们和标准 `free` 一样危险。

### 检测逻辑

#### Step 1: 搜索释放点后的指针使用

定位每个释放调用，然后追踪该函数作用域内指针的后续使用：

```c
// 标准释放
free(ptr);
delete ptr;
delete[] ptr;

// 自定义释放（大厂常见模式）
xxx_free(ptr);           // 如 my_free, pool_free
xxx_destroy(ptr);        // 如 object_destroy
xxx_release(ptr);        // 如 ZoneRelease
FREE_xxx(ptr);           // 宏释放
```

**自定义分配器识别**：目标代码中 `*_free`、`*_destroy`、`*_release`、`FREE_*` 的函数都应视作释放操作，后续使用同样为 UAF。

#### Step 2: 使用模式分类

**模式 A — 直接释放后解引用：**
```c
// BAD
free(ptr);
ptr->field = 1;  // UAF

// BAD: 释放后读
free(conf);
printf("%s", conf->name);  // UAF
```

**模式 B — 释放后写入：**
```c
// BAD
free(p);
memcpy(p, data, len);  // UAF

// BAD
free(buf);
snprintf(buf, size, "%s", val);  // UAF
```

**模式 C — 释放后将指针作为参数传递：**
```c
// BAD
free(ptr);
do_something(ptr);  // 传递已释放指针
```

**模式 D — C++ 成员函数返回 this 指针的悬空引用：**
```c++
// BAD: 临时对象成员函数返回的指针
std::string temp = get_name();
const char *ptr = temp.c_str();
// temp 被销毁...
printf("%s", ptr);             // 悬空指针!
```

### 检测模式

```
# === MATCH (触发检测) ===

# free/delete 后同作用域使用
free(ptr)|delete ptr
                                                       # → MUST: code_context (释放点+后续使用点)
→ (无 ptr = NULL|ptr = nullptr|return)
→ 访问 ptr|ptr->|*ptr|ptr[
                                                       # → MUST: judgment_rationale (释放后置空检查+别名分析)

# === EXCLUDE (不报告) ===
→ free\(.*\);\s*(p\w*|ptr\w*)\s*=\s*(NULL|nullptr)   # 释放后置空
→ std::unique_ptr|std::shared_ptr                      # 智能指针管理
→ return;|exit\(|goto\s+                               # 不可达控制流
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `free(p); p = NULL;` 后使用 p | 使用 NULL 而非已释放内存 | 确认 free 行和后续使用行之间存在 `p = NULL` 或 `p = nullptr` 赋值 |
| `std::unique_ptr::reset()` 后 RAII | unique_ptr 自动置空 | 确认指针由 std::unique_ptr 管理，非裸指针 |
| 静态分析已排除的死代码 | 不可达路径中的使用 | 确认释放点后存在 return/exit/goto 等不可达控制流 |
| 释放后仅地址比较 | `if (p == other_ptr)` 不访存 | 确认操作为指针地址比较，非内容解引用 |

### 修复指引

1. **释放后置 NULL**：`free(ptr); ptr = NULL;` — 后续使用 NULL 会崩溃而非被利用
2. **C++ 使用智能指针**：`std::unique_ptr::reset()` 自动置空
3. **提前 return**：`free(buf); return;` — 无后续使用路径
4. **引用计数保护**：`if (--refcount == 0) { free(p); }` — 其他使用者仍合法

## Scenario 2: 别名传递与跨函数释放后使用

### 威胁定义

同一指针存在多个别名时，释放其中一个别名后，其他别名仍然指向已释放内存。或者 free 在一个函数中完成而解引用在另一个函数中，调用者传递已被释放的指针给被调用者。

### 检测逻辑

**模式 A — 别名使用：**
```c
// BAD: p2 指向已释放内存
char *p2 = p;
free(p);
p2[0] = 'x';  // UAF
```

指针别名检查：在同一作用域内查找指向同一地址的所有变量，确认释放后是否有任何别名被解引用。

**模式 B — 跨函数传递：**
```c
// BAD: 释放后传递给其他函数
void process_data(char *data) {
    data->field = 1;    // UAF — data 已释放
}
void caller() {
    char *buf = malloc(100);
    free(buf);
    process_data(buf);
}
```

**跨函数追踪规则**：当 free 在函数 A 中完成，但指针解引用在函数 B 中、且 A 调用 B 时：

- **最大追踪深度**：1 层
```c
void A() {
    free(p);
    B(p);  // B 接收已释放指针
}
void B(void *ptr) {
    ptr->field = 1;  // UAF
}
```
- 超过 depth 1 的调用链 → 降级为 suspicious

**常见跨函数 UAF 模式：**
1. **回调函数**：释放后注册的回调被调用，使用已释放上下文
2. **事件循环**：free(event) 后事件处理中的 event->data 解引用
3. **函数指针表**：释放后函数表项仍可被调度调用

### 检测模式

```
# === MATCH (触发检测) ===

# 别名 UAF
p2 = p1
→ free(p1)
→ 使用 p2

# 跨函数 UAF
free(ptr) in function A
→ A 调用 B(ptr)
→ B 中解引用 ptr

# === EXCLUDE (不报告) ===
→ new_ptr\s*=\s*realloc                                # 使用新指针
→ if\s*\(new\w*\)|if\s*\(new_ptr                       # realloc 返回值检查
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 释放后函数内部重新赋值 | 赋值后指针不再指向已释放内存 | 确认 callee 第一行有 `ptr = new_value` 赋值 |
| 智能指针间接访问 | 智能指针自动管理生命周期 | 确认参数类型为 `std::unique_ptr<T>&` 或 `std::shared_ptr<T>` |
| 引用计数池化内存 | free 不真正释放，内存池复用 | 确认 free 被宏重定义或在自定义内存池作用域内 |

### 修复指引

1. **避免别名**：释放前确保无人持有该指针的副本
2. **释放后清空别名**：`free(p); p = NULL; p2 = NULL;`
3. **跨函数**：释放者负责置 NULL，调用链各方检查 NULL
4. **清晰的所有权语义**：谁分配谁释放，避免跨函数借用后释放

## Scenario 3: realloc 不当使用

### 威胁定义

`realloc()` 可能移动已分配内存块到新位置，旧指针变为无效。realloc 后继续使用旧指针构成 UAF。此外，`realloc(ptr, new_size)` 直接赋值给 `ptr` 在 realloc 失败时会导致原指针泄漏。

### 检测逻辑

**模式 A — realloc 后继续使用旧指针：**
```c
// BAD: realloc 可能移动内存，旧指针变为悬空
char *old = malloc(100);
char *newbuf = realloc(old, 200);
if (newbuf) {
    old[0] = 'a';  // UAF: old 可能无效
}
```

**模式 B — realloc 返回值直接覆盖原指针（悬空 + 泄漏）：**
```c
// BAD: realloc 失败时 ptr 仍有效但丢失，成功时旧指针悬空
ptr = realloc(ptr, new_size);
```

**安全变体：**
```c
// GOOD: 使用临时变量
char *newptr = realloc(ptr, new_size);
if (!newptr) {
    // ptr still valid, handle error
    free(ptr);
    return;
}
ptr = newptr;  // 更新指针
```

### 检测模式

```
# === MATCH (触发检测) ===

# realloc 后使用旧指针
old_ptr = malloc(N)
→ new_ptr = realloc(old_ptr, M)
→ 检查 new_ptr 后仍使用 old_ptr

# realloc 直接覆盖原指针
ptr = realloc(ptr, M)

# === EXCLUDE (不报告) ===
→ new_ptr\s*=\s*realloc                                # 使用新指针
→ if\s*\(new\w*\)|if\s*\(new_ptr                       # realloc 返回值检查
→ old\s*=\s*realloc\(old                               # 同名变量更新（仍有风险，但非 UAF 模式）
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `realloc` 返回的新指针不等 | 旧指针已通过 realloc 内部释放，但使用新指针安全 | 确认后续代码使用的是 realloc 返回的新指针变量，非旧指针变量 |
| 自定义内存池 | free 不是真正的释放，内存仍在池中 | 确认 free 被宏重定义或在自定义内存池作用域内，释放后内存仍可安全访问 |

### 修复指引

1. **realloc 后只使用新指针**：不再使用 `realloc` 前的旧指针
2. **临时变量接收 realloc 返回值**：避免直接 `ptr = realloc(ptr, n)` 导致泄漏
3. **检查 realloc 返回值**：失败时处理旧指针，成功时更新指针

## Scenario 4: 引用计数/所有权不匹配导致 Use-After-Free（合并自原 ownership_transfer）

### 威胁定义

引用计数增减不匹配——`AddRef`/`Release`、`ref`/`unref`、`get`/`put`、`acquire`/`release`、`retain`/`release`——在函数或调用链上不均衡。**减大于增（under-ref）**：`Release` 多于 `AddRef`，引用计数提前归零，资源被释放但仍有悬空指针访问 → **Use-After-Free**（CWE-416）。别名/容器/跨函数转移所有权后释放方释放、使用方仍持悬空引用亦同。

> 注：增大于减（over-ref）导致资源永不释放，属**内存泄漏**（CWE-401，见 memory_leak 规则），非本场景。

### 检测逻辑

1. 识别引用计数函数对（`*_ref`/`*_unref`、`*_AddRef`/`*_Release`、`*_retain`/`*_release` 等），建 inc/dec 映射
2. 同函数/作用域内对每个 inc 搜对应 dec，分析所有退出路径（return/break/continue/goto/异常）
3. **under-ref**（dec 多于 inc，或 inc 后某退出路径无 dec 致提前归零）→ 标记 UAF：释放后悬空访问

```c
// BAD: dec 多于 inc — 提前释放 → UAF
obj_get(o);      // +1
obj_put(o);      // -1
obj_put(o);      // -1（无对应 get！）→ refcount=0 释放 → 后续访问 UAF
```

### 误报排除

- over-ref（inc 多于 dec，泄漏）→ 归 memory_leak，非本规则
- 配对的 inc/dec（每条路径均衡）→ SAFE
- 引用计数由 RAII/智能指针管理（C++）→ SAFE

## 安全模式汇总（所有场景通用）

以下模式在任何场景中均不报告 UAF：

```c
// SAFE: 置 NULL
free(ptr);
ptr = NULL;

// SAFE: 重新分配
free(p);
p = malloc(100);
p->field = 1;  // 安全

// SAFE: 提前 return
free(buf);
return;
```

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。



**指针别名**：检查同一区域内是否有别名指向同一地址

**realloc 后使用旧指针**：


---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: {存在性 — 指针在 free()/delete 之后是否被解引用 (*ptr 或 ptr->field)?}

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: {可利用性 — free 和解引用之间的代码路径是否运行时可达 (无 NULL 保护)?}

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: {缓解 — 指针在 free 后是否被重新赋值或置为 NULL?}

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
    "Q1_uaf_exist": true|false,
    "Q2_uaf_exploit": true|false,
    "Q3_uaf_mitigate": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集 (MUST)
- [ ] **code_context**：释放操作（free/delete/xxx_free 等）及其后续同作用域内指针使用点的完整代码，标注释放行号和后续使用行号之间的代码路径 → findings.evidence.code_context
- [ ] **judgment_rationale**：分析释放点与后续使用点之间是否存在 ptr=NULL 赋值——如果没有置空且后续代码直接或间接访问指针（->、*ptr、ptr[...]、函数参数传递），则为 UAF；若涉及别名，确认别名的声明时间和使用场景 → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：指针从 malloc/new 分配 → 使用 → free/delete 释放 → （可能置 NULL）→ （悬空访问）的完整生命周期数据流 → findings.evidence.data_flow_path
- [ ] **call_stack**：若为跨函数 UAF，记录分配函数 → 释放函数 → 悬空使用函数的完整调用链 → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：指针值在分配后/释放后的状态、是否存在别名变量（p2=p1）、realloc 返回值是否覆盖了原始指针 → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了 std::unique_ptr/std::shared_ptr 自动管理、是否有 AddressSanitizer 运行时检测（-fsanitize=address） → findings.evidence.sanitizer_analysis
- [ ] **cross_signal_analysis**：当多信号归并分析发生时，记录归并依据和 cross_signal_analysis 标记 → findings.evidence.cross_signal_analysis

## 输出格式

每个 finding 遵循三段式证据链：

1. **问题定位**：释放点行号 + 解引用点行号
2. **证据链**：code_context（释放操作 + 后续使用代码） + judgment_rationale（置空检查 + 别名分析）
3. **分类分级**：severity（critical）、CWE-416、scenario 归属

输出模板：
```json
{
  "rule": "use_after_free",
  "scenario": "同函数直接释放后使用 | 别名与跨函数释放后使用 | realloc 不当使用",
  "severity": "critical",
  "cwe": "CWE-416",
  "evidence": {
    "code_context": "<free_line>-<use_line> 行代码路径",
    "judgment_rationale": "<置空检查结论 + 别名分析结论>",
    "data_flow_path": "<分配→释放→使用的完整数据流>",
    "call_stack": "<跨函数调用链>"
  }
}
```
