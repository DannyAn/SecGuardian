---
detector: use-after-free
description: Detects use-after-free vulnerabilities where memory is accessed after being freed
severity: critical
cwe: CWE-416
cvss: 9.8
language: [c, cpp]
tags: [memory, heap, exploitation, dangling-pointer]
precision: very-high
confidence: dynamic
target_functions: [c_str, caller, code_context, free, get_name, judgment_rationale, malloc, nullptr, process_data, ptr, realloc, strcpy, xxx, xxx_destroy, xxx_free, xxx_release]
match_patterns: [free(ptr)|delete ptr, p2 = p1, old_ptr = malloc(N)]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

指针在 `free()`/`delete` 后继续被读写，导致访问已释放内存。已释放内存可能被分配器重新分配给其他对象，攻击者可通过堆风水（heap feng shui）实现代码执行。这是 CWE Top 25 中最危险的漏洞之一。

**核心原则：释放后立即置 NULL，且后续代码不得悬空使用。** 检测时必须识别自定义分配器（`xxx_free`/`xxx_destroy`/`xxx_release`/`FREE_xxx`）——它们和标准 `free` 一样危险。

## 检测逻辑 (Detection Logic)

### Step 1: 搜索释放点后的指针使用

定位每个释放调用，然后追踪该函数作用域内指针的后续使用：

```c
// 标准释放
free(ptr);
delete ptr;
delete[] ptr;

// 自定义释放（大厂常见模式，参考 knowledge/languages/cpp.md）
xxx_free(ptr);           // 如 my_free, pool_free
xxx_destroy(ptr);        // 如 object_destroy
xxx_release(ptr);        // 如 ZoneRelease
FREE_xxx(ptr);           // 宏释放
```

**自定义分配器识别**：目标代码中 `*_free`、`*_destroy`、`*_release`、`FREE_*` 的函数都应视作释放操作，后续使用同样为 UAF。

### Step 2: 使用模式分类

**模式 1：同函数内释放后使用**
```c
// BAD: free 后又使用
free(ptr);
ptr->field = value;           // Use-After-Free!
printf("%s", ptr);            // Use-After-Free!
```

**模式 2：跨函数释放后使用**
```c
// BAD: 释放后传递给其他函数
void process_data(char *data) {
    // 处理 data
}
void caller() {
    char *buf = malloc(100);
    free(buf);
    process_data(buf);        // Use-After-Free! buf 已释放
}
```

**模式 3：通过别名使用**
```c
// BAD: 别名绕过
char *p1 = malloc(100);
char *p2 = p1;
free(p1);
strcpy(p2, "data");           // Use-After-Free! p2 仍指向已释放内存
```

**模式 4：realloc 后继续使用旧指针**
```c
// BAD: realloc 可能移动内存，旧指针变为悬空
char *old = malloc(100);
char *new = realloc(old, 200);
if (new) {
    old[0] = 'x';             // Use-After-Free 或访问已移动内存!
}
```

**模式 5：C++ 成员函数返回 this 指针的悬空引用**
```c++
// BAD: 临时对象成员函数返回的指针
std::string temp = get_name();
const char *ptr = temp.c_str();
// temp 被销毁...
printf("%s", ptr);             // 悬空指针!
```

### Step 3: 跨函数/跨文件追踪

对于复杂情况，重点关注：
1. 指针作为函数返回值的释放义务（谁分配谁释放）
2. C++ 析构函数中的隐式释放
3. 回调函数中释放主函数的指针

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：释放操作（free/delete/xxx_free 等）及其后续同作用域内指针使用点的完整代码，标注释放行号和后续使用行号之间的代码路径
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析释放点与后续使用点之间是否存在 ptr=NULL 赋值——如果没有置空且后续代码直接或间接访问指针（->、*ptr、ptr[...]、函数参数传递），则为 UAF；若涉及别名，确认别名的声明时间和使用场景
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：指针从 malloc/new 分配 → 使用 → free/delete 释放 → （可能置 NULL）→ （悬空访问）的完整生命周期数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若为跨函数 UAF，记录分配函数 → 释放函数 → 悬空使用函数的完整调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：指针值在分配后/释放后的状态、是否存在别名变量（p2=p1）、realloc 返回值是否覆盖了原始指针
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用了 std::unique_ptr/std::shared_ptr 自动管理、是否有 AddressSanitizer 运行时检测（-fsanitize=address）
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **释放后置 NULL**：`free(ptr); ptr = NULL;` — 后续使用 NULL 会崩溃而非被利用
2. **C++ 使用智能指针**：`std::unique_ptr::reset()` 自动置空
3. **避免别名**：释放前确保无人持有该指针的副本
4. **realloc 后使用新指针**：不继续使用 `realloc` 前的旧指针

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `free(p); p = NULL;` 后使用 p | 使用 NULL 而非已释放内存（虽然仍是逻辑错误） | 确认 free 行和后续使用行之间存在 `p = NULL` 或 `p = nullptr` 赋值 |
| `realloc` 返回的新指针不等 | 旧指针已通过 realloc 内部释放，但使用新指针安全 | 确认后续代码使用的是 realloc 返回的新指针变量，非旧指针变量 |
| 自定义内存池 | free 不是真正的释放，内存仍在池中 | 确认 free 被宏重定义或在自定义内存池作用域内，释放后内存仍可安全访问 |
| `std::unique_ptr::reset()` 后 RAII 保证 | unique_ptr 自动置空 | 确认指针由 std::unique_ptr 管理，非裸指针 |
| 静态分析已排除的死代码 | 不可达路径中的使用 | 确认释放点后存在 return/exit/goto 等不可达控制流 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# free/delete 后同作用域使用
free(ptr)|delete ptr
                                                       # → MUST: code_context (释放点+后续使用点)
→ (无 ptr = NULL|ptr = nullptr|return)
→ 访问 ptr|ptr->|*ptr|ptr[
                                                       # → MUST: judgment_rationale (释放后置空检查+别名分析)

# 别名 UAF
p2 = p1
→ free(p1)
→ 使用 p2

# realloc 后使用旧指针
old_ptr = malloc(N)
→ new_ptr = realloc(old_ptr, M)
→ 检查 new_ptr 后仍使用 old_ptr

# === EXCLUDE (不报告) ===
→ free\(.*\);\s*(p\w*|ptr\w*)\s*=\s*(NULL|nullptr)   # 释放后置空
→ std::unique_ptr|std::shared_ptr                      # 智能指针管理
→ new_ptr\s*=\s*realloc                                # 使用新指针
→ if\s*\(new\w*\)|if\s*\(new_ptr                       # realloc 返回值检查
→ return;|exit\(|goto\s+                               # 不可达控制流
```
