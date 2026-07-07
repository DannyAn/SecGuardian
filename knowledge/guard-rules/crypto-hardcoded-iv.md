---
confidence: dynamic
cwe: CWE-329
detector: crypto-hardcoded-iv
language: [c, cpp, java, python, go, js]
precision: high
severity: high
tags: [crypto, iv, nonce, fixed]
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "crypto.crypto-hardcoded-iv",
  "type": "guard-rule",
  "namespace": "crypto",
  "severity": "High",
  "cwe": "CWE-329",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "c",
    "cpp",
    "java",
    "python",
    "go",
    "js"
  ],
  "target_functions": [
    "aes_256_cbc",
    "aes_256_gcm",
    "arameterSpec",
    "byte",
    "code_context",
    "createCipheriv",
    "ctrl",
    "from",
    "getBytes",
    "init",
    "judgment_rationale",
    "nonce"
  ],
  "match_patterns": [
    "unsigned char\\s+(iv|nonce)\\[.*\\]\\s*=\\s*\\{.*0x  # 硬编码字节数组",
    "const.*(iv|nonce).*=.*\".*\"                       # 固定字符串 IV",
    "byte\\[\\]\\s+(iv|nonce)\\s*=\\s*\\{\\s*(0x[0-9a-fA-F]{2}|[0-9]+)",
    "new\\s+IvParameterSpec\\([^)]*\\{(?!.*SecureRandom)  # 字节字面量",
    "(GCMParameterSpec|IvParameterSpec)\\(.*\".*\"\\.getBytes\\(\\)",
    "(GCMParameterSpec|IvParameterSpec)\\(.*getBytes\\(\\)",
    "(iv|nonce)\\s*=\\s*b['\"].*['\"]         # 字节字面量 IV",
    "AES\\.new\\(.*iv\\s*=\\s*b['\"]           # 固定 IV 传入",
    "(iv|nonce)\\s*:=\\s*\\[\\]byte\\([\"']     # 字节切片转为固定字符串",
    "cipher\\.NewCBCEncrypter.*iv\\)        # 需检查 iv 来源",
    "gcm\\.Seal.*nonce                     # 需检查 nonce 来源",
    "Buffer\\.from\\(['\"]                   # 字符串转 Buffer 作 IV",
    "createCipheriv\\(.*iv\\)              # 需检查 iv 是否固定"
  ],
  "exclude_patterns": []
}
```
## 威胁定义 (Threat Definition)

CBC/GCM 等加密模式中 IV/Nonce 硬编码为固定值而非随机生成，破坏加密的语义安全性，使攻击者可通过观察密文模式推断明文信息。

## 检测逻辑 (Detection Logic)

### Step 1: 各语言固定 IV 模式

**C/C++:**
```c
// BAD: CBC 固定 IV
unsigned char iv[16] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                         0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10};
EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, key, iv);
// IV 为常量 — 每次加密使用相同 IV!

// BAD: GCM 固定 Nonce（更危险: 相同 Nonce+Key 可恢复认证密钥）
unsigned char nonce[12] = "FIXED_NONCE_";
EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, 12, NULL);
EVP_EncryptInit_ex(ctx, NULL, NULL, key, nonce);  // GCM 固定 nonce → 灾难!

// BAD: 零 IV
unsigned char iv[16] = {0};  // 全零 IV
```

**Java:**
```java
// BAD: 固定 IV
byte[] iv = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
             0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f};
IvParameterSpec ivSpec = new IvParameterSpec(iv);  // 硬编码 IV!
cipher.init(Cipher.ENCRYPT_MODE, key, ivSpec);

// BAD: GCM 固定 Nonce
GCMParameterSpec spec = new GCMParameterSpec(128, "fixed_nonce".getBytes());
cipher.init(Cipher.ENCRYPT_MODE, key, spec);
```

**Python:**
```python
# BAD: pycryptodome 固定 IV
from Crypto.Cipher import AES
iv = b'0123456789abcdef'  # 硬编码 IV!
cipher = AES.new(key, AES.MODE_CBC, iv=iv)

# BAD: GCM 固定 Nonce
cipher = AES.new(key, AES.MODE_GCM, nonce=b'fixed_nonce12')
```

**Go:**
```go
// BAD: CBC 固定 IV
iv := []byte("0123456789abcdef")  // 硬编码
block, _ := aes.NewCipher(key)
mode := cipher.NewCBCEncrypter(block, iv)

// BAD: GCM 固定 Nonce（极度危险）
nonce := make([]byte, 12)
copy(nonce, "FIXED_NONCE_")  // 硬编码 Nonce!
gcm, _ := cipher.NewGCM(block)
gcm.Seal(nil, nonce, plain, nil)
```

**JavaScript:**
```javascript
// BAD: Node.js 固定 IV
const iv = Buffer.from('0123456789abcdef');  // 硬编码
const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);

// BAD: GCM 固定 Nonce
const nonce = Buffer.from('fixed_nonce_12');  // 硬编码
const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce);
```

### Step 2: 识别 IV 来源

检测 IV 变量是否：
- 初始化为字面量/常量
- 从固定字符串派生
- 未调用 CSPRNG 生成

**安全模式（所有语言通用）:**
- CBC: 每次加密随机生成 IV（随机且不可预测）
- GCM: 每次加密使用唯一 Nonce（可以是计数器，但绝不能重复）
- CTR: 每次加密使用唯一 Nonce（计数器 + Nonce 组合）

## 修复指引 (Remediation Guide)

1. **CBC 模式**：每次加密使用 `getrandom()`/`SecureRandom`/`secrets.token_bytes()` 生成随机 IV
2. **GCM 模式**：每次加密使用唯一 Nonce（推荐 96-bit 随机，或确定性计数器 + 状态保护）
3. **CTR 模式**：Nonce + 计数器组合必须每次加密唯一
4. **禁止**：固定字符串、全零 IV、从密钥派生的 IV

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| IV 来自 `SecureRandom`/`getrandom`/`/dev/urandom` | 随机生成 | 确认 IV 变量由 CSPRNG API 赋值，非硬编码字节数组或字符串 |
| GCM Nonce 为确定性计数器（每消息递增且有状态保护） | 正确使用计数器 | 确认计数器有持久化状态且每次递增，无重复风险 |
| ECB 模式（无 IV） | 但 ECB 本身应被 crypto-aes-ecb-mode 检测 | 确认加密模式为 ECB（无 IV 参数），同时交叉验证 ECB 检测器已触发 |
| 测试/演示代码 | 非生产 | 确认文件路径匹配 test/demo/example 模式 |
| IV 来自 TLS 协议内部生成 | 协议层管理 | 确认调用的是 TLS 库的内部加密（SSL_write/SSL_read），非应用层直接设置 IV |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# C/C++: 固定 IV 数组
unsigned char\s+(iv|nonce)\[.*\]\s*=\s*\{.*0x  # 硬编码字节数组
const.*(iv|nonce).*=.*".*"                       # 固定字符串 IV
→ MUST: code_context (IV 声明及初始化代码)
→ MUST: judgment_rationale (IV 来源分析 — 字面量 vs 随机生成)

# Java: 硬编码 IV 字节
byte\[\]\s+(iv|nonce)\s*=\s*\{\s*(0x[0-9a-fA-F]{2}|[0-9]+)
new\s+IvParameterSpec\([^)]*\{(?!.*SecureRandom)  # 字节字面量

# Java: 固定字符串 IV
(GCMParameterSpec|IvParameterSpec)\(.*".*"\.getBytes\(\)
(GCMParameterSpec|IvParameterSpec)\(.*getBytes\(\)
→ MUST: code_context (IV 初始化代码 + Cipher.init 调用)

# Python: 固定 IV
(iv|nonce)\s*=\s*b['"].*['"]         # 字节字面量 IV
AES\.new\(.*iv\s*=\s*b['"]           # 固定 IV 传入

# Go: 固定 IV
(iv|nonce)\s*:=\s*\[\]byte\(["']     # 字节切片转为固定字符串
cipher\.NewCBCEncrypter.*iv\)        # 需检查 iv 来源
gcm\.Seal.*nonce                     # 需检查 nonce 来源

# JS/Node: 固定 IV
Buffer\.from\(['"]                   # 字符串转 Buffer 作 IV
createCipheriv\(.*iv\)              # 需检查 iv 是否固定

# === EXCLUDE (不报告) ===

→ (SecureRandom|getrandom|/dev/urandom|secrets\.token_bytes|crypto\.randomBytes)  # CSPRNG 生成
→ ECB 模式（无 IV 参数）                                                           # 由 ECB 检测器覆盖
→ SSL_write|SSL_read|TLS_internal                                                   # TLS 协议层管理
→ *test*/|*demo*/|*example*/                                                        # 测试/演示代码路径
```
