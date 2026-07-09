---
name: secguard-cpp-error_propagation
description: "Detect silently ignored error returns — fopen NULL consumed, malloc unchecked, unwrapped failure-returning calls in void context"
category: language-specific
language: cpp
topic: [memory]
skill_id: error.propagation
signal_filter: error.propagation*
signal_source: call_sites[cat="error"]
severity: medium
cwe: [CWE-390]
---

# error_propagation 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `error.propagation` |
| signal_filter | `error.propagation*`（供 `secguard ./src c error.propagation` 过滤匹配） |
| signal_source | `call_sites[cat="error"]` |
| 默认严重度 | Medium |

---

## Scenario 1: 堆内存分配返回值未检查（CWE-390）

### 威胁定义

malloc / calloc / realloc / strdup / new (std::nothrow) 等内存分配函数在内存不足时返回 NULL（或 nullptr），调用方未检查返回值就直接解引用会导致空指针解引用（segfault）或使用未初始化内存。攻击者可利用此漏洞触发拒绝服务，或在特定条件下利用空指针解引用后的代码路径执行任意操作。

对于 nothrow new，虽不会抛出 `std::bad_alloc`，但返回 nullptr 时未检查同样危险。

**核心原则：每个堆内存分配函数的返回值都必须在使用前进行 NULL 检查。** Operator new（默认抛出异常）不需 NULL 检查，但 new(std::nothrow) 和 C 风格分配函数必须检查。

Guard-rule 关联：本 Scenario 对应 `error-exception-swallow` 中 C/C++ 错误码忽略模式（Step 3），重点关注分配失败被静默忽略导致的安全漏洞。

### 检测逻辑

**模式 B: malloc 返回值未检查**

```c
// 脆弱 — 未检查 malloc 返回值
struct config *cfg = malloc(sizeof(*cfg));
cfg->timeout = 30;      // cfg 可能为 NULL → segfault

// 安全 — 使用时前检查 NULL
struct config *cfg = malloc(sizeof(*cfg));
if (!cfg) {
    return ENOMEM;
}
cfg->timeout = 30;
```

**模式 D: 链式检查 vs 分离调用后的解引用**

```c
// 安全（链式检查）:
if (!(fp = fopen(path, "r"))) {
    return -1;
}

// 脆弱（分离调用且未检查）:
fp = fopen(path, "r");
// 缺少: if (!fp) ...
fread(buf, 1, n, fp);
```

**C++ nothrow new:**

```cpp
// 脆弱: 不检查 nothrow new 的返回值
int *p = new (std::nothrow) int[1024];
p[0] = 42;  // p 可能为 nullptr

// 安全: 检查 nothrow new
int *p = new (std::nothrow) int[1024];
if (!p) return;
p[0] = 42;
```

### 检测模式

```
# MATCH（触发检测）
→ malloc/calloc/realloc/strdup 返回值赋值后 3 行内被解引用且无 NULL 检查
→ nothrow new 返回值赋值后 3 行内被解引用且无 nullptr 检查
→ 链式调用分离: ptr = malloc(n); *ptr = 0;（中间无 if (!ptr)）

# EXCLUDE（不报告）
→ xmalloc/checked_malloc/ec_malloc 等包装函数（内部含 exit/abort 确保不返回 NULL）
→ 编译期小常量分配（如 malloc(64)）— 降低 confidence，但大项目仍需关注
→ RAII 包装类构造中的分配（构造失败由异常保证）
→ std::vector / std::string 内部使用的分配函数 — 不可控的 STL 内部分配
```

### 修复指引

1. 所有 malloc/calloc/realloc/strdup 调用后立即检查返回值是否为 NULL
2. 使用包装函数（xmalloc）内部处理 OOM，避免在每个调用点重复检查
3. 使用 C++ RAII 类型（`std::vector`、`std::string`、智能指针）替代裸指针
4. 优先使用 `new`（默认异常）而非 `new (std::nothrow)`，以利用异常机制

---

## Scenario 2: 系统/IO/安全 API 返回值忽略（CWE-390 / CWE-391）

### 威胁定义

fopen / open / read / write / close 等系统调用或 IO 操作失败时通过返回值（NULL 或 -1）报告错误。调用方如果忽略返回值就继续使用资源，会导致对无效文件描述符或未打开文件进行操作，不仅产生 crash，还可能被攻击者利用以实现信息泄露或越权访问。

对于 pthread_mutex_lock、SSL_accept、access 等安全检查或同步 API，忽略返回值会让安全机制完全失效。此模式对应 `error-exception-swallow` guard-rule 中的 Step 3（C/C++ 错误码忽略）——类似于异常被空 catch 吞掉，C/C++ 中通过忽略返回值实现"静默吞掉错误"。

**核心原则：任何可能返回错误的系统调用和安全 API 的返回值必须在使用前进行检查。** 允许 close/shutdown 路径不检查（已不可恢复），但仍需记录。

### 检测逻辑

**模式 A: fopen 返回值未检查**

```c
// 脆弱
FILE *fp = fopen(path, "r");
fread(buf, 1, sizeof(buf), fp);  // fp 可能为 NULL → crash / UB
fclose(fp);

// 安全
FILE *fp = fopen(path, "r");
if (!fp) {
    fprintf(stderr, "Cannot open %s: %s\n", path, strerror(errno));
    return -1;
}
fread(buf, 1, sizeof(buf), fp);
fclose(fp);
```

**模式 C: 显式丢弃返回值**

```c
// 脆弱 — (void) 显式丢弃
(void)write(fd, buf, n);  // 返回值被强制 void 丢弃
(void)read(fd, buf, n);   // 可能返回 < 0 或 < n

// 安全
ssize_t written = write(fd, buf, n);
if (written < 0) {
    // handle write error
} else if ((size_t)written < n) {
    // partial write — 需要重试
}
```

**模式 E: 系统调用返回值未检查**

```c
// 脆弱
int fd = open(path, O_RDONLY);
read(fd, buf, n);   // open 可能返回 -1

// 安全
int fd = open(path, O_RDONLY);
if (fd < 0) {
    return -1;
}
ssize_t r = read(fd, buf, n);
if (r < 0) {
    close(fd);
    return -1;
}
```

**模式 F: 构造函数中的错误（C++）**

```cpp
// 脆弱 — 构造函数无法返回错误码
class FileReader {
    FILE *fp;
public:
    FileReader(const char *path) {
        fp = fopen(path, "r");   // 失败只能通过异常或成员标志
    }
    void read() {
        fread(buf, 1, n, fp);    // fp 可能 NULL
    }
};

// 安全 — 使用工厂方法
class FileReader {
    FILE *fp;
    FileReader(FILE *f) : fp(f) {}
public:
    static std::unique_ptr<FileReader> create(const char *path) {
        FILE *fp = fopen(path, "r");
        return fp ? std::make_unique<FileReader>(fp) : nullptr;
    }
};
```

**Guard-Rule 补充: 安全/同步 API 返回值忽略（error-exception-swallow Step 3）**

```c
// 脆弱 — 线程锁失败被忽略
int ret = pthread_mutex_lock(&mutex);
// ret 未被检查 — 锁失败，后续并发访问无保护

// 脆弱 — SSL 握手失败被忽略
if (SSL_accept(ssl) <= 0) {
    // 空处理或仅日志 — 已建立的连接未经认证
}

// 脆弱 — 权限检查失败被忽略
int rv = access(path, R_OK);
if (rv == -1) {
    // 空处理块 — 权限检查被绕过
}
// 继续读取文件

// 脆弱 — 信号处理错误被忽略
signal(SIGTERM, handler);  // 返回值（旧 handler 地址或 SIG_ERR）未检查
```

### 检测模式

```
# MATCH（触发检测）
→ fopen 返回值赋值后 3 行内在无 NULL 检查的情况下被 fread/fwrite/fclose 使用
→ open() 返回值赋值后 3 行内在无 < 0 检查的情况下被 read/write/close 使用
→ (void) cast 明确丢弃可能返回错误码的函数调用
→ read/write 返回值被赋值后从未使用（等效于 (void) casting）
→ pthread_mutex_lock / SSL_accept / access 等安全关键 API 返回值未被检查
→ signal() 返回值（旧 handler / SIG_ERR）未检查

# EXCLUDE（不报告）
→ close() / fclose() 在清理/shutdown/异常恢复路径中的返回值未检查
→ RAII 包装类（std::ifstream / std::unique_ptr / 使用异常的工厂方法）
→ retry 循环中的 read/write: while ((n = read(fd, buf, sz)) > 0)
→ assert(fp != NULL) 在 Debug 模式检查但 Release 无保护 → 标记但 confidence: low
→ std::vector / std::string 内部使用的分配函数
→ 返回值被赋值给从未使用的局部变量（等效于 (void) casting，仍标记但 severity: low）
```

### 修复指引

1. 所有系统调用（open / read / write / fread / fclose / close）和 fopen 返回值必须检查
2. 避免使用 `(void)` 强制丢弃返回值 — 应明确处理或传播错误
3. 安全关键 API（pthread_mutex_lock / SSL_accept / access）返回值必须检查且失败时必须中止操作
4. C++ 中使用工厂 + RAII 模式而非构造函数内裸 `fopen()`
5. 关闭路径（close / fclose）在不可恢复阶段可仅记录不处理，但正常路径仍需检查
6. 部分写入（partial write）需实现重试逻辑

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


- `fopen(path, mode)`: path 是否来自用户输入？如果不是则风险较低（但仍然需要 NULL 检查）
- `malloc(n)`: n 是否为 0 或极端值？如果 n 来自用户且可能很大，NULL 可能性更高
- `read(fd, buf, n)`: fd 有效性（来自 open 还是 socket？）


---

## 取证证据收集指引

> 参考 guard-rule `error-exception-swallow` 的证据收集要求。

### 必须收集（MUST）
- [ ] **code_context**：错误返回函数的调用点及后续使用代码（标注 Source / Propagate / Sink 三个阶段）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：返回值未检查导致的内存/安全风险说明及所属 Scenario
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：API 返回值从赋值到解引用或传递的路径（标注各节点的检查状态）
      → findings.evidence.data_flow_path
- [ ] **call_stack**：从当前函数到 caller / callee 的调用链（深度最多 1 级跨函数追踪）
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：返回值的类型（FILE\* / int / ssize_t / void\*）及其后续赋值或使用方式
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：项目是否使用了 checked_malloc / xmalloc 等安全包装，或启用了编译器警告（如 GCC `-Wunused-result`）
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "fopen 调用未检查 NULL 返回值", "file": "src/file_handler.c", "line": 42},
    "propagate": {"description": "fopen 返回值直接传递给 fread 无 NULL 检查", "file": "src/file_handler.c", "line": 42},
    "sink": {"description": "fread 使用 fp 参数，fp 可能为 NULL 导致 crash", "file": "src/file_handler.c", "line": 43}
  },
  "scenario": "Scenario 2: 系统/IO/安全 API 返回值忽略",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
