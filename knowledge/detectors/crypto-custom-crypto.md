---
detector: crypto-custom-crypto
severity: critical
cwe: CWE-327
language: [c, cpp, java, python, go, js]
tags: [crypto, custom, algorithm, implementation]
---

# 自定义加密算法 (Custom Crypto Implementation)

## 威胁定义

检测代码中是否实现了自定义加密/哈希算法或使用 XOR/位运算进行数据"加密"。自定义加密极易产生致命缺陷，应严格禁止。

## 检测逻辑

### Step 1: 自定义密码学原语

```c
// BAD: XOR "加密"
for (int i = 0; i < len; i++) {
    data[i] ^= key[i % key_len];  // XOR — 非加密!
}

// BAD: 自定义哈希
unsigned int my_hash(const char *s) {
    unsigned int h = 0;
    while (*s) h = h * 31 + *s++;  // 自创哈希 — 非密码学哈希!
    return h;
}

// BAD: 自定义 PRNG
int my_rand() {
    static int seed = 12345;
    seed = seed * 1103515245 + 12345;  // LCG — 非安全随机!
    return seed;
}
```

### Step 2: 各语言自创加密模式

```java
// BAD: Java 自定义加密
public static String encrypt(String data) {
    StringBuilder sb = new StringBuilder();
    for (char c : data.toCharArray()) {
        sb.append((char)(c ^ 0x55));  // XOR!
    }
    return sb.toString();
}

// BAD: 自定义 Base64 (非标准加密用途)
public static String myEncode(byte[] data) { ... }
```

```python
# BAD: Python 自定义加密
def encrypt(data, key):
    return ''.join(chr(ord(c) ^ key) for c in data)  # XOR!

# BAD: 自定义密码存储
def hash_password(pw):
    import hashlib
    return hashlib.md5(pw[::-1].encode()).hexdigest()  # 自创加盐!
```

```go
// BAD: Go 自定义加密
func Encrypt(data []byte, key byte) []byte {
    result := make([]byte, len(data))
    for i, b := range data {
        result[i] = b ^ key  // XOR!
    }
    return result
}
```

```javascript
// BAD: JS 自定义加密
function encrypt(data, key) {
    return data.split('').map(c => 
        String.fromCharCode(c.charCodeAt(0) ^ key)
    ).join('');  // XOR!
}

// BAD: 自定义 base64 API key 编码
function encodeApiKey(key) { /* 自创编码 */ }
```

### Step 3: 自创密钥派生

```c
// BAD: 自创 KDF
void derive_key(const char *password, unsigned char *key) {
    unsigned int h = 0;
    for (int i = 0; password[i]; i++) {
        h = h * 31 + password[i];  // 简单乘法哈希做 KDF
    }
    memcpy(key, &h, sizeof(h));
}
```

```java
// BAD: 自创密钥派生
byte[] key = password.getBytes();
for (int i = 0; i < 1000; i++) {
    key = MessageDigest.getInstance("MD5").digest(key);  // MD5 迭代做 KDF!
}
```

## 修复指引

1. **禁止**：任何形式的自定义加密/XOR/自创哈希用于安全场景
2. **使用标准库**：AES-256-GCM（加密）、SHA-256（哈希）、HMAC-SHA256（认证）
3. **密码存储**：Argon2id > bcrypt > scrypt > PBKDF2
4. **密钥管理**：使用 KMS/Vault/HSM，绝不自行设计

## 误报排除

| 场景 | 原因 |
|------|------|
| 校验和/CRC（明确为非安全用途） | 有注释说明非安全 |
| 数据去重使用的非密码学哈希 | 公开数据去重 |
| 标准库的加解密（AES/RSA/SHA-256） | 标准密码学实现 |
| 教学/演示代码 | 非生产 |
| 公开的挑战/响应算法（CTF） | CTF 场景 |

## 检测模式汇总

```
# XOR "加密" (不在模运算/校验和场景)
\bxor\b.*encrypt|crypt|secret|key|password
\bencrypt.*\bxor\b|crypt|cipher

# 自定义循环位运算加密 (非标准算法)
for.*\bxor\b.*key|for.*\brotate\b.*key
^\s*[a-zA-Z_]+\s*=\s*[a-zA-Z_]*\s*\^\s*key  # var ^= key

# 自创哈希/签名函数命名
my_hash|custom_hash|simple_hash|fast_hash|my_sign

# Java 自创加密方法
String\s+\w*[Ee]ncrypt|byte\[\]\s+\w*[Ee]ncrypt.*\bxor\b|\bfor.*\^\s*

# Python 自创加密
def\s+encrypt.*\bxor\b|def\s+hash_password.*\.md5\(|lambda.*xor

# Go 自创加密
func\s+\w*[Ee]ncrypt.*\bxor\b|func\s+\w*[Hh]ash.*key

# JS 自创加密
function\s+encrypt.*\bxor\b|String\.fromCharCode.*xor|\.charCodeAt.*\^
```
