---
name: secguard-js-weak_crypto
description: "Detects use of broken or deprecated cryptographic algorithms and insecure random number generators"
language: javascript
topic: [crypto, algorithm, weak]
skill_id: js.weak_crypto
signal_filter: js.weak_crypto*
signal_source: call_sites[category="crypto"]
severity: high
cwe: [CWE-327]
trigger_functions: [crypto.createHash('md5'), crypto.createHash('sha1'), crypto.createCipher('aes-128-ecb'), Math.random, crypto.randomBytes, crypto.pbkdf2]
---

# weak_crypto 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.weak_crypto` |
| signal_source | `call_sites[cat="crypto"]` |
| trigger_functions | `crypto.createHash('md5')`, `crypto.createCipher('aes-128-ecb')`, `Math.random()` 安全用途 |
| severity | High |
| CWE | CWE-327 |

## Scenario 1: 弱哈希 / 弱加密 / 不安全随机数

### 威胁定义

使用 MD5/SHA-1 作安全哈希、AES-ECB 模式加密、或 `Math.random()` 作为安全随机数。攻击者可利用碰撞攻击、模式泄露或可预测性绕过安全机制。

### 检测逻辑

```javascript
// BAD: 弱哈希
const hash = crypto.createHash('md5').update(password).digest('hex');  // MD5 不安全
const hash = crypto.createHash('sha1').update(token).digest('hex');    // SHA-1 不安全

// BAD: 弱加密
const cipher = crypto.createCipher('aes-128-ecb', key);  // ECB 模式不安全

// BAD: Math.random() 安全用途
const token = Math.random().toString(36);  // 可预测! 应使用 crypto.randomBytes

// GOOD: 安全方案
crypto.createHash('sha256').update(data).digest('hex');
crypto.createCipheriv('aes-256-gcm', key, iv);
crypto.randomBytes(32).toString('hex');
```

### 检测模式

```
# MATCH
createHash\(['"]md5|createHash\(['"]sha1
createCipher\(|createCipheriv.*ecb|aes-128-ecb
Math\.random\(\)(?!.*nonce|uuid|guid)  # 安全上下文中
CryptoJS\.MD5|CryptoJS\.SHA1

# EXCLUDE
checksum|dedup|fingerprint|cache.*key   # 非安全用途
// test|/* test|@Test                   # 测试代码
Math\.random\(\)(.*nonce|.*uuid|.*guid) # 非安全场景
SecureRandom|secrets\.|crypto\.randomBytes
```

### 修复指引

| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | MD5, SHA-1 | SHA-256/384/512 |
| 加密 | AES-ECB, DES | AES-256-GCM |
| 随机数 | Math.random() | crypto.randomBytes() |

## 证据收集指引

- **code_context**: 弱算法调用的完整代码行，含算法名称和上下文用途
- **judgment_rationale**: 算法已知缺陷在该场景下的实际风险

## 输出格式

三段式: Source（待哈希/加密的数据）→ Propagate（算法选择）→ Sink（弱算法导致安全风险降低）。
