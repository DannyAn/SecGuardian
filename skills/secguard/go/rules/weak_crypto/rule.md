---
name: secguard-go-weak-crypto
description: "Detect deprecated or weak cryptographic algorithms — MD5, SHA-1, DES, math/rand for security — enabling decryption or forgery"
language: go
topic: [crypto]
skill_id: go.crypto.weak
signal_filter: go.crypto.weak*
signal_source: call_sites[category="*"]
severity: high
cwe: [CWE-327]
trigger_functions: [crypto/md5.New, crypto/sha1.New, crypto/des.NewCipher, math/rand.Read, math/rand.Intn, crypto/rand.Read]
---

# weak_crypto 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.crypto.weak` |
| signal_filter | `go.crypto.weak*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `crypto/md5.Sum`, `crypto/sha1.Sum`, `crypto/des.NewCipher`, `math/rand.Read`, `math/rand.Intn`, `crypto/rand.Read` |
| 默认严重度 | High |
| CWE | CWE-327 (Use of a Broken or Risky Cryptographic Algorithm) |
| Guard-rule | `crypto-weak-crypto-algorithm`, `crypto-weak-random` |

## Scenario 1: 弱哈希 / 弱加密算法

### 威胁定义

Go 标准库提供 `crypto/md5`、`crypto/sha1`、`crypto/des` 等已废弃算法。MD5/SHA-1 存在已知碰撞攻击，DES 密钥长度（56 位）可被暴力破解。`math/rand` 是伪随机数生成器，**不得**用于安全场景（token/key/session 生成）。

**核心原则：已知弱算法仅可用于非安全用途（校验和、去重哈希），安全场景必须使用 SHA-256+ / AES-256-GCM / crypto/rand。**

### 检测逻辑

```go
// 脆弱 — 弱哈希用于安全场景
hash := md5.Sum(data)           // MD5 碰撞可构造
hash := sha1.Sum(data)          // SHA-1 碰撞攻击可行

// 脆弱 — 弱加密
block, _ := des.NewCipher(key)  // DES 密钥过短

// 脆弱 — math/rand 用于安全场景
token := make([]byte, 32)
rand.Read(token)                // 可预测!

// 安全 — SHA-256/384/512
hash := sha256.Sum256(data)

// 安全 — AES-256-GCM
block, _ := aes.NewCipher(key)
gcm, _ := cipher.NewGCM(block)

// 安全 — crypto/rand 安全随机
import "crypto/rand"
token := make([]byte, 32)
rand.Read(token)
```

### 检测模式

```
# MATCH（触发检测）
→ import "crypto/md5" 且用于安全用途（认证/签名/密码存储）
→ import "crypto/sha1" 且用于安全用途
→ crypto/des.NewCipher(key) — 任何使用场景
→ math/rand 用于 token/session/key/crypto 上下文
→ cipher.NewCBCEncrypter / ECB 模式

# EXCLUDE（不报告）
→ md5.Sum 用于校验和/checksum/去重（非安全用途）
→ sha1.Sum 用于非安全用途（git commit hash 等）
→ math/rand 用于游戏/模拟/非安全场景
→ crypto/rand.Read 的导入和调用
→ bcrypt/scrypt/argon2 用于密码存储
```

### 修复指引

| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | crypto/md5, crypto/sha1 | crypto/sha256, crypto/sha512 |
| 对称加密 | crypto/des | crypto/aes (GCM 模式) |
| 随机数 | math/rand 安全用途 | crypto/rand.Read |
| 密码存储 | md5/sha 单次 | golang.org/x/crypto/bcrypt / argon2 |

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 弱算法调用行及上下文用途（安全 vs 非安全） |
| judgment_rationale | MUST | 分析该算法在当前使用场景下的实际风险 |
| data_flow_path | SHOULD | 输入数据 → 弱算法处理 → 输出使用的完整数据流 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
