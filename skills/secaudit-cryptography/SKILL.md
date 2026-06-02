---
name: secaudit-cryptography
description: 审计密码学实现的安全性，检测弱算法、错误使用模式、密钥管理缺陷和随机数安全问题。当用户请求密码学审计、加密算法检测、密钥管理审查、随机数安全、弱加密检测时使用。
category: domain
topic: [crypto]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 密码学安全审计

## 审计概览

密码学错误通常是最隐蔽的安全漏洞——代码能正常运行，但保护形同虚设。本次审计覆盖四个方面：

> **参考**: 详细算法安全速查表（对称/非对称/哈希/KDF）、常见误用模式见 [`../../knowledge/cheatsheets/crypto-algorithms.md`](../../knowledge/cheatsheets/crypto-algorithms.md)。
- **算法选择**：用了什么算法，是否已被破解
- **使用模式**：算法用对了吗（模式、填充、IV）
- **随机数安全**：密钥、Token、盐值是否真正随机
- **密钥管理**：密钥如何存储、轮换、销毁

## 审计流程

### Phase 1: 资产识别

搜索代码中所有密码学相关调用：

```
□ 哈希函数 (MessageDigest, hashlib, crypto/sha256, OpenSSL)
□ 对称加密 (Cipher, AES, DES, ChaCha20)
□ 非对称加密 (RSA, ECDSA, Ed25519)
□ 随机数生成 (Random, SecureRandom, random, secrets, crypto/rand, /dev/urandom)
□ 密码哈希 (bcrypt, scrypt, argon2, PBKDF2)
□ 证书/TLS 配置 (SSLContext, tls.Config, ssl)
□ 签名/验证 (Signature, JWT sign, HMAC)
□ 自定义加密实现 (任何 XOR、位移、自创算法)
```

**关键问题**：找出所有自称为"加密"或"哈希"的代码，即使它不是调标准库。自定义加密是几乎一定有漏洞的。

### Phase 2: 检查清单

#### 2.1 哈希安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 密码存储是否使用专用算法 | 确认使用 bcrypt/scrypt/argon2/PBKDF2，不是 SHA/MD5 |
| [C] | 禁止 MD5/SHA-1 用于安全目的 | grep `MD5\|SHA-1\|sha1\|md5`，排除非安全用途 |
| [H] | 密码哈希 cost factor 是否足够 | bcrypt ≥ 10, PBKDF2 ≥ 310000, argon2 ≥ 2 |
| [H] | 是否使用固定盐值 | 检查哈希函数调用中盐值生成逻辑 |
| [M] | 哈希长度扩展攻击防护 | 检查 HMAC 是否正确使用（key 先于 message） |

#### 2.2 对称加密

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 禁止使用 ECB 模式 | grep `ECB\|Cipher/ECB\|getInstance.*ECB` |
| [C] | 禁止使用 DES/3DES/RC4/Blowfish | grep `DES\|RC4\|Blowfish` |
| [H] | 是否使用认证加密 (AEAD) | 检查是否使用 GCM/CCM/ChaCha20-Poly1305 |
| [H] | IV/Nonce 是否唯一且随机 | AES-GCM：nonce 是否重用（致命错误） |
| [H] | 加密前是否有认证 (Encrypt-then-MAC) | 非 AEAD 模式是否手动添加 MAC |
| [M] | 密钥长度是否达到安全标准 | AES ≥ 128, 优先 256 |

#### 2.3 非对称加密

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | RSA 密钥长度是否 ≥ 2048 bit | 检查 KeyPairGenerator.initialize(size) |
| [H] | ECC 曲线是否安全 | 禁止废弃曲线，推荐 secp256r1/Curve25519 |
| [H] | 禁止使用 RSA PKCS#1 v1.5 填充 | 检查 Cipher 的 transformation 字符串 |
| [M] | 签名算法是否安全 | ECDSA 比 RSA 签名优先 |

#### 2.4 随机数安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 安全场景禁止使用非安全随机数 | grep `Math.random\|rand()\|random.random\|math/rand` |
| [H] | SecureRandom 是否使用强种子 | 检查 SecureRandom 构造方式，禁止固定种子 |
| [H] | 随机种子是否可预测 | 禁止使用时间戳、PID、MAC 地址作为种子 |

#### 2.5 密钥管理

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 密钥是否硬编码 | grep 高熵 base64/hex 字符串 + 变量名匹配 |
| [C] | 密钥是否与代码一同提交 | 检查 .gitignore + `git log -p` 历史 |
| [H] | 是否使用密钥管理服务 | 检查是否引用 KMS/HSM/Vault |
| [H] | 密钥是否有轮换机制 | 检查是否有 key rotation 逻辑 |

### Phase 3: 常见漏洞模式

#### 模式 1: ECB 模式泄露数据模式

```java
// BAD: ECB 模式——相同明文产生相同密文，数据模式可见
Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding");

// GOOD: GCM 认证加密
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
GCMParameterSpec spec = new GCMParameterSpec(128, iv);
cipher.init(Cipher.ENCRYPT_MODE, key, spec);
```

#### 模式 2: GCM Nonce 重用（致命）

```python
# BAD: 固定 nonce → 认证密钥可被恢复
nonce = b'\x00' * 12
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)

# GOOD: 每次加密生成随机 nonce
nonce = os.urandom(12)
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
```

#### 模式 3: 非安全随机数用于密钥

```go
// BAD: math/rand 可被预测
import "math/rand"
token := fmt.Sprintf("%d", rand.Int63())

// GOOD: crypto/rand 加密安全
import "crypto/rand"
b := make([]byte, 32)
rand.Read(b)
```

#### 模式 4: 缺少认证的加密

```python
# BAD: AES-CTR 无 MAC → 密文可被 bit-flipping 篡改
cipher = AES.new(key, AES.MODE_CTR, counter=ctr)
encrypted = cipher.encrypt(plaintext)

# GOOD: GCM 内置认证
cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
encrypted, tag = cipher.encrypt_and_digest(plaintext)
```

#### 模式 5: 自定义加密

```c
// BAD: 任何自定义算法都是高危
void encrypt(char *data, int len) {
    for (int i = 0; i < len; i++) {
        data[i] ^= 0x55;  // 简单 XOR 不是加密
    }
}

// GOOD: 使用标准库
EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), NULL, key, iv);
```

### Phase 4: 语言特定的检查重点

| 语言 | 重点检查 |
|------|---------|
| Java | `Cipher.getInstance(transformation)` 参数、`MessageDigest` 算法名、`SecureRandom` 种子 |
| Python | `hashlib` 算法、`cryptography` vs `pycrypto`、`secrets` vs `random` |
| Go | `crypto/*` vs `math/rand`、`crypto/aes` 模式、`crypto/hmac` 使用 |
| C/C++ | OpenSSL EVP vs 低级 API、`memset` 清零、自定义算法 |
