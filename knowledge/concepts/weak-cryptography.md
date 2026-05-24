---
category: concept
threat_type: weak_crypto
severity: high
cwe: CWE-327
owasp: A02:2021 - Cryptographic Failures
---

# 弱加密算法 (Weak Cryptography)

使用已被证明不安全或过时的加密算法、哈希函数、随机数生成器。

## 检测策略

### 核心原则
**禁止已知弱算法，使用业界标准的安全算法。**

1. **弱哈希函数**
   - MD2/MD4/MD5/SHA-0/SHA-1 用于安全目的
   - 非加密哈希（CRC32）用于安全场景

2. **弱加密算法**
   - DES/3DES、RC2/RC4、Blowfish
   - ECB 模式（电子密码本）
   - 无认证的加密（缺少 MAC/GCM）

3. **不安全的随机数**
   - `Math.random()`、`rand()` 用于安全目的
   - 可预测的种子（时间戳作为种子）

4. **弱密钥派生**
   - 单次 SHA/MD5 直接作为密钥
   - 低迭代次数的 PBKDF2
   - 使用非密码学哈希做密码哈希

### 误报排除
- 用于非安全目的（校验和、数据去重）
- 与安全硬件（HSM、TEE）配合使用
- 遗留系统兼容（需标注迁移计划）

## 修复指引

| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | MD5, SHA-1 | SHA-256/384/512 |
| 对称加密 | DES, RC4, ECB | AES-256-GCM, ChaCha20-Poly1305 |
| 密码存储 | SHA, MD5 | bcrypt, scrypt, Argon2 |
| 随机数 | Math.random | SecureRandom / secrets模块 |
