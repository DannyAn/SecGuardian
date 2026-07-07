---
detector: resource.refcount-misuse
severity: medium
cwe: CWE-911
cvss: 5.5
language: [c, cpp]
tags: [resource, refcount, leak, reference-counting, use-after-free]
precision: medium
confidence: dynamic
target_functions: [acquire, do_work, obj_get, obj_put, process, ptr, ref, release, unref]
match_patterns: [obj_get() / AddRef() / ref() / acquire() 后在函数内缺乏对应的 obj_put() / Release() / unref() / release(), obj_put() / Release() / unref() / release() 多于对应的 inc 操作（多 release）, 循环内 inc 但仅循环外 dec（每次迭代泄漏）, 跨函数 inc/dec 不匹配（init 中 inc 但无对应的 cleanup 中 dec）]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

成对引用计数操作——`AddRef`/`Release`、`get`/`put`、`ref`/`unref`、`acquire`/`release` 等——在函数或其调用链上出现不匹配，映射 CWE-911（Improper Update of Reference Count）。两种失效模式：(a) **增大于减**（over-ref）——`AddRef` 调用多于 `Release`，引用计数永远不会归零，资源永不释放，等价于内存/资源泄漏，在长时间运行的服务中持续累积；(b) **减大于增**（under-ref）——`Release` 调用多于 `AddRef`，引用计数提前归零导致资源被释放，但仍有代码持有悬空指针继续访问，形成 use-after-free 漏洞。不同于 `resource.socket-leak`（裸 fd 泄漏）和 `resource.lock-misuse`（锁配对），本检测器关注的是**自定义引用计数机制的语义配对完整性**，需要识别项目特定的 ref/unref 函数命名约定。

## 检测逻辑 (Detection Logic)

### Step 1 — 识别引用计数函数对

搜索符合引用计数命名模式的函数：`*_ref()`/`*_unref()`、`*_AddRef()`/`*_Release()`、`*_get()`/`*_put()`、`*_acquire()`/`*_release()`、`*_retain()`/`*_release()`、`ObjCreate()`/`ObjDestroy()` 等。记录每个函数所在文件和行号，建立 inc（引用计数+1）和 dec（引用计数-1）的映射表。

### Step 2 — 配对分析（同函数内）

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
// ... 任何退出路径 ...
// ptr 析构自动 dec，无泄漏

// GOOD (C): goto cleanup 保证配对
err = obj_get(o);
if (err) return -1;
if (error_condition) goto cleanup;
do_work(o);
cleanup:
    obj_put(o);                      // 所有路径汇聚
    return ret;
```

### Step 3 — 跨函数配对分析

当 inc 和 dec 位于不同函数中时（如 init 函数 inc → 工作函数使用 → cleanup 函数 dec），追踪调用链确认配对。检查模块的初始化/清理函数是否形成完整的 refcount 生命周期闭环。

### Step 4 — 所有权语义分析

识别引用计数操作的所有权语义：函数返回对象指针是否隐式传递所有权（调用者负责 Release）、函数参数中的 in/out 语义。确认注释或命名约定（`_unref` vs `_free` 等）。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含 inc/dec 操作对的函数体，标注所有 inc 调用和其对应的 dec 调用（含退出路径分析）
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：具体列出 inc 无对应 dec 的路径（行号 + 退出方式，over-ref 泄漏），或 dec 无对应 inc 的位置（under-ref 提前释放）
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：refcount 操作的完整序列（inc1 → inc2 → dec1 → ...），标注 refcount 在各点的理论值
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当 inc 和 dec 分散在不同函数中时，追踪调用链并标注每个函数对 refcount 的影响（+1/-1/不变）
      → `findings.evidence.call_stack`

### 可选收集 (MAY)
- [ ] **variable_state**：对象当前引用计数值（运行时或静态推导）、对象分配/释放函数的对应关系
      → `findings.evidence.variable_state`
- [ ] **sanitizer_analysis**：AddressSanitizer heap-use-after-free 或 LeakSanitizer 检测报告（如有运行时验证数据）
      → `findings.evidence.sanitizer_analysis`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| RAII 智能指针（shared_ptr/unique_ptr/RefPtr）自动管理引用计数 | 语言级或框架级 RAII 封装在构造/析构中隐式管理 refcount，不依赖手动配对 | 使用了 `std::shared_ptr`、`RefPtr<T>`、`scoped_refptr` 等 RAII 类型 |
| 单线程无并发场景下 inc 缺失（如对象由创建者持有初始引用） | 初始化时 refcount=1，后续仅 dec 无 inc 为正常的单持有者模式 | 对象仅在单线程中使用，无并发访问，且生命周期明确 |
| 初始化 refcount=1 后仅 dec（对象创建者持有初始引用） | `obj_create()` 返回 refcount=1 的对象，调用者使用后 `obj_release()`，这是标准的所有权模式，非 inc/dec 不匹配 | 创建函数建立了初始引用，release 函数为唯一 dec 点 |
| 自定义 ref/unref 命名中 ref 函数仅返回指针不修改计数 | 某些代码库中 `_ref()` 是只读访问器（返回指针），`_unref()` 才修改计数，需语义区分 | 阅读函数实现确认 `_ref()` 不修改计数变量 |

## 修复指引 (Remediation Guidance)

1. **首选**（C++）：使用 `std::shared_ptr<T>` 和 `std::weak_ptr<T>` 替代手动引用计数。编译器保证所有退出路径（包括异常）正确调整引用计数，无需手动配对。
2. **次选**（C）：采用 goto cleanup 模式，将所有 inc 后的退出路径汇聚到包含 dec 的 cleanup label。为每个 inc 操作使用局部变量追踪"已获取"状态，cleanup 处根据状态执行对应 dec。
3. **最低要求**：在每个 inc 调用后的每个 `return`/`break`/`continue`/`goto` 前显式添加对应的 dec 调用。添加注释说明配对关系（如 `obj_put(o); // paired with obj_get() at L42`）。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
obj_get() / AddRef() / ref() / acquire() 后在函数内缺乏对应的 obj_put() / Release() / unref() / release()
                                 # → MUST: code_context（inc/dec 配对 + 退出路径标注）
                                 # → SHOULD: data_flow_path（refcount 操作序列 + 理论值）

obj_put() / Release() / unref() / release() 多于对应的 inc 操作（多 release）
                                 # → MUST: judgment_rationale（哪些 dec 无对应 inc）
                                 # → SHOULD: data_flow_path

循环内 inc 但仅循环外 dec（每次迭代泄漏）
                                 # → MUST: code_context（循环体内 inc + 循环体外单一 dec）
                                 # → MUST: judgment_rationale（每次迭代的泄漏效应）

跨函数 inc/dec 不匹配（init 中 inc 但无对应的 cleanup 中 dec）
                                 # → MUST: call_stack（跨函数配对追踪）
                                 # → SHOULD: data_flow_path

# === EXCLUDE (不报告) ===
→ 使用 std::shared_ptr / RefPtr<T> / scoped_refptr 等 RAII 封装      # 编译器保证配对
→ 对象创建时 refcount=1，仅通过单一 release 函数 dec                  # 单持有者模式
→ 所有 inc 路径均存在对应的 dec（含 goto cleanup / RAII）              # 配对完整
→ 位于 test/ 或 *_test.c / *_mock.c 文件                              # 测试辅助代码
```
