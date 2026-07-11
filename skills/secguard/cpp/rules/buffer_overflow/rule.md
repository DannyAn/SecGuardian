---
name: secguard-cpp-buffer-overflow
description: "检测 C/C++ 代码中通过不安全字符串操作函数导致的缓冲区溢出漏洞，含 strcpy/strcat/sprintf/memcpy/gets 及安全变体参数误用、堆越界写入、差一错误"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.buffer_overflow
signal_filter: memory.buffer*
signal_source: call_sites[callee="strcpy|strcat|sprintf|gets|scanf|fgets|memcpy|memmove|strncpy|snprintf|vsprintf|strcpy_s|sprintf_s|memcpy_s|strcat_s"]
severity: critical
cwe: [CWE-120, CWE-122, CWE-193, CWE-787]
---

# buffer_overflow 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.buffer_overflow` |
| signal_filter | `memory.buffer*`（供 `secguard ./src c memory.buffer_overflow` 过滤匹配） |
| signal_source | `call_sites[cat="string", cat="memory"]` |
| 默认严重度 | Critical |

---

## Scenario 1: 无边界字符串拷贝（CWE-120 / CWE-121）

### 威胁定义

程序向栈/堆上的缓冲区写入超出其容量的数据，覆盖相邻内存。主要影响 C/C++，其他语言通过 FFI/cgo 间接影响。

**核心原则：内存操作必须边界检查。** 区分"无边界保护的写入"和"已验证边界的写入"——仅报告前者。

### 高危函数清单

#### 无边界检查函数（unsafe）

| 函数 | 风险等级 | 溢出条件 | CWE 变体 |
|------|---------|---------|---------|
| `strcpy(dst, src)` | Critical | src 长度 >= dst 分配大小 | CWE-121 (栈) / CWE-122 (堆) |
| `strcat(dst, src)` | Critical | strlen(dst) + strlen(src) >= dst 大小 | CWE-121 |
| `sprintf(buf, fmt, ...)` | Critical | 格式化结果长度 >= buf 大小 | CWE-121 |
| `memcpy(dst, src, n)` | High | n > dst 分配大小 或 dst+n 越界 | CWE-787 |
| `gets(buf)` | Critical | 输入长度 >= buf 大小（无限制） | CWE-120 |
| `wcscpy(dst, src)` | Critical | wcslen(src) * sizeof(wchar_t) >= dst 大小 | CWE-121 |

#### 安全变体（需参数审计）

| 函数 | 契约 | 检查要点 |
|------|------|---------|
| `strcpy_s(dst, dsize, src)` | dsize > strnlen(src, dsize) | dsize 必须正确反映 dst 容量 |
| `strcat_s(dst, dsize, src)` | dsize > strnlen(dst, dsize) + strnlen(...) | dsize 为 dst 总容量 |
| `sprintf_s(buf, size, fmt, ...)` | size > 格式化结果长度 | size 必须等于 sizeof(buf) |
| `memcpy_s(dst, dsize, src, n)` | dsize >= n | dsize 是 dst 容量，n 是要复制的字节数 |
| `gets_s(buf, n)` | n > 输入长度 | n 必须 <= buf 分配大小 |
| `snprintf(buf, size, fmt, ...)` | 返回值 < size | 返回值 >= size 表示截断 |

### 检测模式

```
# MATCH（触发检测）
strcpy(dst, src)           # dst 是 char dst[N] 且 src 来自外部
strcat(dst, src)           # dst 已含内容 + src 外部输入
sprintf(buf, "%s", input)  # %s 参数来自外部输入/argv/getenv
gets(buf)                  # 任何使用都是高危
memcpy(dst, src, n)        # n 来自变量/外部输入（非 sizeof(dst)）
memcpy(dst, src, sizeof(src))  # src 是函数参数退化为指针

# EXCLUDE（不报告）
strcpy_s(dst, sizeof(dst), src)  # C11 Annex K
sprintf_s(buf, sizeof(buf), ...)
snprintf(buf, sizeof(buf), ...) + 返回值检查
std::string / std::vector / std::array
```

### 修复指引

1. **C11 代码**：使用 `strcpy_s(dst, sizeof(dst), src)` 等 Annex K 函数
2. **非 Annex K 平台**：`snprintf(buf, sizeof(buf), "%s", src)` 并检查返回值
3. **C++ 代码**：使用 `std::string` / `std::vector` 替代 C 风格数组
4. **memcpy/memmove**：确保第三个参数 ≤ `sizeof(dst)`

---

## Scenario 2: 堆越界写入（CWE-122 / CWE-787）

### 威胁定义

堆上分配的缓冲区发生溢出，覆盖相邻堆块的元数据（malloc chunk header）。攻击者可利用堆风水（heap feng shui）技术实现代码执行。

**核心原则：堆上写入操作必须验证其大小不超过分配的堆块容量。关注 memcpy 第三个参数是否来自外部输入。**

### 检测逻辑

**Step 1: 识别堆分配点**
```c
ptr = malloc(size);
ptr = calloc(n, size);
ptr = realloc(old_ptr, size);
ptr = new T[n];
```

**Step 2: 检查写入操作是否越界**
- `memcpy(ptr, src, n)` — n > 分配大小？
- `strcpy(ptr, src)` — src 长度 > 分配大小？
- 循环写入 — 循环次数 > 分配大小 / 元素大小？
- `ptr[i] = val` — i 是外部控制变量？

**特有风险模式：**

**模式 1：大小计算错误**
```c
// BAD: 单位混淆
int *arr = malloc(n);              // 分配 n 字节，非 n 个 int
for (int i = 0; i < n; i++)
    arr[i] = i;                    // 溢出！需要 n * sizeof(int)
```

**模式 2：realloc 后使用旧大小**
```c
char *buf = malloc(64);
buf = realloc(buf, 128);
// 后续仍按 64 字节操作 buf → 浪费但安全，更危险的是 realloc 后写入超过新大小
```

### 修复指引

1. 使用 C++ `std::vector`/`std::string` 替代 C 风格堆数组
2. C 代码使用 `calloc`（清零+防止整数溢出）
3. 启用 AddressSanitizer（`-fsanitize=address`）
4. 统一使用 `safe_malloc(size)` 包装函数内置大小校验

---

## Scenario 3: 差一错误（CWE-193）

### 威胁定义

缓冲区操作中边界计算差一（`<=` 而非 `<`），导致写入刚好一个字节越界。这一字节可覆盖相邻堆块的 size 字段或栈帧的保存 EBP，实现控制流劫持。

**核心原则：循环边界和大小计算必须精确验证。特别关注 `<=` vs `<` 和 null 终止符额外占用的一字节空间。**

### 检测逻辑

**模式 1：循环边界差一**
```c
// BAD: <= 导致越界
char buf[64];
for (int i = 0; i <= 64; i++)    // 应该是 i < 64
    buf[i] = 0;                   // buf[64] 越界

// BAD: 倒序循环
for (int i = n; i >= 0; i--)      // 应该是 i > 0
    arr[i] = arr[i-1];
```

**模式 2：字符串操作**
```c
// BAD: strlen 不包含 '\0'
char *src = "hello";              // strlen=5
char dst[5];                      // 需要 6 字节
strcpy(dst, src);                 // 溢出 1 字节！
```

**模式 3：sizeof 指针陷阱**
```c
char buf[32];
memset(buf, 0, sizeof(buf));      // GOOD: 32
char *ptr = buf;
memset(ptr, 0, sizeof(ptr));      // BAD: 8（指针大小）
```

**模式 4：strncpy 无 null 终止**
```c
strncpy(dst, src, sizeof(dst));   // src >= sizeof(dst) 时不写 '\0'
// 需要手动：dst[sizeof(dst)-1] = '\0'
```

### 修复指引

1. 循环条件始终使用 `<` 而非 `<=`
2. `char buf[N]` 最多存储 N-1 个字符 + `\0`
3. strncpy 后手动 `buf[N-1] = '\0'`

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

**strcpy_s(dst, dsize, src)**:
- `dsize == sizeof(dst)`（栈数组）→ 安全
- `dsize < sizeof(dst)` → 截断风险
- `dsize > sizeof(dst)` → 逻辑错误

**memcpy_s(dst, dsize, src, n)**:
- `dsize >= n` → 安全
- `dsize < n` → 缓冲区溢出

**snprintf(buf, size, fmt, ...)**:
- 返回值 >= size → 截断（非溢出，但数据丢失）


---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: {存在性 — dst 缓冲区是否小于最大可能的源数据 (sizeof(dst) < max_strlen(src))?}

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: {可利用性 — 源数据是否来自程序外部（argv/stdin/网络/文件）?}

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: {缓解 — 复制操作前是否有 sizeof 边界检查或使用了安全变体 (strcpy_s/snprintf+sizeof/strlcpy)?}

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
    "Q1_bof_exist": true|false,
    "Q2_bof_exploit": true|false,
    "Q3_bof_mitigate": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：危险函数调用点完整代码，包含目标缓冲区声明/分配、源数据来源、拷贝长度参数
- [ ] **judgment_rationale**：缓冲区大小 vs 写入数据大小的关系分析

### 建议收集（SHOULD）
- [ ] **data_flow_path**：外部输入 → 危险函数参数 → 目标缓冲区的完整数据流
- [ ] **call_stack**：调用函数 → 危险函数的完整调用链，确认 sizeof 在跨函数传递时是否退化为指针大小

### 可选收集（MAY）
- [ ] **variable_state**：变量/分配大小、写入参数值、循环索引范围
- [ ] **sanitizer_analysis**：FORTIFY_SOURCE、Stack Protector、ASan 启用情况

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "64 字节栈缓冲区 buf 分配于函数入口", "file": "src/parser.c", "line": 40},
    "propagate": {"description": "strcpy 无长度限制，从 user_input 复制", "file": "src/parser.c", "line": 42},
    "sink": {"description": "user_input 可能超过 63 字节导致栈缓冲区溢出", "file": "src/parser.c", "line": 42}
  },
  "scenario": "Scenario 1: 无边界字符串拷贝",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
