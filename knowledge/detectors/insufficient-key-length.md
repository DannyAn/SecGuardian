---
detector: insufficient-key-length
severity: medium
cwe: CWE-326
language: [c, cpp]
tags: [crypto, key-size, configuration]
---

# 不足的密钥长度 (Insufficient Key Length)

## 检测概要

检查加密操作中使用的密钥长度是否达到当前安全标准。

## 检测逻辑

### Step 1: 搜索密钥生成

| 算法 | 最低安全位 | 危险值 |
|------|----------|--------|
| RSA | 2048 | < 2048 位 (如 1024, 512) |
| DH | 2048 | < 2048 位 |
| DSA | 2048 | < 2048 位 |
| ECDSA/ECDH | 256 (P-256) | < 256 位曲线 |
| AES | 128 | 未达标 |
| HMAC | 256 | < 128 位 |

### Step 2: 危险代码模式

```c
// BAD: RSA 1024 位
RSA_generate_key_ex(rsa, 1024, e, NULL);

// BAD: DH 1024 位
DH_generate_parameters_ex(dh, 1024, DH_GENERATOR_2, NULL);

// BAD: EC 弱曲线
EC_KEY_new_by_curve_name(NID_secp192r1);  // 192 位曲线
EC_KEY_new_by_curve_name(NID_X9_62_prime192v1);

// BAD: AES-128 在某些场景不足
// (虽然 AES-128 仍被 NIST 认可，敏感数据应使用 AES-256)
```

### Step 3: 密钥派生参数

```c
// BAD: PBKDF2 迭代次数不足
PKCS5_PBKDF2_HMAC(password, len, salt, salt_len, 1000, ...);

// GOOD: 至少 100,000 次 (推荐)
PKCS5_PBKDF2_HMAC(password, len, salt, salt_len, 100000, ...);

// BAD: bcrypt cost 过低
char salt[BCRYPT_HASHSIZE];
bcrypt_gensalt(5, salt);         // cost=5 太低
// 推荐 cost >= 12
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 非对称算法 3072+ / 曲线 384+ | 已超标 |
| 内部测试/非生产代码 | 无安全影响 |
| 与外部系统兼容的协议限定 | 有文档记录 |

## 检测模式汇总

```
# RSA/DH 短密钥
RSA_generate_key.*1024|RSA_generate_key.*512
DH_generate_parameters.*1024|DH_generate_parameters.*512

# 弱 EC 曲线
NID_secp192|NID_X9_62_prime192|NID_secp160|NID_sect163

# 低迭代 PBKDF2
PKCS5_PBKDF2_HMAC.*[0-9]{1,3}\)  # < 10000 次迭代
```