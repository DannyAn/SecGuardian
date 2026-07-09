# Weak Crypto — 跨函数追踪 (Go)

适用于 `go.crypto.weak` skill（CWE-327）。max depth 1。

## 场景一: 弱哈希用于密码存储

```go
func registerUser(w http.ResponseWriter, r *http.Request) {
    password := r.FormValue("password")
    hash := hashPassword(password)            // 调用哈希函数
    db.Exec("INSERT INTO users VALUES($1, $2)", username, hash)
}

func hashPassword(pwd string) string {
    h := md5.Sum([]byte(pwd))                 // Sink: MD5 密码哈希
    return hex.EncodeToString(h[:])
}
```

## 场景二: math/rand 用于安全 token

```go
func generateSessionToken() string {
    return weakRandomString(32)               // 调用弱随机
}

func weakRandomString(length int) string {
    const charset = "abcdefghijklmnopqrstuvwxyz0123456789"
    b := make([]byte, length)
    for i := range b {
        b[i] = charset[mathRand.Intn(len(charset))]  // Sink: math/rand
    }
    return string(b)
}
```

## 场景三: DES 加密跨函数

```go
func encryptData(plaintext []byte) ([]byte, error) {
    return desEncrypt(plaintext, secretKey)   // 调用 DES
}

func desEncrypt(data, key []byte) ([]byte, error) {
    block, _ := des.NewCipher(key)             // Sink: DES 弱加密
    // ...
}
```

## 深度限制

- max depth 1，追踪弱算法/弱随机数的使用链
- 重点追踪: 密码哈希、token 生成、加密函数中的算法选择
