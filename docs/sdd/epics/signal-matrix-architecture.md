# EPIC-007: Signal Matrix Architecture

> **核心命题**: Tree-sitter 能提取的远不止函数调用。在一棵树上一次遍历，产出 N 种信号类型。Dispatcher 按命令需求组合信号。

## 架构定位

```
旧假设:     call_sites → Dispatcher → Worker      (单信号维度)
            ↑ 只提取 1 种 AST 节点

新架构:     Indexer Signal Matrix → Multi-Signal Dispatcher → Worker
            ↑ 同一 AST 提取 7 种信号类型 (零额外解析开销)
```

**核心原则**: 每个源码文件只解析一次。7 个 extractor 共享同一 AST，各自只读不写。

---

## §1 信号矩阵总览

| # | 信号类型 | 代码名 | AST 来源 | 核心用途 | secguard | secaudit | secreview |
|---|---------|--------|----------|---------|----------|----------|-----------|
| S1 | **调用点** | `call_sites` | `call_expression` 节点 | 内存安全、注入、资源管理 | ✅ | ✅ | ✅ |
| S2 | **字符串字面量** | `string_literals` | `string_literal` 节点 | 硬编码密钥、密码、令牌、URL | ✅ | ✅ | ✅ |
| S3 | **声明与数组大小** | `declarations` | `declaration` / `array_declarator` 节点 | 密钥长度、缓冲区大小、结构体字段 | — | ✅ | — |
| S4 | **常数值** | `value_constants` | `number_literal` / `enum` / 算法名称 | 弱算法(AES-ECB/DES)、短密钥(56bit) | — | ✅ | — |
| S5 | **导入/包含** | `imports` | `preproc_include` / `import_declaration` | 依赖审计、弃用 API 检测 | — | ✅ | — |
| S6 | **配置模式** | `config_patterns` | 赋值/对象属性/函数参数字面量 | TLS 配置、CORS、CSP、Auth中间件 | — | ✅ | — |
| S7 | **控制流守卫** | `control_flow` | `if_statement` / `return` / 守卫条件 | 认证绕过、错误处理缺失、鉴权守卫 | — | — | ✅ |

**信号选择规则**:
```
secguard  → S1 + S2            (内存安全 + 注入 + 硬编码)
secaudit  → S1 + S2 + S3 + S4 + S5 + S6  (全域审计)
secreview → S1 + S2 + S7        (PR 上下文 + 控制流)
```

---

## §2 信号类型详细设计

### S1: call_sites (现有，增强)

当前实现维护，增加以下函数到 `knownLibFuncs`:

```
// 新增安全相关函数
"srand":  {"srand", false, "crypto"},   // PRNG 种子，弱随机检测
"DES_ecb_encrypt": {"DES_ecb_encrypt", false, "crypto"},
"DES_set_key_checked": {"DES_set_key_checked", false, "crypto"},
"EVP_EncryptInit_ex": {"EVP_EncryptInit_ex", false, "crypto"},
"MD5":    {"MD5", false, "crypto"},
"RAND_load_file": {"RAND_load_file", false, "crypto"},
"DH_generate_key": {"DH_generate_key", false, "crypto"},
"EVP_DecryptInit_ex": {"EVP_DecryptInit_ex", false, "crypto"},
```

结构保持不变:
```go
type CallSite struct {
    CallerFunction string   `json:"caller"`
    CalleeName     string   `json:"callee"`
    File           string   `json:"file"`
    Line           uint     `json:"line"`
    Arguments      []string `json:"arguments"`
    IsSafeVariant  bool     `json:"safe_variant"`
    Category       string   `json:"category"`
}
```

---

### S2: string_literals (新增)

从 AST 提取所有字符串字面量，按模式分类。这是 `hardcoded_secrets`、credential scanning、URL/令牌检测的核心信号。

```go
type StringLiteral struct {
    File    string `json:"file"`
    Line    uint   `json:"line"`
    Value   string `json:"value"`    // 原始值（截断到 256 字符）
    Length  int    `json:"length"`   // 字符串长度
    Context string `json:"context"`  // 所在函数名，或"global"
    Kinds   []string `json:"kinds"`  // 推断类型: "secret","api_key","password","token","url","jwt","sql","cipher_name","generic"
}
```

**Kinds 推断规则** (基于字符串模式):

| 模式 | 类型标记 |
|------|---------|
| `sk-*`, `api_key`, `apikey`, `AKIA*` | `api_key` |
| `password=`, `passwd=`, `pwd=` 赋值上下文 | `password` |
| `eyJ*` (base64url JWT) | `jwt` |
| `Bearer `, `bearer ` | `token` |
| `https?://*` | `url` |
| `aes-*`, `des`, `rc4`, `md5`, `sha1` | `cipher_name` |
| `SELECT `, `INSERT `, `DELETE ` | `sql` |
| 长度 >= 20 且无空格 | `secret` |
| 其他 | `generic` |

**Tree-sitter 实现**: 在 `walkTopLevel()` 中增加 `string_literal` 节点处理。每个节点结合赋值上下文推断 kind。

**Regex 实现**: 匹配双引号/单引号字符串 + 周围上下文分析。

---

### S3: declarations (新增)

从 AST 提取类型声明，重点是数组大小、密钥长度、结构体字段。这对应 CWE-326(密钥长度不足)、缓冲区大小验证。

```go
type Declaration struct {
    File       string `json:"file"`
    Line       uint   `json:"line"`
    Name       string `json:"name"`       // 变量名
    TypeName   string `json:"type_name"`  // 类型: "unsigned char", "char", "int", "struct"...
    ArraySize  int    `json:"array_size,omitempty"` // 数组大小（如果有）key[7] → 7
    IsPointer  bool   `json:"is_pointer"`
    IsConst    bool   `json:"is_const"`
    Function   string `json:"function"`   // 所在函数
    Category   string `json:"category"`   // "buffer","key","credential","counter"
}
```

**Category 推断**:
- `unsigned char key[N]` (N < 32) → `key`, 用于密钥长度不足检测
- `char buf[N]` → `buffer`, 用于缓冲区溢出上下文验证
- `const char *password = ...` → `credential`

**Tree-sitter 实现**: 在 `declaration` 节点中深度分析 `array_declarator` 的子节点，提取数值大小。

**Regex 实现**: 匹配 `类型 变量[数字]` 和 `类型 变量 = 初始值` 模式。

---

### S4: value_constants (新增)

提取数值常量、枚举值、算法标识符。这是弱算法检测(AES-ECB、DES、RC4、MD5)、密钥长度校验的核心信号。

```go
type ValueConstant struct {
    File      string `json:"file"`
    Line      uint   `json:"line"`
    Value     string `json:"value"`          // 原始值: "128", "EVP_aes_256_gcm", "DES_ENCRYPT"
    ValueType string `json:"value_type"`     // "number","identifier","enum","function_ref"
    Context   string `json:"context"`         // 所在函数名, 或赋值对象名
    Category  string `json:"category"`        // "algorithm","key_length","mode","flag"
}
```

**Category 推断**:

| 值/模式 | 类型 | 安全含义 |
|---------|------|---------|
| `7`, `56` | `key_length` | DES 或短密钥 |
| `128`, `192`, `256` | `key_length` | AES 密钥长度 |
| `EVP_aes_*` | `algorithm` | AES 算法选择 |
| `DES_*`, `EVP_des_*` | `algorithm` | DES(已弃用) |
| `EVP_rc4*` | `algorithm` | RC4(已弃用) |
| `MD5`, `EVP_md5` | `algorithm` | MD5(已弃用) |
| `ECB`, `aes-128-ecb` | `mode` | ECB(不安全) |
| `DES_ENCRYPT`, `DES_DECRYPT` | `flag` | 模式标志 |

**Tree-sitter 实现**: 函数体内的数字字面量、函数引用参数、枚举引用。结合赋值上下文推断。

**注意**: S4 与 S3 部分重叠(key[7] vs key_length=56)，但来源不同——S3 看声明语法树，S4 看使用时的常数值。

---

### S5: imports (新增)

提取 #include/import/module 语句。这是依赖审计、弃用 API 检测的核心信号。

```go
type Import struct {
    File     string `json:"file"`
    Line     uint   `json:"line"`
    Path     string `json:"path"`     // 导入路径: "openssl/des.h", "crypto/md5"
    Kind     string `json:"kind"`     // "system","user","module","package"
    Category string `json:"category"` // "crypto","net","sys","db","web","unsafe"
}
```

**Category 推断**:

| 导入模式 | 类型 | 安全含义 |
|---------|------|---------|
| `openssl/*`, `crypto/*`, `mbedtls/*` | `crypto` | 加密库 |
| `net/*`, `socket`, `sys/socket` | `net` | 网络通信 |
| `sql*`, `mysql*`, `pgx`, `redis` | `db` | 数据库 |
| `unsafe`, `syscall`, `inline asm` | `unsafe` | 不安全操作 |
| `pthread*`, `sync*` | `sync` | 并发 |

**Tree-sitter 实现**: 捕获 `preproc_include` (C/C++)、`import_declaration` (Go/Python)、`import` (Java) 等节点。

**Regex 实现**: `#include\s*<.*>`、`import .*` 模式匹配。

---

### S6: config_patterns (新增)

提取常见的配置模式赋值。这是 secaudit 全域审计的核心扩展——检测 TLS 配置错误、CORS 配置、CSP 头缺失、认证中间件等。

```go
type ConfigPattern struct {
    File     string `json:"file"`
    Line     uint   `json:"line"`
    Key      string `json:"key"`     // 配置键: "tls_version", "cors_origin", "jwt_secret"
    Value    string `json:"value"`   // 配置值: "1.0", "*", "true"/"false"
    Category string `json:"category"` // "tls","cors","auth","session","csp"
}
```

**检测模式** (按语言):

| 配置域 | 检测模式 | 示例 |
|--------|---------|------|
| TLS | `SSLv3`, `TLSv1`, `tls_version="1.0"`, `MinVersion` | TLS 1.0/1.1 不安全 |
| CORS | `Access-Control-Allow-Origin: *`, `allowedOrigins: ["*"]` | 全通配 CORS |
| Auth | `enableAuth: false`, `authentication: none` | 认证绕过 |
| CSP | `Content-Security-Policy` 缺失 | XSS 防护缺失 |
| Session | `SameSite=None`, `secure=false`, `httpOnly=false` | Session 配置不当 |

**实现**: 主要基于正则模式匹配赋值语句中的配置键值对。Tree-sitter 可提取赋值表达式中的字符串和标识符。

---

### S7: control_flow (新增)

提取控制流结构中的守卫条件。这是 secreview 的核心扩展——检测未受保护的代码路径。

```go
type ControlFlowSignal struct {
    File       string `json:"file"`
    Line       uint   `json:"line"`
    Function   string `json:"function"`
    Kind       string `json:"kind"`    // "if_guard","return","error_check","loop"
    Condition  string `json:"condition,omitempty"`  // 守卫条件（截断 128 字符）
    HasReturn  bool   `json:"has_return,omitempty"`  // if 体包含 return
    Target     string `json:"target,omitempty"`      // 被守卫的操作
    Category   string `json:"category"`  // "auth","error","validation"
}
```

**检测重点**:
- `if` 检查返回值: `if (func() == -1) return err;` → `error_check`
- `if` 检查指针 NULL: `if (!ptr) return NULL;` → `validation`
- `if` 检查认证: `if (!authenticated) return 401;` → `auth`
- 无守卫的敏感操作: `strcpy(dst, src)` 前无 `if (strlen(src) < sizeof(dst))`

**Tree-sitter 实现**: 在函数体内遍历 `if_statement` 节点，分析条件和分支内容。

---

## §3 Dispatcher 集成

### 3.1 index.json 扩展

```json
{
  "path": "./src",
  "file_count": 15,
  "function_count": 96,
  "primary_language": "c",
  "files": ["src/crypto.c", ...],
  
  "symbols": { ... },
  "call_graph": { ... },
  "alloc_free": { ... },
  "lock_graph": { ... },
  
  "signals": {
    "call_sites":         [ ... ],     // S1
    "string_literals":    [ ... ],     // S2
    "declarations":       [ ... ],     // S3
    "value_constants":    [ ... ],     // S4
    "imports":            [ ... ],     // S5
    "config_patterns":    [ ... ],     // S6
    "control_flow":       [ ... ]      // S7
  }
}
```

所有信号统一放入 `signals` 命名空间，避免与现有字段冲突。

### 3.2 Dispatcher 信号选择

```json
// secguard → S1 + S2
// secaudit → S1 + S2 + S3 + S4 + S5 + S6
// secreview → S1 + S2 + S7
```

Dispatcher (commands/secguard.md) 在 Phase 1 Step 4b 分组前，
增加信号选择步骤:

```
Step 3e: 选择信号集
  COMMAND = 当前命令 (secguard/secaudit/secreview)
  
  signal_set = {
    "secguard":  ["call_sites", "string_literals"],
    "secaudit":  ["call_sites", "string_literals", "declarations",
                   "value_constants", "imports", "config_patterns"],
    "secreview": ["call_sites", "string_literals", "control_flow"]
  }[COMMAND]
  
  只加载 signal_set 中的信号 → 进入 Dispatcher 分组
```

### 3.3 新 Worker 类型

signal_set 扩展后，部分信号不需要调用点分析——如 `string_literals` 可直接在 Indexer 层过滤后报告。新增两类 Worker：

| Worker 类型 | 驱动信号 | 描述 |
|------------|---------|------|
| CallSite Worker (现有) | call_sites | 现有 W1-W5 协议，不改变 |
| StringLiteral Worker (新增) | string_literals | 硬编码密钥检测，快速模式匹配 + LLM 审核 |
| Declaration Worker (新增) | declarations + value_constants | 密钥长度、缓冲区大小审核 |
| Config Worker (新增) | imports + config_patterns | 依赖审计、配置安全 |
| Flow Worker (新增) | control_flow | 控制流守卫检视 |

每种 Worker 可共享现有 W1-W5 协议框架，但各步骤的具体执行不同。

---

## §4 生产级扩展 — 多仓库与超大代码库

### 4.1 多仓库扫描流程

```
扫描 5 个仓库:
  repo-A/src/ (200 .c files)
  repo-B/src/ (150 .c files)
  repo-C/lib/ (80 .c files)
  repo-D/src/ (180 .c files)
  repo-E/src/ (70 .c files)
  -----------
  合计: 680 files

策略: 每个仓库独立索引(并行) → 复合索引合并 → Dispatcher 统一派发

并行索引:
  secguardian-index -path repo-A/src -output index-A.json
  secguardian-index -path repo-B/src -output index-B.json
  ... (可并行)

合并:
  secguardian-merge index-*.json -output merged-index.json
  → 合并 signals 数组，symbols/functions 去重
  → 更新 file_count 等统计字段

Dispatcher 读取 merged-index.json，按正常流程执行
```

### 4.2 680 文件信号矩阵规模估算

基于 cpp-vuln-demo (15 files, 115 call_sites) 线性外推:

| 信号 | 15 files | 680 files | 单条大小 | 总大小 |
|------|---------|-----------|---------|-------|
| call_sites | 115 | ~5,213 | ~150B | ~782KB |
| string_literals | ~30 | ~1,360 | ~200B | ~272KB |
| declarations | ~50 | ~2,267 | ~120B | ~272KB |
| value_constants | ~40 | ~1,813 | ~100B | ~181KB |
| imports | ~20 | ~907 | ~80B | ~72KB |
| config_patterns | ~5 | ~226 | ~150B | ~34KB |
| control_flow | ~80 | ~3,627 | ~100B | ~363KB |
| **总计** | **~340** | **~15,413** | | **~1.98MB** |

**index.json 预计 < 2MB** — 完全可一次读入内存。不需要分片索引。

### 4.3 分批派发升级

当前 BATCH_SIZE=50 基于 call_sites。signal_set 扩展后:

```
BATCH_SIZE_PER_SIGNAL = {
  "call_sites":      50,     // 同现有
  "string_literals": 100,    // 轻量检测，可更大
  "declarations":    200,    // 纯模式匹配，少量 LLM
  "value_constants": 200,
  "imports":         500,    // 依赖列表，纯规则
  "config_patterns": 100,
  "control_flow":    50,     // 需要 W5 反思，应保持小
}
```

Worker 数量估算 (680 files):

| Signal | 总数 | BATCH_SIZE | Workers |
|--------|------|-----------|---------|
| call_sites | 5,213 | 50 | ~105 |
| string_literals | 1,360 | 100 | ~14 |
| declarations | 2,267 | 200 | ~12 |
| value_constants | 1,813 | 200 | ~10 |
| imports | 907 | 500 | ~2 |
| config_patterns | 226 | 100 | ~3 |
| control_flow | 3,627 | 50 | ~73 |
| **总计** | | | **~219** |

Workflow 自动并发约 10，约 22 wave。每个 Worker 处理 1 个 Batch (1-2 分钟)。**全量扫描预计 ~45 分钟。**

### 4.4 内存安全

所有 extractor 共享同一 Tree-sitter 树 → 解析阶段仅 1 份 AST 在内存。
每个 extractor 只读不写，不拷贝子树。
输出序列化前保持在 `[]CallSite` / `[]StringLiteral` 等切片中，不在堆上累积大型中间结构。

---

## §5 实施路径

### Phase 1: Type definitions + S2 string_literals (当前)
- `types.go`: 新增 StringLiteral、Declaration、ValueConstant、Import、ConfigPattern、ControlFlowSignal 类型
- `parser_ts.go`: 新增 string_literal 遍历 + 分类
- `parser_re.go`: 新增字符串正则提取
- 验证: crypto.c 的硬编码密钥检出

### Phase 2: S3 declarations + S4 value_constants (当前)
- `extractDeclarations()`: AST 中提取声明和数组大小
- `extractValueConstants()`: AST 中提取常量值
- 验证: key[7] 检出 56-bit key

### Phase 3: S5 imports + S6 config_patterns
- `extractImports()`: 提取依赖
- `extractConfigPatterns()`: 提取配置模式
- 验证: openssl/des.h 依赖检出

### Phase 4: S7 control_flow
- `extractControlFlow()`: 提取控制流守卫
- 验证: NULL 检查缺失检出

### Phase 5: Dispatcher + Worker 集成
- 命令信号配置
- 新 Worker 模板
- Batch 按信号类型独立配置

---

## §6 Schema 验证

每个信号类型有其 JSON Schema:

```json
{
  "string_literals": {
    "type": "array",
    "items": {
      "type": "object",
      "required": ["file", "line", "value", "length", "kinds"],
      "properties": {
        "value": {"type": "string", "maxLength": 256},
        "length": {"type": "integer", "minimum": 1},
        "kinds": {"type": "array", "items": {"type": "string"}}
      }
    }
  }
}
```

`validate-index.py` 新增 schema 校验命令:
```bash
python3 scripts/validate-index.py --schema signals --index index.json
```
