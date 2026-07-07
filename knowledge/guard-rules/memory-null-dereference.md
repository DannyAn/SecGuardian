---
detector: null-dereference
severity: high
cwe: CWE-476
language: [c, cpp]
tags: [memory, pointer, crash]
precision: very-high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "memory.null-dereference",
  "type": "guard-rule",
  "namespace": "memory",
  "severity": "High",
  "cwe": "CWE-476",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "very-high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "caller",
    "calloc",
    "cleanup",
    "code_context",
    "fopen",
    "getenv",
    "goto",
    "judgment_rationale",
    "malloc",
    "process",
    "realloc",
    "strchr",
    "strstr",
    "use"
  ],
  "match_patterns": [
    "(malloc|calloc|realloc)\\(",
    "(malloc|calloc)\\([^)]*\\)",
    "(getenv|fopen|strchr|strstr)\\(",
    "\\w+\\s*=\\s*realloc\\(\\1,"
  ],
  "exclude_patterns": [
    "new\\s+(?!\\(std::nothrow\\))",
    "__attribute__\\(\\(returns_nonnull\\)\\)",
    "if\\s*\\(.*==\\s*NULL\\)|if\\s*\\(!ptr\\)",
    "std::unique_ptr|std::shared_ptr",
    "\\balloca\\("
  ],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

程序对值为 NULL 的指针进行解引用操作，导致段错误崩溃或（在特定条件下）可被利用的未定义行为。C/C++ 中 malloc/fopen/getenv 等函数可能返回 NULL，如果未检查直接使用就是高危。

**核心原则：任何可能返回 NULL 的函数调用后，返回值必须在使用前检查。** 但需区分"直接检查"和"通过调用链保证"——调用者已检查的场景不重复报告。

## 检测逻辑 (Detection Logic)

### Step 1: 搜索可能返回 NULL 的调用

| 函数类别 | 示例 | 检测条件 |
|---------|------|---------|
| 内存分配 | `malloc`/`calloc`/`realloc` | 返回值被解引用且无 NULL 检查 |
| 文件操作 | `fopen`/`opendir` | 同上 |
| 环境变量 | `getenv` | 同上 |
| 字符串查找 | `strchr`/`strstr`/`strtok` | 同上 |
| 自定义分配器 | `xxx_malloc`/`xxx_alloc`/`xxx_new` | 同上，需匹配命名约定 |
| C++ new (std::nothrow) | `new(std::nothrow) T` | 返回 nullptr |
| C++ dynamic_cast (指针) | `dynamic_cast<T*>(ptr)` | 失败返回 nullptr |

### Step 2: 确认"检查"存在

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

### Step 3: 调用链保证

```c
// 场景：调用者已检查
void process(char *buf) {
    buf[0] = 'x';  // 调用者保证 buf 非 NULL → 不报告
}

void caller() {
    char *buf = malloc(100);
    if (!buf) return;
    process(buf);   // 已检查后传入
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含可能返回 NULL 的函数调用（malloc/calloc/realloc/fopen/getenv/strchr 等）及其后续解引用操作的完整代码块，标注返回值赋值变量和首次解引用的行号
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析从 NULL 返回函数调用到指针解引用之间是否存在 NULL 检查——逐行验证是否有 if(ptr==NULL)/if(!ptr) 分支保护，确认检查是否为有效检查（排除 assert/NDEBUG 场景），以及调用链上是否有调用者已做保证
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：指针从分配函数返回值 → 赋值 → （可能的检查）→ 解引用的完整数据流，标注检查点的存在性和有效性
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若涉及跨函数传递，记录调用者→被调用者的完整调用链，确认调用者在传递指针前是否已做 NULL 检查
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：指针变量在分配后的值（NULL/非NULL）、是否被重新赋值、函数签名中是否有 __attribute__((nonnull)) 标注
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：编译选项中是否启用 -fsanitize=null（UBSan 空指针检测）、是否有静态分析器标注（__attribute__((returns_nonnull))）
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **分配后立即检查**：`if (!ptr) return ERR_NOMEM;`
2. **C++ 优先使用 throw 版本**：`new T` 失败抛 `std::bad_alloc`，无需手动 NULL 检查
3. **使用 RAII 包装**：`std::unique_ptr<T>` 自动管理生命周期
4. **禁止用 assert 做 NULL 检查**：release 构建中 assert 被移除

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| C++ `new T`（非 nothrow） | 失败抛异常，不返回 nullptr | 确认使用 `new T` 而非 `new(std::nothrow) T`，无自定义 new_handler |
| 调用者已检查 NULL | 通过参数传递前已验证 | 确认调用者在调用前有 if(!ptr) 检查，且被调用函数未重新赋值指针 |
| `alloca()` / 栈分配 | 非堆分配，无 NULL 返回 | 确认使用 alloca() 或变长数组（VLA），而非 malloc 系列 |
| `std::unique_ptr`/`std::shared_ptr` | RAII 保证有效 | 确认指针由智能指针管理，未通过 .get() 获取裸指针后绕过检查 |
| `static`/全局 buffer | 编译期分配，地址确定 | 确认变量声明为 static 或在文件作用域，非动态分配 |
| GCC `__attribute__((returns_nonnull))` | 编译器标注函数不返回 NULL | 确认被调用函数声明包含此属性，且编译器版本支持 |
| `assert(ptr)` 且 `NDEBUG` 未定义 | 开发/调试构建 | 确认编译选项中未定义 NDEBUG，且非 release 构建配置 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

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

# getenv/fopen/strchr 返回值未检查
(getenv|fopen|strchr|strstr)\(
→ 返回值赋值
→ 无 if.*NULL 直接使用

# realloc 覆盖原始指针（泄漏 + 空指针双重风险）
\w+\s*=\s*realloc\(\1,

# === EXCLUDE (不报告) ===

# C++ new (throw 版本) — 不返回 nullptr
new\s+(?!\(std::nothrow\))

# 调用者已检查的模式（通过上下文判断）
# — 指针变量在 if (!ptr) 之后的作用域内使用
# — 函数参数标注为 __attribute__((nonnull))

# GCC returns_nonnull 标注
__attribute__\(\(returns_nonnull\)\)

# 显式 NULL 检查
if\s*\(.*==\s*NULL\)|if\s*\(!ptr\)
# std 智能指针管理
std::unique_ptr|std::shared_ptr
# alloca/栈分配
\balloca\(
```
