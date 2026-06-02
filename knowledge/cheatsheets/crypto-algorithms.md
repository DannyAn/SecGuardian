# 密码学算法安全速查

## 对称加密算法

| 算法 | 密钥长度 | 状态 | 替代方案 |
|------|---------|------|---------|
| DES | 56-bit | ❌ 禁用 | AES-256-GCM |
| 3DES | 112/168-bit | ❌ 逐步淘汰 | AES-256-GCM |
| RC4 | 变长 | ❌ 禁用 | ChaCha20-Poly1305 |
| AES-ECB | 128/192/256 | ❌ 禁用 | AES-GCM/CBC |
| AES-CBC | 128/192/256 | ⚠️ 需要 HMAC | AES-256-GCM |
| AES-GCM | 128/192/256 | ✅ 推荐 | — |
| ChaCha20-Poly1305 | 256 | ✅ 推荐 | — |
| Blowfish | 32-448 | ⚠️ 仅遗留系统 | AES-256-GCM |

## 非对称加密算法

| 算法 | 密钥长度 | 状态 | 替代方案 |
|------|---------|------|---------|
| RSA-1024 | 1024-bit | ❌ 禁用 | RSA-2048+ |
| RSA-2048 | 2048-bit | ✅ 可接受 | Ed25519 更优 |
| RSA-4096 | 4096-bit | ✅ 可接受 | Ed25519 更优 |
| ECDSA P-256 | 256-bit | ✅ 推荐 | — |
| ECDSA P-384 | 384-bit | ✅ 推荐 | — |
| Ed25519 | 256-bit | ✅ 最佳 | — |

## 哈希算法

| 算法 | 输出长度 | 状态 | 替代方案 |
|------|---------|------|---------|
| MD5 | 128-bit | ❌ 禁用 | SHA-256 |
| SHA-1 | 160-bit | ❌ 禁用 | SHA-256 |
| SHA-256 | 256-bit | ✅ 推荐 | — |
| SHA-384 | 384-bit | ✅ 推荐 | — |
| SHA-512 | 512-bit | ✅ 推荐 | — |
| SHA-3 | 变长 | ✅ 推荐 | — |
| BLAKE2b | 变长 | ✅ 推荐 | — |

## 密码哈希 (KDF)

| 算法 | 状态 | 推荐参数 |
|------|------|---------|
| bcrypt | ✅ 推荐 | cost ≥ 12 |
| scrypt | ✅ 推荐 | N=32768, r=8, p=1 |
| Argon2id | ✅ 最佳 | m=65536, t=3, p=4 |
| PBKDF2-SHA256 | ⚠️ 可接受 | iterations ≥ 600000 |
| PBKDF2-SHA1 | ❌ 禁用 | 升级到 SHA-256+ |

## 随机数生成

| API | 语言 | 状态 | 正确 API |
|-----|------|------|---------|
| `rand()` | C | ❌ | `getrandom()` / `/dev/urandom` |
| `random()` | Python | ❌ | `secrets.randbelow()` / `os.urandom()` |
| `Math.random()` | Java/JS | ❌ | `SecureRandom` / `crypto.randomBytes()` |
| `math/rand` | Go | ❌ | `crypto/rand` |

## 常见误用模式

### 1. ECB 模式
```python
# ❌ ECB 模式会泄露数据模式
cipher = AES.new(key, AES.MODE_ECB)
# ✅ 使用 GCM 模式
cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
```

### 2. 固定 IV/Nonce
```java
// ❌ 固定 IV 导致已知明文攻击
byte[] iv = "1234567890123456".getBytes();
// ✅ 每次加密生成随机 IV
byte[] iv = new byte[12];
SecureRandom.getInstanceStrong().nextBytes(iv);
```

### 3. 不安全的密钥派生
```go
// ❌ 直接使用密码作为密钥
key := []byte(password)
// ✅ 使用 PBKDF2/Argon2 派生
key := pbkdf2.Key([]byte(password), salt, 600000, 32, sha256.New)
```
