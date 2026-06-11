---
confidence: dynamic
cwe: CWE-327
detector: crypto-aes-ecb-mode
language: [c, cpp, java, python, go, js]
precision: very-high
severity: high
tags: [crypto, aes, ecb, mode]
---

# AES ECB 模式使用 (AES ECB Mode Usage)

## 威胁定义 (Threat Definition)

AES-ECB 模式不提供语义安全——相同明文块产生相同密文块，导致数据模式可被观察。禁止用于任何安全敏感场景。

## 检测逻辑 (Detection Logic)

### Step 1: Java — ECB 模式检测

```java
// BAD: 显式 ECB 模式
Cipher.getInstance("AES/ECB/PKCS5Padding");
Cipher.getInstance("AES/ECB/NoPadding");
Cipher.getInstance("DES/ECB/PKCS5Padding");
Cipher.getInstance("Blowfish/ECB");

// BAD: 默认 ECB（未指定模式）
Cipher.getInstance("AES");          // Java 默认 ECB!
Cipher.getInstance("DES");
Cipher.getInstance("Blowfish");

// BAD: 无反馈模式
Cipher.getInstance("AES/CBC/NoPadding");  // CBC 无填充: Padding Oracle
```

**Java 安全模式:**
```java
// GOOD: GCM 认证加密模式
Cipher.getInstance("AES/GCM/NoPadding");
GCMParameterSpec spec = new GCMParameterSpec(128, iv);
cipher.init(Cipher.ENCRYPT_MODE, key, spec);
```

### Step 2: C/C++ — ECB 模式检测

```c
// BAD: OpenSSL ECB 模式
EVP_aes_128_ecb();
EVP_aes_256_ecb();
EVP_EncryptInit_ex(ctx, EVP_aes_256_ecb(), NULL, key, NULL);

// BAD: 手动 ECB 循环
for (int i = 0; i < blocks; i++) {
    AES_encrypt(plain + i * 16, cipher + i * 16, &key);  // ECB!
}

// BAD: mbedTLS ECB
mbedtls_aes_crypt_ecb(&ctx, MBEDTLS_AES_ENCRYPT, input, output);
```

**C/C++ 安全模式:**
```c
// GOOD: GCM 模式
EVP_aes_256_gcm();
EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, NULL, NULL);
EVP_EncryptUpdate(ctx, cipher, &len, plain, plain_len);
EVP_EncryptFinal_ex(ctx, cipher + len, &final_len);
EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, tag);
```

### Step 3: Python — ECB 模式检测

```python
# BAD: pycryptodome ECB
from Crypto.Cipher import AES
AES.new(key, AES.MODE_ECB)

# BAD: cryptography 库 ECB
from cryptography.hazmat.primitives.ciphers.modes import ECB
ECB()

# BAD: pyaes ECB
import pyaes
pyaes.AESModeOfOperationECB(key)
```

**Python 安全模式:**
```python
# GOOD: GCM 模式
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
```

### Step 4: Go — ECB 模式检测

```go
// BAD: 自定义 ECB 加密
import "crypto/des"
block, _ := des.NewCipher(key)
// 循环逐块加密 — ECB 模式

// BAD: 第三方 ECB 库
import "github.com/xxx/aes-ecb"
```

### Step 5: JavaScript — ECB 模式检测

```javascript
// BAD: Node.js crypto 默认可能为 ECB
const cipher = crypto.createCipheriv('aes-128-ecb', key, null);

// BAD: CryptoJS ECB
CryptoJS.AES.encrypt(data, key, { mode: CryptoJS.mode.ECB });
```

## 修复指引 (Remediation Guide)

1. **首选**：AES-256-GCM（认证加密，提供机密性+完整性+认证）
2. **次选**：AES-CBC + HMAC-SHA256（Encrypt-then-MAC）
3. **禁止**：任何 ECB 模式的新代码，遗留系统需制定迁移计划

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 数据库加密（RDS/MySQL AES_ECB）兼容遗留系统 | 有文档记录的兼容性需求 | 确认有明确的遗留系统迁移文档或 issue 跟踪 |
| AES-GCM / AES-CCM 模式 | 认证加密，安全 | 确认算法字符串包含 GCM 或 CCM 模式标识 |
| AES-CBC + HMAC（Encrypt-then-MAC） | 有认证保护 | 确认 HMAC 验证在解密之前执行，且密钥独立 |
| 仅用于教学/演示代码 | 非生产环境 | 确认文件路径匹配 tutorial/demo/example 模式 |
| 仅加密非敏感数据（公开的 Nonce/索引） | 无安全需求 | 确认注释或文档说明数据为非敏感且无需机密性保证 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java
Cipher\.getInstance\(.*ECB|Cipher\.getInstance\("AES"\)|Cipher\.getInstance\("DES"\)
→ MUST: code_context (Cipher.getInstance 调用及周边密码学代码)
→ MUST: judgment_rationale (确认 ECB 模式 vs 安全模式，评估数据敏感度)

# C/C++
EVP_aes_128_ecb|EVP_aes_256_ecb|mbedtls_aes_crypt_ecb
AES_encrypt.*AES_encrypt   → 循环中的逐块原始加密 (手动 ECB)
→ MUST: code_context (加密函数调用及循环上下文)

# Python
AES\.MODE_ECB|pyaes\.AESModeOfOperationECB
cryptography.*modes\.ECB\(\)

# Go
crypto/des.*NewCipher.*\n.*Encrypt → 逐块加密 (手动 ECB)

# JS
aes-128-ecb|aes-256-ecb|CryptoJS\.mode\.ECB

# === EXCLUDE (不报告) ===

→ AES/GCM|AES/CCM|AES/CBC.*HMAC                                  # 安全密码学模式
→ AES_256_GCM|EVP_aes_256_gcm|AES\.MODE_GCM                    # GCM 认证加密
→ *tutorial*/|*demo*/|*example*/|*test*/                          # 教学/测试代码路径
→ #define\s+AES_ECB_COMPAT|LEGACY_ECB                             # 遗留系统兼容宏
```
