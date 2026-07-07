---
detector: memory-leak
description: Detects memory leak vulnerabilities where allocated memory is not properly freed
severity: medium
cwe: CWE-401
cvss: 5.5
language: [c, cpp]
tags: [memory, heap, resource-management]
precision: high
confidence: dynamic
target_functions: [free, malloc, process]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

通过 `malloc`/`calloc`/`new` 分配的堆内存未在合适的时机释放，导致进程内存持续增长，最终资源耗尽。C/C++ 无 GC，内存泄漏是常见但可防止的问题。

**检测时需区分"真泄漏"和"刻意不释放"**：
- **真泄漏**：每个请求/迭代中分配但不释放 → 内存持续增长
- **非泄漏**：全局缓冲区、Arena 分配器、main() 中单次分配的 exit-time 回收

## 检测逻辑 (Detection Logic)

### Step 1: 识别分配点（含自定义分配器）

标准 C/C++ 和命名约定匹配的自定义分配器：
```
malloc / calloc / realloc / strdup
new / new[]
xxx_malloc / xxx_alloc / xxx_new / xxx_create / ALLOC_xxx
```

### Step 2: 追踪释放路径 — 报告条件

**报告以下模式**：

1. **错误路径未释放**（最常见）：
```c
buf = malloc(N);
if (error) return -1;  // 泄漏！
free(buf);
```

2. **循环中分配未释放**：
```c
for (i = 0; i < n; i++) {
    char *tmp = malloc(K);  // 每次迭代泄漏！
    process(tmp);
}  // 无 free(tmp)
```

3. **指针覆盖**：
```c
ptr = malloc(N);
ptr = malloc(M);  // 旧指针丢失，N 字节泄漏
```

### Step 3: 不报告（刻意不释放）

| 模式 | 原因 |
|------|------|
| `main()` 中单次分配直到程序退出 | OS 回收 |
| Arena/Zone 分配器 `pool_alloc` + 批量 `pool_free_all` | 整体管理 |
| `static` 变量初始化分配 | 生命周期 = 程序 |
| `atexit()` 注册的释放回调 | 程序退出时执行 |

## 修复指引 (Remediation)

1. **C++ 首选**：`std::unique_ptr<T>` / `std::shared_ptr<T>` / RAII
2. **C 代码**：使用 `goto cleanup` 模式统一资源释放
3. **循环分配**：在循环内释放或复用缓冲区
4. **编译器辅助**：启用 `-fanalyzer` (GCC 10+) 或 clang static analyzer

## 取证证据收集指引 (Evidence Collection Guide)

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
- [ ] **sanitizer_analysis**：是否启用LeakSanitizer或-fanalyzer
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| `std::unique_ptr`/`std::shared_ptr` | RAII 自动释放 | 确认指针由智能指针管理，离开作用域时自动调用析构函数释放资源 |
| 自定义 Arena/Pool：`pool_alloc` + `pool_free_all()` | 批量释放 | 确认存在配对的 `pool_free_all`/`arena_reset`/`zone_destroy` 等批量释放调用 |
| 全局/static 变量 | 整个程序生命周期 | 确认分配发生在全局/static 变量初始化中，生命周期与程序一致 |
| `main()` 或单次入口分配且程序很快退出 | OS 回收 | 确认分配仅在 main() 或单次入口函数中，程序为短生命周期工具 |
| `alloca()` 栈分配 | 函数返回自动回收 | 确认使用的是 `alloca`/`_alloca` 栈分配，非堆分配 |
| `atexit(cleanup_func)` | 程序退出时执行 | 确认 `atexit` 注册的回调函数中存在配对的释放逻辑 |
| 分配后赋值给带 `__attribute__((cleanup))` 的变量 | 自动清理 | 确认变量声明带有 `__attribute__((cleanup(cleanup_func)))`，且清理函数执行释放 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# 分配 + 中间 return 无释放 → evidence: code_context
(malloc|calloc|new|ALLOC_|_alloc|_malloc)\(
→ (同一函数, 之后) return|goto.*(?!cleanup|error|fail)
→ (return 之前, 同路径) 无 free|delete|xxx_free|xxx_release
→ evidence: call_stack (记录从分配到提前返回的调用路径)

# 循环内分配无配对释放 → evidence: code_context
(for|while)\s*\(
→ 循环体内 (malloc|calloc|new)
→ 循环体内无 free|delete
→ 且指针未保存到循环外的作用域
→ evidence: variable_state (记录每次迭代分配的指针是否被覆盖)

# 指针重新赋值前未释放旧值 → evidence: variable_state
\w+\s*=\s*(malloc|calloc|new)
→ 同变量再次 \w+\s*=\s*(malloc|calloc|new)
→ 两次之间无 free|delete
→ evidence: data_flow_path (记录指针变量从首次分配到覆盖的路径)
```

### 排除模式 (EXCLUDE)

```
# RAII 包装 → evidence: code_context
std::unique_ptr|std::shared_ptr|std::vector|std::string

# Arena/Zone 释放 → evidence: sanitizer_analysis
pool_free_all|zone_destroy|arena_reset|ALL_FREE

# 全局/static → evidence: code_context
static\s+\w+\s*=\s*malloc|全局初始化

# atexit 注册 → evidence: sanitizer_analysis
atexit\(.*free|atexit\(.*cleanup

# goto cleanup 模式 → evidence: code_context
goto\s+cleanup|goto\s+err|goto\s+fail  # 在标签处存在统一释放逻辑

# __attribute__((cleanup)) → evidence: code_context
__attribute__\(\(cleanup\(  # GCC/Clang 自动清理属性
```
