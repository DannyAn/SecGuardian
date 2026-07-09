---
name: secguard-java-weak-crypto
description: "检测 Java 弱加密算法 — MD5/SHA-1/DES/RC4/ECB/非安全 Random 用于安全用途"
language: java
topic: [crypto, algorithm]
skill_id: java.weak-crypto.algorithm
signal_source: call_sites[cat="crypto"]
severity: high
cwe: CWE-327
trigger_functions: [getInstance, MessageDigest, Cipher, SecureRandom, Random, KeyGenerator]
---

# weak_crypto 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.weak-crypto.algorithm` | `call_sites[cat="crypto"]` | `getInstance`, `MessageDigest`, `Cipher`, `Random` | High | CWE-327 |

## Scenario 1: 使用已弃用/弱安全算法

### 威胁定义
使用 MD5/SHA-1 作密码哈希（碰撞攻击可行）、DES/RC4/ECB 模式加密（可破解或信息泄露）、`java.util.Random` 用于安全令牌/会话/密钥生成（可预测）。Spring Security 和 JWT 库的密码学配置也需检查。

### 检测逻辑
```java
// BAD: MD5 / SHA-1 作安全哈希
MessageDigest md = MessageDigest.getInstance("MD5");
MessageDigest sha1 = MessageDigest.getInstance("SHA-1");

// BAD: DES / RC4 / ECB 模式
Cipher cipher = Cipher.getInstance("DES/CBC/PKCS5Padding");
Cipher rc4 = Cipher.getInstance("RC4");
Cipher ecb = Cipher.getInstance("AES/ECB/PKCS5Padding");

// BAD: 非安全随机数用于安全用途
String token = Long.toString(new Random().nextLong());

// GOOD: SHA-256 作非密码哈希时的替代
MessageDigest md = MessageDigest.getInstance("SHA-256");

// GOOD: AES-GCM
Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");

// GOOD: 安全随机数
SecureRandom sr = SecureRandom.getInstanceStrong();
```

### 检测模式
**MATCH**: `MessageDigest.getInstance("MD5"` / `MessageDigest.getInstance("SHA-1"`；`Cipher.getInstance("DES` / `Cipher.getInstance("RC4` / `Cipher.getInstance.*ECB`；`new Random()` 且上下文含 `token|session|password|crypto|key`

**EXCLUDE**: 非安全用途（checksum / dedup / cache key）；遗留系统互操作（有文档记录 + 补偿控制）

### 修复指引
- 哈希：SHA-256/384/512（密码存储用 bcrypt/Argon2id）
- 加密：AES-256-GCM / ChaCha20-Poly1305
- 随机数：`SecureRandom.getInstanceStrong()` / 慎用 `new SecureRandom()`

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 弱算法调用的完整代码行及上下文用途 |
| judgment_rationale | MUST | 该算法在当前场景下是否构成实际风险 |
| call_stack | SHOULD | 调用位置到最外层用途的上下文 |
| variable_state | MAY | 密钥长度、操作模式、IV/Nonce 方式 |

## 输出格式
`[High][CWE-327] {file}:{line} — 弱加密算法（{algorithm}）`
