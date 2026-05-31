---
detector: weak-crypto-algorithm
severity: high
cwe: CWE-327
language: [c, cpp, java, python, go, js]
tags: [crypto, algorithm, deprecated]
---

# 弱加密算法 (Weak Crypto Algorithm)

## 威胁定义

使用已被证明不安全或过时的加密算法、哈希函数、随机数生成器。按用途分类：弱哈希（MD2/MD4/MD5/SHA-1）、弱加密（DES/3DES/RC2/RC4/Blowfish/ECB 模式）、不安全随机数（rand()/Math.random() 用于安全用途）、弱密钥派生（单次 SHA/MD5 作密钥）。

**核心原则：禁止已知弱算法，使用业界标准的安全算法。**

## 检测逻辑

### Step 1: 搜索弱哈希函数

```c
// BAD: 弱哈希
MD5_Init(&ctx);
SHA1(...);
// 对于密码存储，即使是 SHA-256 也不够（需要 PBKDF2/bcrypt/Argon2）
```

### Step 2: 搜索弱加密算法

```c
// BAD: 弱加密
DES_cblock key;
DES_set_key(&key, &schedule);
RC4_set_key(&key, len, data);
EVP_bf_cbc();                    // Blowfish 已过时

// BAD: 弱模式
EVP_aes_128_ecb();               // ECB 模式不安全
```

### Step 3: 搜索弱密钥交换

```c
// BAD: 弱 DH 参数
DH *dh = DH_new();
DH_generate_parameters_ex(dh, 512, ...);  // 512 位太短
```

## 废弃算法清单

| 算法 | 状态 | 替代方案 |
|------|------|---------|
| MD2, MD4, MD5 | 完全破解 | SHA-256/384/512 |
| SHA-1 | 碰撞攻击可行 | SHA-256+ |
| RC2, RC4 | 已破解 | AES-GCM / ChaCha20 |
| DES, 3DES | 密钥过短 | AES-128+ |
| ECB 模式 | 模式不安全 | CBC/GCM/CTR |
| RSA PKCS#1 v1.5 | 填充攻击 | OAEP |
| DH < 2048 位 | 不够安全 | DH 2048+ / ECDH |
| DSA < 2048 位 | 不够安全 | ECDSA / EdDSA |

## 修复指引

| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | MD5, SHA-1 | SHA-256/384/512 |
| 对称加密 | DES, RC4, AES-ECB | AES-256-GCM, ChaCha20-Poly1305 |
| 密码存储 | SHA, MD5 单次 | bcrypt, scrypt, Argon2id |
| 随机数 | rand(), Math.random() | getrandom(), SecureRandom, secrets.token_bytes() |

## 误报排除

| 场景 | 原因 |
|------|------|
| 非安全用途（校验和） | MD5 作为 checksum 可接受 |
| 遗留系统互操作 | 有明确文档说明 |
| 测试向量中的已知值 | 非生产数据 |

## 检测模式汇总

```
# 弱哈希 API
MD5_|EVP_md5|SHA1_|EVP_sha1

# 弱加密 API
DES_|EVP_des|RC4_|EVP_rc4|EVP_bf_

# 弱模式
EVP_.*_ecb

# 弱 DH 参数
DH_generate_parameters.*512|DH_generate_parameters.*1024
```