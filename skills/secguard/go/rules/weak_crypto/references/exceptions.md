# Weak Crypto — 例外规则 (Go)

适用于 `go.crypto.weak` skill（CWE-327）。

## 例外 1: 非安全用途的弱哈希

MD5/SHA-1 用于非安全场景时不报告。

```go
// EXCEPTION: 文件完整性校验（非安全哈希）
func verifyFileIntegrity(path string, expectedHash string) bool {
    data, _ := os.ReadFile(path)
    hash := md5.Sum(data)           // 用于重复检测/去重，非安全用途
    return hex.EncodeToString(hash[:]) == expectedHash
}

// EXCEPTION: 内容寻址存储
func contentAddress(data []byte) string {
    h := sha1.Sum(data)             // Git 式的对象寻址，非安全
    return hex.EncodeToString(h[:])
}

// EXCEPTION: 布隆过滤器/一致性哈希
func hashSlot(key string, slots int) int {
    h := md5.Sum([]byte(key))
    return int(binary.BigEndian.Uint32(h[:4])) % slots
}
```

## 例外 2: crypto/rand 用于安全随机数

使用 `crypto/rand`（安全随机数生成器）而非 `math/rand` 的场景不报告。

```go
// EXCEPTION: 使用 crypto/rand
import "crypto/rand"

func generateAPIKey() string {
    b := make([]byte, 32)
    rand.Read(b)                    // crypto/rand，安全
    return hex.EncodeToString(b)
}
```

## 例外 3: crypto/rand + encoding/hex 的 token 生成

```go
// EXCEPTION: 安全的 token 生成
func generateSecureToken() (string, error) {
    b := make([]byte, 32)
    if _, err := rand.Read(b); err != nil {
        return "", err
    }
    return hex.EncodeToString(b), nil
}
```

## 例外 4: bcrypt/scrypt/argon2 替代 MD5 哈希

```go
// EXCEPTION: 使用 bcrypt 密码哈希
hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
bcrypt.CompareHashAndPassword(hash, []byte(input))

// EXCEPTION: 使用 argon2
argon2.IDKey([]byte(password), salt, 1, 64*1024, 4, 32)
```

## 例外 5: crypto/sha256/sha512 替代 SHA-1

```go
// EXCEPTION: 使用 SHA-256
h := sha256.Sum256(data)
h := hmac.New(sha256.New, key)
```

## 例外 6: AES-GCM 替代 DES

```go
// EXCEPTION: 使用 AES-256-GCM
block, _ := aes.NewCipher(key)
gcm, _ := cipher.NewGCM(block)
sealed := gcm.Seal(nil, nonce, plaintext, nil)
```

## 例外 7: 测试代码

`_test.go` 完全抑制。
