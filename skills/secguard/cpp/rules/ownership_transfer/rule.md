---
name: secguard-cpp-ownership_transfer
description: "Detect use-after-free via ownership transfer violations including realloc misuse, mismatched alloc/dealloc, refcount mismatch, and container-stored dangling pointers"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.ownership
signal_filter: memory.ownership*
signal_source: call_sites[cat="memory"]
severity: high
cwe: [CWE-416]
---

# ownership_transfer 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | memory.ownership |
| signal_filter | memory.ownership* |
| signal_source | call_sites[cat="memory"] |
| severity | high |
| cwe | CWE-416 |
| precision | high |
| confidence | dynamic |

## Scenario 1: realloc 不当使用与不匹配释放

### 威胁定义

`realloc()` 可能移动已分配内存块到新位置，旧指针变为无效。realloc 后继续使用旧指针构成 Use-After-Free。此外，分配和释放函数不配对（`malloc`→`delete` 或 `new`→`free`）导致未定义行为，不同分配体系使用不同的内部数据结构，混用必然导致堆损坏。C/C++ 混合代码和自定义分配器是高发场景。

**核心原则**：
- realloc 后**只使用新指针**，旧指针不再访问
- `malloc`↔`free`、`new`↔`delete`、`new[]`↔`delete[]`、`xxx_alloc`↔`xxx_free` 严格配对

### 检测逻辑

#### Step 1: 搜索 realloc 调用与旧指针使用

定位每个 `realloc` 调用，然后追踪调用点后续是否仍使用旧的输入指针：

```c
// BAD: realloc 可能移动内存，旧指针已无效
char *old = malloc(100);
char *newbuf = realloc(old, 200);
if (!newbuf) return;
old[0] = 'a';                            // USE-AFTER-FREE: old 已无效
memcpy(old, data, 10);                    // USE-AFTER-FREE: 写入已释放内存

// BAD: realloc 返回值直接覆盖原指针（双问题）
ptr = realloc(ptr, new_size);            // 失败时原指针泄漏，成功时旧地址悬空
```

**安全变体：**
```c
// GOOD: 使用临时变量接收 realloc 返回值
char *newptr = realloc(ptr, new_size);
if (!newptr) {
    free(ptr);                            // 失败时妥善处理旧指针
    return;
}
ptr = newptr;                             // 更新指针
// 后续只使用 ptr
```

#### Step 2: 分配/释放对分析

| 分配函数 | 正确释放函数 | 错误释放 |
|---------|-------------|----------|
| `malloc`/`calloc`/`realloc` | `free()` | `delete` / `delete[]` |
| `new` | `delete` | `free()` / `delete[]` |
| `new[]` | `delete[]` | `free()` / `delete` |
| `strdup`/`asprintf` (POSIX) | `free()` | `delete` |

#### Step 3: 危险模式检测

```c
// BAD: malloc + delete
char *buf = (char*)malloc(100);
delete buf;                            // UB!

// BAD: new + free
int *arr = new int[10];
free(arr);                             // UB! 析构函数不会被调用

// BAD: new + delete[] / new[] + delete
MyClass *p = new MyClass;
delete[] p;                            // 类型不匹配
```

#### Step 4: 自定义分配器配对检查

大厂项目几乎不使用裸 `malloc`/`free`，而是通过自定义包装器管理内存。

**常见自定义分配器命名模式：**

| 分配端 | 释放端 | 示例项目 |
|--------|--------|---------|
| `xxx_malloc(s)` | `xxx_free(p)` | 内核、嵌入式 |
| `xxx_alloc(s)` | `xxx_free(p)` / `xxx_dealloc(p)` | 游戏引擎 |
| `xxx_new(...)` | `xxx_delete(p)` / `xxx_destroy(p)` | C 风格 OOP |
| `xxx_create(...)` | `xxx_destroy(p)` / `xxx_release(p)` | 资源管理器 |
| `ALLOC_xxx(s)` | `FREE_xxx(p)` | 宏包装 |
| `pool_alloc(s)` | `pool_free(p)` | 内存池 |
| `zone_alloc(z, s)` | `zone_free_all(z)` | Arena/Zoned allocator |

**危险混用模式：**
```c
// BAD: 用 free() 释放自定义分配器返回的内存
void *p = my_alloc(100);
free(p);                             // 堆损坏！

// BAD: 用 A 的分配器和 B 的释放器
void *p = zone_alloc(zone_a, 100);
pool_free(pool_b, p);                // 跨分配器释放

// BAD: 自定义释放器释放标准 malloc 的内存
void *p = malloc(100);
my_free(p);                          // my_free 可能期望 pool header
```

**检测规则：**
1. 识别项目中所有 `*_alloc`/`*_malloc`/`*_new`/`*_create`/`ALLOC_*` 函数
2. 找到每个分配函数对应的释放函数（通常命名成对）
3. 检查每个分配/释放调用：是否来自同一"家族"
4. `free()` 只应释放 `malloc`/`calloc`/`realloc` 返回的指针，不能释放自定义分配器的内存

### 检测模式

```
# === MATCH (触发检测) ===

# realloc 后使用旧指针
old_ptr = malloc(N)
→ new_ptr = realloc(old_ptr, M)
→ 检查 new_ptr 后仍使用 old_ptr
                                          # → MUST: code_context (realloc 调用+后续旧指针使用)

# realloc 直接覆盖原指针 (失败时泄漏)
ptr = realloc(ptr, M)
                                          # → MUST: code_context (realloc 赋值模式)
                                          # → SHOULD: data_flow_path (realloc 成功/失败两路径分析)

# malloc + delete → evidence: code_context
malloc|calloc|realloc
→ delete | delete[]
                                          # → MUST: variable_state (分配函数和释放函数类型)

# new + free → evidence: code_context
new | new[]
→ free
                                          # → MUST: variable_state (分配函数和释放函数类型)

# new/delete 数组标量混用
new T        → delete[] p
new T[n]     → delete p
                                          # → MUST: judgment_rationale (new/new[] 与 delete/delete[] 不匹配原因)

# 自定义分配器与标准释放混用
\w+_(alloc|malloc|new)\s*\(
→ free\(|delete\s
                                          # → MUST: data_flow_path (跨家族分配/释放的调用链)

# 跨分配器释放
\w+_alloc\(         → \w+_free\((?!\1)    # 不同前缀的分配器
                                          # → MUST: variable_state (两个分配器的类型)

# === EXCLUDE (不报告) ===
→ new_ptr\s*=\s*realloc                    # 使用新指针，未使用旧指针
→ if\s*\(new\w*\)|if\s*\(new_ptr          # realloc 返回值检查
→ old\s*=\s*realloc\(old                   # 同名变量更新（仍有风险，但非 UAF 模式）
→ std::unique_ptr|std::shared_ptr          # 智能指针管理
→ operator new\(size, ptr\)                # placement new + free (底层 malloc)
→ realloc\(\w+,\s*0\s*\)                   # realloc(ptr, 0) 等同于 free(ptr)
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `realloc` 返回的新指针不等，后续代码使用新指针安全 | 旧指针已通过 realloc 内部释放，但使用新指针则安全 | 确认后续代码使用的是 realloc 返回的新指针变量，非旧指针变量 |
| C 中 `operator new` placement 包装 | 底层仍是 `malloc`，可能故意用 `free` | 确认 placement new 未分配额外内存（仅原地构造），且底层分配使用 `malloc` 家族 |
| 跨语言 FFI 边界 | Rust/Cgo 等边界处有显式配对约定 | 确认 FFI 边界处有文档化的分配/释放配对约定，且调用方遵循该约定 |
| `realloc(ptr, 0)` | 等同于 `free(ptr)` | 确认 `realloc` 的第二个参数为字面量 `0`，释放行为符合预期 |

### 修复指引

1. **realloc 后只使用新指针**：不再使用 `realloc` 前的旧指针。使用临时变量接收 realloc 返回值，避免直接 `ptr = realloc(ptr, n)` 导致泄漏
2. **严格配对**：`malloc`→`free`、`new`→`delete`、`new[]`→`delete[]`
3. **C++ 首选**：使用 `std::unique_ptr`/`std::make_unique` 自动管理
4. **自定义分配器**：提供配对宏 `#define SAFE_FREE(ptr) xxx_free(ptr); ptr = NULL`
5. **代码审查**：C/C++ 混合代码中特别关注分配/释放配对

## Scenario 2: 引用计数/所有权不匹配导致 Use-After-Free

### 威胁定义

引用计数的增（inc）减（dec）操作不匹配——`AddRef`/`Release`、`get`/`put`、`ref`/`unref`、`acquire`/`release` 等——在函数或其调用链上出现不均衡。两种失效模式：

- **(a) 增大于减（over-ref）**：`AddRef` 多于 `Release`，引用计数永不归零，资源永不释放，等价于内存泄漏
- **(b) 减大于增（under-ref）**：`Release` 多于 `AddRef`，引用计数提前归零导致资源被释放，但仍有代码持有悬空指针继续访问，形成 use-after-free 漏洞

此外，指针变量在同一函数内存在多个别名（`p2 = p1`）、存储在容器中、或在跨函数调用中转移所有权后，释放方释放了内存而使用方仍持有悬空引用，形成直接 UAF。

### 检测逻辑

#### Step 1: 识别引用计数函数对

搜索符合引用计数命名模式的函数：`*_ref()`/`*_unref()`、`*_AddRef()`/`*_Release()`、`*_get()`/`*_put()`、`*_acquire()`/`*_release()`、`*_retain()`/`*_release()`、`ObjCreate()`/`ObjDestroy()` 等。记录每个函数所在文件和行号，建立 inc（引用计数+1）和 dec（引用计数-1）的映射表。

#### Step 2: 配对分析（同函数内）

对每个 inc 操作，在同一函数/作用域内搜索对应的 dec 操作。分析所有退出路径：正常的函数末尾返回、条件 return、break/continue、goto、异常传播。如果存在 inc 后无对应 dec 的退出路径，标记为 over-ref（泄漏）。

```c
// BAD: inc 多于 dec — 资源永不释放（泄漏）
obj_get(o);                          // refcount +1
obj_get(o);                          // refcount +1
obj_put(o);                          // refcount -1（仅一次）
// refcount > 0 → 永不释放

// BAD: dec 多于 inc — 提前释放
obj_get(o);                          // refcount +1
obj_put(o);                          // refcount -1
obj_put(o);                          // refcount -1（无对应 get!）
// refcount=0 → 资源释放 → 后续访问为 use-after-free

// BAD: inc 后异常路径未 dec
obj_get(o);                          // refcount +1
if (error) {
    return -1;                       // dec 缺失！泄漏
}
do_work(o);
obj_put(o);                          // 仅正常路径 dec

// BAD: 循环中 inc 但仅循环外 dec
while (items) {
    obj_get(item);                   // 每次循环 inc
    process(item);
}
obj_put(item);                       // 仅 dec 一次！每次迭代都在泄漏
```

**安全模式：**
```c
// GOOD: 成对使用，所有路径匹配
obj_get(o);                          // inc
if (error) {
    obj_put(o);                      // 错误路径 dec
    return -1;
}
do_work(o);
obj_put(o);                          // 正常路径 dec
return 0;

// GOOD (C++): shared_ptr 自动管理
std::shared_ptr<Obj> ptr(obj);       // 构造时 inc
// 析构自动 dec，无泄漏

// GOOD (C): goto cleanup 保证配对
err = obj_get(o);
if (err) return -1;
if (error_condition) goto cleanup;
do_work(o);
cleanup:
    obj_put(o);                      // 所有路径汇聚
    return ret;
```

#### Step 3: 别名与容器所有权分析

**模式 A — 别名引用 Use-After-Free：**
```c
// BAD: p2 指向已释放内存
char *p2 = p1;
free(p1);
strcpy(p2, "data");                  // UAF: p2 指向已释放的 p1 内存

// BAD: 指针算术别名
char *base = malloc(256);
char *mid = base + 128;
free(base);
mid[0] = 'x';                        // UAF: mid 在已释放区域内
```

**模式 B — 容器/数据结构悬空指针：**
```c
// BAD: 容器接管所有权后调用者继续使用原指针
item_t *it = malloc(sizeof(item_t));
list_append(list, it);               // list 接管所有权
it->value = 42;                      // UAF: list 可能已释放

// BAD: 容器释放后持有过期引用
list_free_all(list);                 // 释放所有 item
item_t *first = list->items[0];      // 悬空: list 已释放全部
```

#### Step 4: 跨函数所有权追踪

**模式 A — 函数参数接管所有权：**
```c
// BAD: 调用者传递指针，被调用者释放，调用者继续使用
void take_ownership(item_t *p) {
    // ...
    free(p);
}

void caller() {
    item_t *it = malloc(sizeof(item_t));
    process(it);                     // process 是否释放 it?
    it->value = 99;                  // UAF: process 已释放 it
}
```

**模式 B — C++ unique_ptr 所有权转移：**
```c++
// BAD: move 后继续访问原始对象
auto a = std::make_unique<int>(42);
auto b = std::move(a);
*a = 43;                             // BAD: a 在 move 后为 nullptr

// BAD: 裸指针提取但原 unique_ptr 管理生命周期
int *raw = p.get();
p.reset();                           // p 释放内存
*raw = 42;                           // UAF: raw 已悬空
```

**安全模式：**
```c++
// GOOD: move 后只使用新所有者
auto a = std::make_unique<int>(42);
auto b = std::move(a);
*b = 43;                             // safe: b 是新所有者

// GOOD: release 将所有权移出 unique_ptr
int *raw = p.release();              // p 不再管理
// ... 使用 raw ...
delete raw;                          // 调用者负责释放
```

#### Step 5: 跨函数配对分析

当 inc 和 dec 位于不同函数中时（如 init 函数 inc → 工作函数使用 → cleanup 函数 dec），追踪调用链确认配对。检查模块的初始化/清理函数是否形成完整的 refcount 生命周期闭环。

**跨函数追踪规则**：
- **最大深度**：1 层，超过 depth 1 的调用链 → 降级为 suspicious
- 追踪目标函数内部是否执行 free，但调用者在调用后仍使用该指针
- 检查函数返回值是否为所有权转移信号（如 realloc 返回值）
- 对 C++ unique_ptr 的 move，追踪到构造后原对象不再使用

#### Step 6: 所有权语义分析

识别引用计数操作的所有权语义：函数返回对象指针是否隐式传递所有权（调用者负责 Release）、函数参数中的 in/out 语义。确认注释或命名约定（`_unref` vs `_free` 等）。

### 检测模式

```
# === MATCH (触发检测) ===

# 引用计数 inc 后缺乏对应 dec
obj_get() / AddRef() / ref() / acquire()
后缺乏对应的 obj_put() / Release() / unref() / release()
                                          # → MUST: code_context (inc/dec 配对 + 退出路径标注)
                                          # → SHOULD: data_flow_path (refcount 操作序列 + 理论值)

# 引用计数 dec 多于 inc（多 release）
obj_put() / Release() / unref() / release()
多于对应的 inc 操作
                                          # → MUST: judgment_rationale (哪些 dec 无对应 inc)
                                          # → SHOULD: data_flow_path

# 循环内 inc 但仅循环外 dec
循环内 obj_get() + 循环外单次 obj_put()
                                          # → MUST: code_context (循环体内 inc + 循环体外单一 dec)
                                          # → MUST: judgment_rationale (每次迭代的泄漏效应)

# 跨函数 inc/dec 不匹配
init 中 inc 但无对应的 cleanup 中 dec
                                          # → MUST: call_stack (跨函数配对追踪)
                                          # → SHOULD: data_flow_path

# 别名 UAF
p2 = p1
→ free(p1)
→ 使用 p2
                                          # → MUST: code_context (别名声明+释放+使用三行)
                                          # → MUST: judgment_rationale (别名关系推导)

# 容器悬空指针
释放后容器仍持有指向同一内存的引用
                                          # → MUST: code_context (释放点+容器访问点)
                                          # → MUST: judgment_rationale (容器生命周期分析)

# 跨函数所有权转移后 UAF
caller 中 free 调用 → caller 后续使用同一指针
或 caller 传递指针给 callee 后 callee 释放 → caller 再使用
                                          # → MUST: code_context (释放函数+调用后使用行)
                                          # → SHOULD: call_stack (跨函数调用链)

# unique_ptr move 后访问原对象
std::move(a) → 后续代码访问 a
                                          # → MUST: code_context (move + 后续访问行)

# === EXCLUDE (不报告) ===
→ std::shared_ptr / RefPtr<T> / scoped_refptr    # RAII 编译器保证配对
→ 对象创建时 refcount=1，仅通过单一 release 函数 dec  # 单持有者模式
→ 所有 inc 路径均存在对应的 dec（含 goto cleanup / RAII） # 配对完整
→ 位于 test/ 或 *_test.c / *_mock.c 文件            # 测试辅助代码
→ free\(.*\);\s*(p\w*|ptr\w*)\s*=\s*(NULL|nullptr)  # 释放后置空
→ return;|exit\(|goto\s+                            # 不可达控制流
→ 函数文档标明调用者负责释放，且调用者确实未释放               # resource-leak 而非此算子
```

### 误报排除

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| RAII 智能指针（shared_ptr/unique_ptr/RefPtr）自动管理引用计数 | 框架级 RAII 封装在构造/析构中隐式管理 refcount，不依赖手动配对 | 使用了 `std::shared_ptr`、`RefPtr<T>`、`scoped_refptr` 等 RAII 类型 |
| 单线程无并发场景下 inc 缺失（初始化时 refcount=1） | 初始化 refcount=1，后续仅 dec 无 inc 为正常的单持有者模式 | 对象仅在单线程中使用，无并发访问，且生命周期明确 |
| 释放后函数内部重新赋值 | 赋值后指针不再指向已释放内存 | 确认 callee 第一行有 `ptr = new_value` 赋值 |
| 自定义 ref/unref 命名中 ref 仅返回指针不修改计数 | 某些代码库 `_ref()` 是只读访问器，`_unref()` 才修改计数 | 阅读函数实现确认 `_ref()` 不修改计数变量 |
| 自定义 delete 包装器 | `safe_delete(&p)` 内部置 NULL | 确认释放包装器内部置 NULL |
| 函数命名约定 | `*_release` 可能不释放内存，只释放资源句柄 | 检查实现确认是否真正释放内存 |
| realloc 返回 NULL 但旧指针仍有效 | 此时旧 ptr 丢失是内存泄漏，非 UAF | 确认 `realloc` 返回 NULL 分支不访问旧指针 |
| 句柄而非指针 | 整型句柄（如文件描述符）的"释放"不适用所有权转移分析 | 确认操作的是整型句柄而非指针 |

### 修复指引

1. **引用计数首选用 shared_ptr**（C++）：使用 `std::shared_ptr<T>` 和 `std::weak_ptr<T>` 替代手动引用计数，编译器保证所有退出路径正确调整引用计数
2. **C 语言使用 goto cleanup**：将所有 inc 后的退出路径汇聚到包含 dec 的 cleanup label
3. **最低要求**：在每个 inc 调用后的每个 `return`/`break`/`continue`/`goto` 前显式添加对应的 dec 调用
4. **释放后置 NULL**：`free(ptr); ptr = NULL;` — 后续使用 NULL 会崩溃而非被利用
5. **避免别名**：释放前确保无人持有该指针的副本
6. **清晰的所有权语义**：谁分配谁释放，函数文档明确标注所有权转移

## 安全模式汇总（所有场景通用）

以下模式在任何场景中均不报告 ownership transfer 漏洞：

```c
// SAFE: realloc 后只使用新指针
char *newptr = realloc(old, new_size);
if (!newptr) { free(old); return; }
old = NULL;                            // 清空旧指针
// 后续只使用 newptr

// SAFE: 释放后置 NULL
free(ptr);
ptr = NULL;

// SAFE: 释放后重新分配
free(p);
p = malloc(100);
p->field = 1;

// SAFE: 提前 return
free(buf);
return;

// SAFE: 成对引用计数
obj_get(o);
do_work(o);
obj_put(o);

// SAFE: move 后只使用新对象
auto b = std::move(a);
*b = 42;                               // 只使用 b
```

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。



   - `p = realloc(p, new_size);` — 安全：realloc 可能返回不同的指针，但旧指针被更新
   - `q = realloc(p, new_size); free(p);` — 双重释放：realloc 内部已释放 p，`free(p)` 导致 double-free
   - `q = realloc(p, new_size); p[0] = 'x';` — 释放后使用：如果 realloc 移动了内存，p 已无效

   - `free(p); p2->field = 1;` — 如果 `p2 == p` 则为 UAF
   - 检查函数范围内是否存在别名赋值 `p2 = p` 或 `p2 = p + offset`

   - 释放指针后未从容器中移除: `free(p); list_contains(p) == true`
   - 检查同一数组或链表中存储的指针

   - 函数参数标明 `__attribute__((ownership_takes(p)))` 或类似语义
   - 调用者继续使用已被调函数释放的指针
   - 函数文档说"调用者负责调用 free"但调用者没有 — 视为 resource-leak 而非此算子

   - 移动后继续访问原始对象: `auto b = std::move(a); a.method();` // a 已转移


---

## 取证证据收集指引

### 必须收集 (MUST)

#### Scenario 1 (realloc/不匹配释放相关)
- [ ] **code_context**：realloc 调用及其后续旧指针使用代码的完整片段，或分配/释放函数配对代码 → findings.evidence.code_context
- [ ] **judgment_rationale**：分析分配函数和释放函数是否来自同一家族，realloc 后旧指针是否有可能被访问 → findings.evidence.judgment_rationale
- [ ] **variable_state**：realloc 场景中记录分配函数和释放函数类型、新旧指针变量名 → findings.evidence.variable_state

#### Scenario 2 (引用计数/所有权转移相关)
- [ ] **code_context**：包含 inc/dec 操作对的函数体，标注所有 inc 调用和其对应的 dec 调用（含退出路径分析），或别名/容器释放与使用代码 → findings.evidence.code_context
- [ ] **judgment_rationale**：具体列出 inc 无对应 dec 的路径（行号 + 退出方式，over-ref 泄漏），或 dec 无对应 inc 的位置（under-ref 提前释放），或别名关系推导 → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：指针从 malloc/new 分配 → 使用 → 释放/所有权转移 → （可能置 NULL）→ （悬空访问）的完整生命周期数据流；refcount 操作的完整序列（inc1 → inc2 → dec1 → ...），标注 refcount 在各点的理论值 → findings.evidence.data_flow_path
- [ ] **call_stack**：跨函数所有权转移时，记录分配函数 → 释放函数 → 悬空使用函数的完整调用链；当 inc 和 dec 分散在不同函数中时，追踪调用链并标注每个函数对 refcount 的影响 → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：指针值在分配后/释放后的状态、是否存在别名变量（p2=p1）、realloc 返回值是否覆盖了原始指针、对象当前引用计数值（运行时或静态推导） → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了 std::unique_ptr/std::shared_ptr 自动管理、是否有 AddressSanitizer 运行时检测（-fsanitize=address）或 LeakSanitizer 检测报告 → findings.evidence.sanitizer_analysis
- [ ] **cross_signal_analysis**：当多信号归并分析发生时，记录归并依据和 cross_signal_analysis 标记 → findings.evidence.cross_signal_analysis

## 输出格式

每个 finding 遵循三段式证据链：

1. **问题定位**：释放/所有权转移点行号 + 后续悬空使用点行号
2. **证据链**：code_context（释放操作 + 后续使用代码） + judgment_rationale（置空检查 + 别名分析 + 引用计数配对分析）
3. **分类分级**：severity（high）、CWE-416、scenario 归属

输出模板：
```json
{
  "rule": "ownership_transfer",
  "scenario": "realloc 不当使用与不匹配释放 | 引用计数/所有权不匹配导致 Use-After-Free",
  "severity": "high",
  "cwe": "CWE-416",
  "evidence": {
    "code_context": "<释放行>-<使用行> 代码路径",
    "judgment_rationale": "<置空/配对/别名分析结论>",
    "data_flow_path": "<分配→释放→使用的完整数据流>",
    "call_stack": "<跨函数调用链>"
  }
}
```
