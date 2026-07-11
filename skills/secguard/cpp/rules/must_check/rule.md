---
name: secguard-cpp-must_check
description: "Detect unchecked return values from allocation, I/O, and system functions"
category: language-specific
language: cpp
topic: [memory]
skill_id: memory.must
signal_filter: memory.must*
signal_source: call_sites[callee="malloc|realloc|calloc|fopen|fread|fgets|scanf|gets"]
severity: high
cwe: [CWE-252]
---

# must_check 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `memory.must` |
| signal_filter | `memory.must*`（供 `secguard ./src c memory.must` 过滤匹配） |
| signal_source | `call_sites[cat="memory|io"]` |
| 默认严重度 | High |

---

## Scenario 1: 内存分配返回值未检查（CWE-252）

### 威胁定义

内存分配函数（malloc/calloc/realloc/reallocarray/mmap）在内存不足时返回 NULL。如果返回值未经检查就直接解引用，会导致空指针解引用（NULL dereference），造成程序崩溃或拒绝服务。realloc 的特殊性在于：直接使用 `ptr = realloc(ptr, size)` 会在 realloc 失败时导致原指针泄漏（原内存无法释放也无法访问）。

**核心原则：内存分配函数的返回值在使用前必须与 NULL 比较。** realloc 必须使用临时变量接收返回值。

### 检测逻辑

**识别分配调用及其返回值检查**

| 函数 | 正确用法 | 错误用法 |
|------|---------|---------|
| `malloc(size)` | `char *b = malloc(n); if (!b) return;` | `char *b = malloc(n); use(b);` |
| `calloc(n, sz)` | `int *a = calloc(n, sz); if (!a) return;` | `int *a = calloc(n, sz); a[0] = 42;` |
| `realloc(p, sz)` | `void *t = realloc(p, sz); if (!t) { free(p); return; } p = t;` | `p = realloc(p, sz);` |
| `mmap(...)` | `p = mmap(...); if (p == MAP_FAILED) return;` | `p = mmap(...); use(p);` |
| `reallocarray(p, n, sz)` | `void *t = reallocarray(p, n, sz); if (!t) return;` | `p = reallocarray(p, n, sz);` |

**检查生命周期验证**：

1. **立即检查**：分配后 1-3 行内必须存在 `if (!ptr) return/abort/ERROR;`
2. **使用前检查**：检查必须在指针第一次被使用（解引用/读取/传递到解引用函数）之前
3. **realloc 特殊规则**：必须使用临时变量；`ptr = realloc(ptr, size)` 禁止
4. **后检查误报**：`char *b = malloc(100); b[0] = '\0'; if (!b) return;` —— 先使用后检查，无效防护

### 检测模式

```
# MATCH（触发检测）
malloc/calloc/realloc/mmap/reallocarray 的返回值未在 5 行内与 NULL 比较
→ 返回值被立即用于解引用（-> / [] / memcpy / strcpy 等）
→ realloc 返回值直接赋值给原指针（无临时变量）
→ 检查出现在使用之后

# EXCLUDE（不报告）
分配后即刻（1-3 行）检查：if (!ptr) return / abort / exit / goto error
(void) 显式丢弃返回值（开发者意图明确）
返回值通过深层封装返回给调用方，调用方负责检查
已知的 checked 封装：xmalloc / safe_malloc / MALLOC / g_new / new (std::nothrow)
```

### 修复指引

1. **始终检查**：`char *p = malloc(n); if (!p) return ENOMEM;`
2. **realloc 临时变量**：`void *np = realloc(p, n); if (!np) { free(p); return; } p = np;`
3. **mmap**：检查 `p == MAP_FAILED` 而非 `!p`（mmap 失败返回 MAP_FAILED 而非 NULL）
4. **检查时机**：检查必须在指针首次使用之前

---

## Scenario 2: IO 资源获取返回值未检查（CWE-252）

### 威胁定义

IO 打开函数（fopen/socket/accept）在资源获取失败时返回错误标识（NULL 或 -1/INVALID_SOCKET）。如果返回值未经检查就立即用于文件读写或网络收发，会导致对无效文件描述符的操作，轻则返回错误，重则程序崩溃。在安全上下文中，这可能被利用来绕过预期文件不存在时的退出路径。

**核心原则：IO 资源获取函数的返回值必须在第一次使用前验证。**

### 检测逻辑

| 函数 | 成功返回值 | 失败返回值 | 正确检查 |
|------|-----------|-----------|---------|
| `fopen(path, mode)` | 非 NULL FILE* | NULL | `if (!fp) return;` |
| `socket(domain, type, proto)` | >= 0 int | -1 | `if (sock < 0) return;` |
| `accept(sock, addr, len)` | >= 0 int | -1 | `if (client < 0) return;` |

**检查生命周期**：

```c
// 正确：fopen 返回值立即检查
FILE *fp = fopen(path, "r");
if (!fp) {
    perror("fopen");
    return ERROR;
}

// 错误：fopen 返回值未检查，直接使用
FILE *fp = fopen(path, "r");
fread(buf, 1, size, fp);            // fp 可能为 NULL

// 正确：socket 返回值立即检查
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) {
    perror("socket");
    return ERROR;
}

// 错误：socket 返回值未检查
int sock = socket(AF_INET, SOCK_STREAM, 0);
send(sock, data, len, 0);           // -1 作为 socket 句柄
```

### 检测模式

```
# MATCH（触发检测）
fopen/socket/accept 的返回值未在 5 行内与 NULL/-1/INVALID_SOCKET 比较
→ 返回值被传递给 read/write/send/recv/fread/fwrite 等函数
→ 函数在一个表达式中被调用且返回值未存储

# EXCLUDE（不报告）
返回值被显式 (void) 丢弃
返回值通过函数返回给调用方，调用方负责检查
资源包装在 RAII 类中（如 std::ifstream，构造函数内部检查）
socket 后检查 WSAGetLastError() 模式（仅限 Windows）
```

### 修复指引

1. **fopen**：`FILE *fp = fopen(p, "r"); if (!fp) perror("fopen"), return ERROR;`
2. **socket**：`int s = socket(AF_INET, SOCK_STREAM, 0); if (s < 0) return ERROR;`
3. **accept**：`int c = accept(s, NULL, NULL); if (c < 0) return ERROR;`
4. **RAII 包装**：使用 `std::ifstream` / `std::fstream` 等 RAII 类自动管理资源错误

---

## Scenario 3: 数据传输操作返回值未检查（CWE-252）

### 威胁定义

数据传输函数（snprintf/fgets/fread/fwrite/read/write/setenv）返回实际处理的字节数或错误标识，但调用方经常忽略返回值，导致：snprintf 截断后仍假定输出完整、fread 部分读取后处理未初始化数据、write 短写入（short write）后数据不完整、setenv 失败后环境变量实际未设置。攻击者可利用这些状态不一致绕过安全检查或泄露信息。

**核心原则：数据传输操作的返回值必须验证是否达到预期效果。** 部分成功（short read/write）必须处理，完整失败必须返回错误。

### 检测逻辑

**snprintf/vsnprintf**：

```c
// 正确：检查截断
int n = snprintf(buf, sizeof(buf), "prefix_%s", name);
if (n < 0) return ERROR;                    // 编码错误
if ((size_t)n >= sizeof(buf)) return ENOSPC; // 输出截断

// 错误：未检查
snprintf(buf, sizeof(buf), "prefix_%s", name);
process_config(buf);                         // buf 可能不完整
```

**fgets**：

```c
// 正确：检查返回值
if (!fgets(line, sizeof(line), fp)) { clearerr(fp); return ERROR; }

// 错误：未检查
fgets(line, sizeof(line), fp);
printf("%s", line);                          // 输出陈旧/垃圾数据
```

**fread**：

```c
// 正确：检查读取量与期望量
size_t nr = fread(data, 1, sizeof(data), fp);
if (nr < sizeof(data)) {
    if (ferror(fp)) return ERROR;
    // 部分读取 —— 仅处理 nr 字节
}
process_n(data, nr);

// 错误：未检查
fread(data, 1, sizeof(data), fp);
process(data);                               // 处理未初始化数据
```

**fwrite**：

```c
// 正确：检查写入量与期望量
size_t wr = fwrite(data, 1, len, fp);
if (wr < len) return ERROR;                  // 部分写入

// 错误：未检查
fwrite(data, 1, len, fp);
// 假定全部写入，但文件可能不完整
```

**read/write**：

```c
// 正确：检查并处理短写入
ssize_t n = read(fd, buf, sizeof(buf));
if (n < 0) return ERROR;
process(buf, (size_t)n);                     // 仅处理已读取字节

ssize_t rem = (ssize_t)datalen;
char *p = data;
while (rem > 0) {
    ssize_t n = write(fd, p, (size_t)rem);
    if (n < 0) return ERROR;
    rem -= n;
    p += n;
}

// 错误：未检查
read(fd, buf, sizeof(buf));
process(buf);                                // 部分填充或错误状态
```

**setenv**：

```c
// 正确：检查返回值
if (setenv("PATH", new_path, 1) < 0) { perror("setenv"); return ERROR; }

// 错误：未检查
setenv("PATH", new_path, 1);                 // 环境表满时静默失败
```

### 检测模式

```
# MATCH（触发检测）
snprintf/vsnprintf 返回值未与缓冲区大小比较 ← 输出截断未被检测
fgets 返回值未被检查是否 == NULL            ← EOF 导致处理旧数据
fread 返回值 < 请求字节数未被检测            ← 部分读取，数据未初始化
fwrite 返回值 < 请求字节数未被检测            ← 部分写入，数据不完整
read/write 返回值 == -1 或 < 请求字节数未被检测 ← I/O 错误或短写入
setenv 返回值未被检查                        ← 环境表满时未设环境变量

# EXCLUDE（不报告）
snprintf(NULL, 0, ...) 大小查询模式 — 返回预期长度，非真正的 IO
(void) 显式丢弃 — 开发者意图明确（如日志写入）
进入不可达路径的写入（后续立即 exit/abort）
fwrite 在 flush 或关闭场景（fclose 时无法重写）
read/write 在信号处理器中（async-signal-safe 上下文）
循环中检查 read 返回值的情况（n < 0 / n == 0 分支处理）
```

### 修复指引

1. **snprintf**：`if ((size_t)n >= sizeof(buf)) return ENOSPC;`
2. **fgets**：`if (!fgets(buf, sz, fp)) { clearerr(fp); return; }`
3. **fread**：`if (nread < expected && ferror(fp)) return ERROR;`
4. **fwrite**：`if (written < len) return ERROR;` 或实现重试循环
5. **read**：检查 `n < 0`（错误）和 `n < expected`（短读）
6. **write**：实现短写入重试循环：`while (remaining > 0) { n = write(...); if (n < 0) return; remaining -= n; p += n; }`
7. **setenv**：`if (setenv(...) < 0) return ERROR;`

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


   - 检查返回值是否立即与 NULL 比较：`if (ptr == NULL) return ERROR;`
   - 检查返回值是否立即用于解引用：`malloc(100)->field = 1;` // BAD
   - 对于 realloc：检查是否使用了临时指针

   - fopen：检查返回值是否与 NULL 比较
   - socket/accept：检查返回值是否与 -1 或 INVALID_SOCKET 比较

   - 检查返回值是否与缓冲区大小比较：仅检查 `n > 0` 不够，应检查 `(size_t)n >= sizeof(buf)`

   - 检查返回值是否与 NULL 比较（fgets 返回 NULL 表示 EOF 或错误）

   - 检查返回值是否等于期望字节数；部分读取需处理

   - 检查 `n == -1` 错误以及是否为部分字节；短写入需继续写入

   - 检查返回值是否为 -1（环境变量已满）


---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：存在未检查返回值的调用点代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：未检查返回值是否导致空指针解引用/短写入/数据不完整
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：返回值从产生到使用或丢弃的语句路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：分配函数到直接使用点的调用链
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：变量的检查状态（已检查/未检查/检查后使用）
      → findings.evidence.variable_state
- [ ] **func_scope**：调用点所在函数的返回值是否向上传播
      → findings.evidence.func_scope

---

---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: 函数返回值是否被忽略 (未赋值给变量直接调用)?

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: 忽略的返回值是否影响后续操作的安全性?

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: 调用者是否通过其他方式处理了错误状态 (errno 检查/全局错误码)?

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
    "Q1_unchecked_return": true|false,
    "Q2_safety_impact": true|false,
    "Q3_error_handled": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "malloc(1024) 返回堆分配指针，无 NULL 检查", "file": "src/parser.c", "line": 42},
    "propagate": {"description": "返回值直接赋给 buf，未与 NULL 比较即传递到下游", "file": "src/parser.c", "line": 42},
    "sink": {"description": "buf 直接用于 memcpy 的解引用操作，NULL 时崩溃", "file": "src/parser.c", "line": 44}
  },
  "scenario": "Scenario 1: 内存分配返回值未检查",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
