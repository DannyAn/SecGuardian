---
name: secguard-cpp-hardcoded_secrets
description: "Detects hardcoded cryptographic keys, passwords, API tokens, and other secrets in C/C++ source code"
category: language-specific
language: cpp
topic: [crypto]
skill_id: crypto.hardcoded
signal_filter: crypto.hardcoded*
signal_source: call_sites[cat="crypto"]+string_literals
severity: high
cwe: [CWE-798]
---

# hardcoded_secrets 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `crypto.hardcoded` |
| signal_filter | `crypto.hardcoded*`（供 `secguard ./src c crypto.hardcoded` 过滤匹配） |
| signal_source | `call_sites[cat="crypto"]+string_literals`（静态分析模式为主，辅以 call_sites 线索） |
| 默认严重度 | High |
| CWE | CWE-798（使用硬编码凭据） |

---

## Scenario 1: 硬编码密码/API密钥/Token（CWE-798）

### 威胁定义

API Key、密码、私钥、Token 等敏感凭证硬编码在源代码中，进入版本控制后永久暴露。攻击者可通过源码泄露、供应链分析或反编译获取这些凭证。

**核心原则：代码中不得包含任何形式的敏感凭证。** 检测时要区分"看起来像秘密"和"真的是秘密"——变量命名线索 + 赋值字面量 + 上下文。

### 检测逻辑

#### Step 1: 变量命名 + 字面量赋值（高置信度）

当**同时满足**以下两个条件时报告：

**条件 A — 敏感变量名**（精确匹配，非子串）：
```
password, passwd, pass, pwd, secret, api_key, api_secret,
access_key, secret_key, private_key, encryption_key, jwt_secret,
db_password, db_pass, admin_pass, master_key, signing_key
```

**条件 B — 赋值为字符串字面量**：
```c
const char *password = "abc123";        // MATCH
char *api_key = "sk-live-xxx";          // MATCH
static const uint8_t aes_key[] = {0x01, ...};  // MATCH（密钥材料数组）
char secret[32] = "my-secret-key";      // MATCH
```

**不报告**（变量名匹配但并非赋值字面量）：
```c
char *password = getenv("DB_PASS");     // EXCLUDE: 从环境变量读取
String apiKey = System.getenv("KEY");   // EXCLUDE: 运行时获取
const int password_min_length = 8;      // EXCLUDE: 配置常量，非密码
char key_name[32] = "id_rsa";           // EXCLUDE: 密钥名称，非密钥内容
```

#### Step 2: 密码/凭证比较（高置信度）

```c
strcmp(input, "admin123") == 0          // MATCH: 硬编码验证密码
strncmp(pass, "secret", 6)              // MATCH
```

**不报告**：
```c
strlen(password) >= 8                   // EXCLUDE: 仅检查长度
strncmp(input, prefix, strlen(prefix))  // EXCLUDE: 前缀匹配，非完整密码比较
```

#### Step 3: 高熵字符串（低置信度，需额外上下文）

仅当同时满足以下条件时报告：
1. Base64 长度 >= 40 字符 或 Hex 长度 >= 32 字符
2. 字符串不在排除列表中（公开证书/公钥/image base64/OAS 许可文件）
3. 变量名或注释暗示这是密钥/凭证

#### Step 4: 连接字符串嵌入式凭据

```c
#define DB_URL "mysql://admin:secret@localhost:3306/db"   // MATCH
char conn[] = "jdbc:postgresql://host:5432/db?user=user&password=pass"; // MATCH
```

#### Step 5: 测试/示例文件排除

路径匹配以下模式时**不报告**：
```
*test*/   *_test.c   *_test.cpp   Test*.java   test_*.py
*mock*/   *fixture*/   *example*/   *demo*/   *sample*/
```
例外：如果测试文件中包含真实生产凭证格式（如有效的 `sk-live-` 前缀），仍报告。

### 检测模式

```
# === MATCH（触发检测）===

# 敏感变量名 + 字符串字面量赋值
(password|passwd|api_key|api_secret|secret_key|private_key|encryption_key|jwt_secret|admin_pass|master_key)\s*=\s*"[^"]
→ 排除 "$\{|"\{\{|getenv\(|System\.getenv\(
→ 排除 *_min_length|*_max_length|*_name|*_type\s*=
→ MUST: code_context（变量声明行及周边代码）
→ MUST: judgment_rationale（是否为真实凭证 vs 配置项/占位符）

# 密码字面量比较
(strcmp|strncmp)\s*\([^)]*"[^"]{3,}"[^)]*\)
→ 排除 strlen|\.length|\.size
→ 排除 "$\{|"\{\{
→ MUST: code_context（比较操作的完整上下文）
→ MUST: judgment_rationale（硬编码密码 vs 格式/长度验证）

# 高熵字符串
→ (base64长度>=40 或 hex长度>=32) AND (变量名/注释暗示密钥)
→ MUST: judgment_rationale（熵分析 + 上下文确认）

# 连接字符串嵌入式凭据
(mysql|postgres|jdbc|redis|mongodb)://[^:]+:[^@]+@

# === EXCLUDE（不报告）===

# 环境变量读取
getenv\(|System\.getenv\(|os\.environ|process\.env|os\.Getenv\(

# 公开证书
-----BEGIN CERTIFICATE-----|-----BEGIN PUBLIC KEY-----

# 模板变量
\$\{\w+\}|\{\{[^}]*\}\}

# 测试文件路径匹配
# *test*/ | *_test.c | *_test.cpp | *mock*/ | *fixture*/

# 配置项变量名（非凭证）
*_min_length|*_max_length|*_name|*_type\s*=

# 仅声明无初始化或来自函数调用
^\s*\w+\s+\*?\w+\s*;|=\s*\w+\(

# 全零占位数组
0x00,\s*0x00|=\{0\}
```

### 修复指引

1. **首选**：密钥管理服务（AWS KMS / HashiCorp Vault / K8s Secrets），运行时注入
2. **次选**：环境变量（`getenv("DB_PASS")`），配置文件不入库
3. **最低要求**：配置文件模板化（`config.template.json` 入仓库，`config.json` 不入仓库）
4. **补救**：已泄露密钥立即轮换 + Git 历史清除（`git filter-branch` / `BFG Repo-Cleaner`）

---

## Scenario 2: 硬编码加密密钥/IV（CWE-329）

### 威胁定义

CBC/GCM 等加密模式中 IV/Nonce 硬编码为固定值而非随机生成，破坏加密的语义安全性。硬编码加密密钥使得任何能访问源码/二进制的人都能解密数据。CWE-329（CBC 模式下使用固定 IV）和 CWE-798（使用硬编码凭据）共同覆盖此场景。

**核心原则：加密密钥必须从密钥管理服务或环境变量获取；IV/Nonce 必须每次操作随机生成或唯一递增。**

### 检测逻辑

#### Step 1: 识别密钥字面量赋值于加密 API

```c
// BAD: 加密密钥为字符串字面量
AES_set_encrypt_key((const uint8_t*)"1234567890123456", 128, &key);  // MATCH
DES_set_key(&des_key, (const_DES_cblock*)"8bytekey");                 // MATCH

// BAD: 固定密钥数组
static const uint8_t aes_key[32] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    // ... MATCH
};

// GOOD: 从密钥派生
uint8_t key[32];
HKDF_extract(key, sizeof(key), ikm, sizeof(ikm), salt, sizeof(salt));
```

#### Step 2: 识别固定 IV/Nonce

```c
// BAD: CBC 固定 IV
unsigned char iv[16] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                         0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10};
EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, key, iv);

// BAD: GCM 固定 Nonce（极度危险：相同 Nonce+Key 可恢复认证密钥）
unsigned char nonce[12] = "FIXED_NONCE_";
EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL);
EVP_EncryptInit_ex(ctx, NULL, NULL, key, nonce);

// BAD: 零 IV
unsigned char iv[16] = {0};  // 全零 IV
```

#### Step 3: 识别 IV 来源

检测 IV 变量是否：
- 初始化为字面量/常量 → **报告**
- 从固定字符串派生 → **报告**
- 未调用 CSPRNG 生成（`getrandom()`/`RAND_bytes`）→ **报告**
- 来自 CSPRNG → **不报告**

### 检测模式

```
# === MATCH（触发检测）===

# 加密密钥字面量
AES_set_encrypt_key\(.*"       # 密钥参数为字符串字面量
DES_set_key\(.*"               # DES 密钥字面量
RSA_generate_key_ex.*1024      # 同时需检查密钥强度（另由 key-length 规则覆盖）

# 固定 IV/Nonce 数组
unsigned char\s+(iv|nonce)\[.*\]\s*=\s*\{.*0x  # 硬编码字节数组
const.*(iv|nonce).*=.*".*"                       # 固定字符串 IV
→ MUST: code_context（IV 声明/初始化/加密调用完整代码）
→ MUST: judgment_rationale（IV 来源分析 — 字面量 vs 随机生成）

# 全零 IV
(unsigned char|uint8_t)\s+(iv|nonce)\[\d+\]\s*=\s*\{0\}

# === EXCLUDE（不报告）===

(RAND_bytes|getrandom|/dev/urandom|RAND_priv_bytes)  # CSPRNG 生成
ECB 模式（无 IV 参数）                                  # 由 ECB 检测器覆盖
SSL_write|SSL_read|TLS_internal                         # TLS 协议层管理
*test*/|*demo*/|*example*/                               # 测试/演示代码路径
```

### 修复指引

1. **加密密钥**：从密钥管理服务（KMS/Vault）获取，环境变量注入
2. **CBC 模式**：每次加密使用 `getrandom()`/`RAND_bytes()` 生成随机 IV
3. **GCM 模式**：每次加密使用唯一 Nonce（推荐 96-bit 随机，或确定性计数器 + 持久化状态保护）
4. **CTR 模式**：Nonce + 计数器组合必须每次加密唯一
5. **禁止**：固定字符串、全零 IV、从密钥派生的 IV

---

## Scenario 3: 弱密码存储与验证（CWE-916）

### 威胁定义

密码存储使用了弱哈希（MD5/SHA-1/SHA-256 单次）、可逆加密或明文比较，而非 bcrypt/scrypt/Argon2 等专用密码哈希函数。攻击者可通过哈希碰撞或 GPU 暴力破解快速恢复明文密码。

**核心原则：密码必须使用带盐的慢哈希。** 检测时要区分"密码存储场景"和"非安全哈希用途（校验和/去重）"——仅报告前者。

### 检测逻辑

#### Step 1: 弱哈希用于密码存储

```c
// BAD: MD5 或 SHA-1 用于密码验证
unsigned char hash[MD5_DIGEST_LENGTH];
MD5((unsigned char*)password, strlen(password), hash);  // MATCH

// BAD: SHA-256 单次（无盐/无迭代）
SHA256((unsigned char*)password, strlen(password), hash);  // MATCH
// 快速哈希可被 GPU 暴力破解

// BAD: 明文比较
strcmp(input_password, stored_password) == 0  // MATCH（密码验证上下文）
```

**不报告**（非密码存储场景）：
```c
// 文件完整性校验
MD5(file_buffer, file_size, digest);  // EXCLUDE: checksum 用途

// 哈希表/去重
size_t hash = std::hash<std::string>{}(key);  // EXCLUDE: 数据结构用途
```

#### Step 2: 弱密码验证模式

```c
// BAD: 字符串比较用于密码验证（无哈希）
if (strcmp(user_pass, stored_pass) == 0) {      // MATCH
    grant_access();
}

// GOOD: 使用专门的密码哈希验证库
#include <bcrypt.h>
bool ok = bcrypt_verify(password, stored_hash);  // OK
```

### 检测模式

```
# === MATCH（触发检测）===

# 弱哈希用于密码验证
MD5\(|MD5_Init|SHA1\(|SHA1_Init
→ 上下文含: password|passwd|pwd|secret|auth|login|credential
→ MUST: code_context（哈希调用及周边认证/注册代码）
→ MUST: judgment_rationale（MD5/SHA 是否用于密码存储 vs 文件校验/数据去重）

# 明文密码比较
strcmp.*password.*stored|strncmp.*pass.*stored
→ 上下文含: password|login|auth|verify|authenticate

# 可逆加密存储密码
EVP_EncryptInit.*password|AES_set_encrypt_key.*password
→ 上下文含: password|passwd|pwd|credential

# === EXCLUDE（不报告）===

bcrypt|scrypt|Argon2|PBKDF2|argon2id             # 安全密码哈希算法
checksum|file_hash|digest.*file|download.*hash     # 文件完整性校验
HMAC|message.*auth|api.*sign|signature.*verify     # 消息认证用途
*test*/|*mock*/|*fixture*/                         # 测试/Mock 代码
jwt\.(sign|verify)|oauth|sso                        # OAuth/SSO 外部 token
```

### 修复指引

1. **首选**：Argon2id（OWASP 推荐，抗 GPU/ASIC/侧信道）
2. **次选**：bcrypt（cost >= 12）/ scrypt
3. **可接受**：PBKDF2-HMAC-SHA256（迭代 >= 100,000）
4. **禁止**：MD5/SHA-1/SHA-256 单次、可逆加密、明文存储

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。




---

## 事实锚定反射

> **强制性。** 在输出 finding 之前必须回答所有三个问题。使用判定矩阵决定最终处理。

### Q1: 代码中是否存在硬编码的密钥/密码/Token (直接作为字符串字面量)?

**Yes** = 缺陷在此上下文中真实存在，有具体代码锚点
**No**  = 缺陷不成立——此调用点不满足缺陷触发条件

### Q2: 该凭据是否用于安全敏感操作 (认证/加密/签名)?

**Yes** = 攻击者可控制触发条件或输入
**No**  = 实际运行中不可达或不可控

### Q3: 该值是否为测试 mock/placeholder (fake key/test token) 或编译期占位符?

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
    "Q1_hardcoded_secret_present": true|false,
    "Q2_secret_security_sensitive": true|false,
    "Q3_secret_test_placeholder": true|false,
    "conclusion": "CONFIRMED|SUPPRESSED|UNKNOWN"
}
```

---

## 取证证据收集指引

### 必须收集（MUST）
- [ ] **code_context**：敏感变量声明行及周边代码（±15 行），包含变量名、赋值右侧表达式、使用上下文
      -> findings.evidence.code_context
- [ ] **judgment_rationale**：是否为真实凭证 vs 配置项/占位符的分析判断，包含变量名语义分析 + 值特征分析 + 使用上下文分析 + 文件路径分析
      -> findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：字符串字面量 -> 变量传递 -> 安全敏感操作/网络发送/日志输出的完整数据流
      -> findings.evidence.data_flow_path
- [ ] **call_stack**：密钥/密码从生成点 -> API 调用点的调用链，确认跨函数传递时的使用方式
      -> findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：密钥长度（bits）、IV/Nonce 生成方式、加密模式（CBC/GCM/ECB）、比较操作类型（strcmp/strncmp/strlen）
      -> findings.evidence.variable_state
- [ ] **sanitizer_analysis**：FORTIFY_SOURCE、AddressSanitizer 启用情况；字符串常量是否在只读段；是否有 -Werror=format-security 等编译时检查
      -> findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "skill_id": "crypto.hardcoded",
  "scenario": "Scenario 1: 硬编码密码/API密钥/Token",
  "severity": "high",
  "cwe": ["CWE-798"],
  "evidence_chain": {
    "source": {
      "description": "字符串字面量 \"sk-live-abc123def456\" 赋给 api_key 变量",
      "file": "src/auth/credentials.c",
      "line": 42
    },
    "propagate": {
      "description": "api_key 变量作为参数传递给 authenticate() 函数",
      "file": "src/auth/authenticate.c",
      "line": 44
    },
    "sink": {
      "description": "authenticate() 使用硬编码的 api_key 进行 HTTP Bearer 认证",
      "file": "src/auth/authenticate.c",
      "line": 55
    }
  },
  "judgment_matrix": {
    "Q1_value_has_secret_features": true,
    "Q2_used_for_security_sensitive": true,
    "Q3_is_test_mock_placeholder": false,
    "conclusion": "CONFIRMED"
  },
  "references_applied": [
    "exceptions.md",
    "cross-function.md",
    "false-positive.md"
  ],
  "cross_signal_analysis": false
}
```
