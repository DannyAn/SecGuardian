---
detector: crypto-password-storage
severity: critical
cwe: CWE-916
language: [java, python, go, js]
tags: [crypto, password, hashing, storage]
---

# 密码存储不安全 (Insecure Password Storage)

## 威胁定义

检测密码存储是否使用了弱哈希（MD5/SHA-1/SHA-256 单次）、可逆加密或明文存储，必须使用 bcrypt/scrypt/Argon2 等专用密码哈希。

## 检测逻辑

### Step 1: Java — 弱密码哈希

```java
// BAD: MD5 存储密码
MessageDigest md = MessageDigest.getInstance("MD5");
byte[] hash = md.digest(password.getBytes());

// BAD: SHA-1 存储密码
MessageDigest.getInstance("SHA-1");

// BAD: SHA-256 单次（无盐/无迭代）
MessageDigest.getInstance("SHA-256");
// 快速哈希可被 GPU 暴力破解

// BAD: 自定义哈希组合
String hash = sha256(md5(password));  // 组合弱算法更弱!

// BAD: 明文比较
if (password.equals(storedPassword)) { ... }

// BAD: 可逆加密存储密码
Cipher cipher = Cipher.getInstance("AES");
byte[] encrypted = cipher.doFinal(password.getBytes());  // 密钥泄露则全泄露
```

**Java 安全模式:**
```java
// GOOD: BCrypt
String hash = BCrypt.hashpw(password, BCrypt.gensalt(12));
if (BCrypt.checkpw(password, hash)) { ... }

// GOOD: Argon2
Argon2 argon2 = Argon2Factory.create();
String hash = argon2.hash(10, 65536, 1, password.toCharArray());
```

### Step 2: Python — 弱密码哈希

```python
# BAD: MD5/SHA-1/SHA-256 存储密码
import hashlib
hashlib.md5(password.encode()).hexdigest()
hashlib.sha1(password.encode()).hexdigest()
hashlib.sha256(password.encode()).hexdigest()  # 单次无盐

# BAD: 自创加盐
salt = "my_fixed_salt"
hash = hashlib.sha256((salt + password).encode()).hexdigest()  # 固定盐!

# BAD: Django 默认不够安全
# settings.py: PASSWORD_HASHERS 使用 SHA256PasswordHasher (非 Argon2)
```

**Python 安全模式:**
```python
# GOOD: bcrypt
import bcrypt
hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))

# GOOD: Django Argon2
# settings.py
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',
]
```

### Step 3: Go — 弱密码哈希

```go
// BAD: SHA-256 单次
hash := sha256.Sum256([]byte(password))

// BAD: MD5
hash := md5.Sum([]byte(password))

// BAD: 手动 HMAC
mac := hmac.New(sha256.New, []byte("fixed_key"))
mac.Write([]byte(password))
hash := mac.Sum(nil)

// BAD: 直接比较
if password == storedPassword { ... }
```

**Go 安全模式:**
```go
// GOOD: bcrypt
hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
bcrypt.CompareHashAndPassword(hash, []byte(password))
```

### Step 4: JavaScript — 弱密码哈希

```javascript
// BAD: SHA-256 单次
const crypto = require('crypto');
const hash = crypto.createHash('sha256').update(password).digest('hex');

// BAD: MD5
crypto.createHash('md5').update(password).digest('hex');

// BAD: 直接比较
if (password === storedPassword) { ... }

// BAD: 自创迭代
let hash = password;
for (let i = 0; i < 1000; i++) {
    hash = crypto.createHash('sha256').update(hash).digest('hex');
}
```

**JavaScript 安全模式:**
```javascript
// GOOD: bcrypt
const bcrypt = require('bcrypt');
const hash = await bcrypt.hash(password, 12);
const match = await bcrypt.compare(password, hash);
```

## 修复指引

1. **首选**：Argon2id（OWASP 推荐，抗 GPU/ASIC/侧信道）
2. **次选**：bcrypt（cost ≥ 12）/ scrypt
3. **可接受**：PBKDF2-HMAC-SHA256（迭代 ≥ 100,000）
4. **禁止**：MD5/SHA-1/SHA-256 单次、可逆加密、明文存储

## 误报排除

| 场景 | 原因 |
|------|------|
| 文件完整性校验（MD5/SHA-1 checksum） | 非密码存储 |
| 数据去重/分片标识 | 非安全用途 |
| HMAC-SHA256 认证（非存储） | 消息认证用途 |
| 测试代码/Mock 数据 | 非生产 |
| OAuth/SSO token（由第三方生成） | 非本系统生成 |

## 检测模式汇总

```
# Java
MessageDigest\.getInstance\("MD5"|"SHA-1"|"SHA-256"\)
→ 上下文含: password|pass|pwd|credential

# Python
hashlib\.(md5|sha1|sha256)\(.*password|pwd|passwd|secret
hashlib\.(md5|sha1|sha256)\(.*encode\(\)\).*hexdigest\(\)
→ 上下文含: User|Account|Login|Auth|Password

# Go
(md5\.Sum|sha256\.Sum256)\(\[\]byte\(password
→ 上下文含: password|store|database|user

# JS/Node
crypto\.createHash\(.(md5|sha1|sha256).\).*password
→ 上下文含: password|user|auth|login|signup
```
