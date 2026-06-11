---
detector: double-free
severity: critical
cwe: CWE-415
language: [c, cpp]
tags: [memory, heap, crash, exploitation]
precision: very-high
confidence: dynamic
---

# 双重释放 (Double Free)

## 威胁定义 (Threat Definition)

同一块内存被 `free()`/`delete` 两次，导致堆分配器内部数据结构损坏。攻击者可利用此漏洞实现任意写。自定义释放函数（`xxx_free`/`xxx_destroy`）的重复调用同样危险。

**核心原则：每次分配对应恰好一次释放。释放后立即置 NULL 防止重复释放。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索释放操作

搜索所有内存释放点，包括标准函数和自定义分配器：
```c
// 标准 C 库
free(ptr);

// C++ 
delete ptr;
delete[] ptr;

// 自定义分配器（大厂常见模式，参考 knowledge/languages/cpp.md）
xxx_free(ptr);           // 如 my_free, pool_free, Z_FREE, obj_release
xxx_destroy(ptr);        // 如 object_destroy
FREE_xxx(ptr);           // 宏包装的释放
```

**自定义分配器识别规则**：在目标代码中搜索匹配 `*_free`、`*_destroy`、`*_release`、`FREE_*` 模式的函数名，这些应被视作 `free()` 的语义等价物。

### Step 2: 控制流分析

对每个释放点，检查是否存在第二次释放同地址的路径：

**模式 1：同路径重复释放**
```c
// BAD: 同一个函数内两次 free
free(ptr);
// ... 一些代码 ...
free(ptr);                    // Double Free!
```

**模式 2：条件分支后重复释放**
```c
// BAD: 不同分支释放同一个指针
if (error) {
    free(ptr);
    return;
}
free(ptr);                    // 非 error 路径的释放
// ... 但 error 路径已经释放过了
```

**模式 3：指针别名**
```c
// BAD: 同一块内存被两个指针释放
char *a = malloc(100);
char *b = a;
free(a);
free(b);                      // Double Free! b 和 a 指向同一地址
```

**模式 4：跨函数释放**
```c
void cleanup(char *p) {
    free(p);
}
void process() {
    char *buf = malloc(100);
    cleanup(buf);
    free(buf);                // Double Free! cleanup 已经释放了
}
```

### Step 3: 指针赋值后释放检查

```c
// GOOD: free 后立即置 NULL，再次 free(NULL) 是安全的
free(ptr);
ptr = NULL;
// ...
free(ptr);                    // 安全——free(NULL) 是 no-op
```

检测时注意：只检查函数内可见的赋值，不追踪全局/堆上存储的指针。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：两次释放操作的完整代码块，包含第一次释放（free/delete/xxx_free）和第二次释放（同一指针变量），标注两次释放之间的代码路径（包括条件分支和 goto 跳转）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析两次释放之间是否存在 ptr=NULL 赋值——如果没有置空且存在代码路径可到达第二次释放，则为 Double Free；若涉及指针别名，确认两个别名变量是否指向同一分配地址；检查是否有条件分支导致互斥路径下的重复释放
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：指针从 malloc 分配 → 第一次释放 → （可能置 NULL/重新赋值）→ 第二次释放的完整生命周期数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若为跨函数双释放，记录分配函数 → 第一次释放函数 → 第二次释放函数的完整调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：指针值在每次释放前后的状态、是否存在别名变量、两次释放之间的条件分支条件值
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了 std::unique_ptr 自动管理生命周期、是否有 safe_free(&ptr) 封装函数、是否配置了 MALLOC_CHECK_ 环境变量
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **释放后置 NULL**：`free(ptr); ptr = NULL;` — 对 NULL 调用 free 是安全的
2. **使用 RAII**：C++ 中优先使用 `std::unique_ptr`/`std::shared_ptr`
3. **避免别名**：确保释放前没有其他指针指向同一内存
4. **全局释放函数**：统一通过 `safe_free(&ptr)` 封装释放 + 置空逻辑

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| free 后 ptr=NULL 置空 | 再次 free(NULL) 安全 | 确认第一次 free 和第二次 free 之间存在 `ptr = NULL` 或 `ptr = nullptr` 赋值 |
| 不同的条件分支（互斥路径） | 只在一个路径执行 | 确认两次 free 分别在 if/else 的互斥分支中，运行时只会执行其中一个 |
| `realloc(ptr, 0)` | 等同于 free，非 double free | 确认使用 realloc(ptr, 0) 语义，且返回值被正确处理 |
| `delete` 空指针 (C++) | `delete nullptr` 安全 | 确认 delete 的目标变量已置为 nullptr |
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动管理生命周期 | 确认指针由智能指针的 release()/reset() 管理，非裸指针手动释放 |
| 同一指针传给不同释放函数但分配不同地址 | 如 `realloc` 后地址变化 | 确认 realloc 返回了新地址，旧指针和新指针指向不同内存 |
| `xxx_free(ptr)` 后 `ptr = NULL` | 自定义释放函数也遵循 free-null 惯例 | 确认自定义释放后紧跟 ptr=NULL 赋值 |
| 自定义内存池的 `pool_free_all()` | 批量释放整个池，非 double-free | 确认使用 pool_free_all/pool_destroy 等批量释放函数，释放整个内存池 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 同一函数内两次 free/delete（排除中间有赋值）
free|delete|xxx_free|xxx_destroy
                                                       # → MUST: code_context (两次释放操作代码)
→ (中间无 ptr = NULL|ptr = nullptr)
→ free|delete|xxx_free|xxx_destroy (同一变量)
                                                       # → MUST: judgment_rationale (释放间置空+互斥路径分析)

# 指针别名后释放
p2 = p1
→ free|xxx_free(p1)
→ free|xxx_free(p2)

# free 无后续 NULL 赋值
free|xxx_free(ptr)
→ (无 ptr = NULL)
→ 函数内后续代码仍使用 ptr 或再次 free|xxx_free(ptr)

# === EXCLUDE (不报告) ===
→ free.*\);\s*(p\w*|ptr\w*)\s*=\s*(NULL|nullptr)      # 释放后置空
→ std::unique_ptr|std::shared_ptr                       # 智能指针 RAII
→ if\s*\(.*\)\s*\{.*free.*\}.*else                     # 互斥分支
→ realloc\(.*,\s*0\)                                    # realloc 归零（语义等同 free）
→ pool_free_all|pool_destroy|alloc_destroy              # 内存池批量释放
→ safe_free\(&                                          # 封装的安全释放函数
```
