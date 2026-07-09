# Weak Crypto — 误报抑制策略 (Go)

适用于 `go.crypto.weak` skill（CWE-327）。

## 策略 1: crypto/rand 确认

区分 `crypto/rand`（安全）和 `math/rand`（不安全）。

```go
import "crypto/rand"
rand.Read(b)   // ✅ crypto/rand — 安全

import "math/rand"
rand.Read(b)   // ❌ math/rand — 不安全（实际上 math/rand 没有 Read 方法）
rand.Intn(100) // ❌ math/rand — 不安全
```

**检查清单:**
- [ ] import 语句是 `"crypto/rand"` 还是 `"math/rand"`？
- [ ] `crypto/rand.Read` 返回 `(n, error)`，`math/rand.Intn` 返回 `int`
- [ ] `math/rand` 可设置种子（`rand.Seed`），`crypto/rand` 不可

## 策略 2: 用途区分

| 算法 | 安全用途（报告） | 非安全用途（抑制） |
|------|----------------|------------------|
| MD5 | 密码哈希、数字签名 | 文件校验和、重复检测 |
| SHA-1 | 证书签名、数字签名 | Git 哈希、内容寻址 |
| math/rand | Token/Key/Session 生成 | 游戏、模拟、洗牌 |
| DES | 数据加密 | 无（DES 不应在任何新代码中使用） |

## 策略 3: 过时库检测

如果弱算法仅在兼容旧数据时使用（只读），可考虑降级。

```go
// 兼容旧数据 — 低风险
func verifyLegacyHash(password, hash string) bool {
    h := md5.Sum([]byte(password))  // 仅验证旧哈希，不创建新哈希
    return hex.EncodeToString(h[:]) == hash
}
```

## 策略 4: 测试文件抑制

## 策略 5: 常量/占位符

```go
// 示例代码或注释中的算法提及不报告
// const exampleMD5 = "5d41402abc4b2a76b9719d911017c592"
```
