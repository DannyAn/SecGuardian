---
detector: jwt-misuse
severity: high
cwe: CWE-347
language: [java, python, go]
tags: [web, authentication, jwt]
---

# JWT Misuse

## 威胁定义

JWT 实现不当：弱签名密钥（可被暴力破解）、算法混淆攻击（`alg: none`/RS256→HS256）、缺少过期验证（永不过期token）。OWASP #2 API 安全风险。

**核心原则：JWT 签名必须使用强密钥（≥256 bits）、固定 `alg` 参数、设置合理 `exp`/`iat` 并验证。**

## Detection Logic

### Step 1: Check JWT secret strength

```java
// BAD: hardcoded weak secret
String SECRET = "secret123";  // Too short, guessable

// BAD: empty or default secret
String SECRET = "";
```

```python
# BAD: hardcoded weak secret
SECRET_KEY = "password"  # Weak key
```

### Step 2: Check algorithm usage

```java
// BAD: algorithm not specified (accepts "none")
Jwts.parser().setSigningKey(secret).parseClaimsJws(token);

// GOOD: algorithm explicitly verified
Jwts.parser().setSigningKey(secret)
    .requireIssuer("my-app")
    .parseClaimsJws(token);
```

```python
# BAD: algorithm not verified
jwt.decode(token, verify=False)  # No signature verification!

# BAD: accepts "none" algorithm
jwt.decode(token, options={"verify_signature": False})
```

```go
// BAD: no key function verification
token, _ := jwt.Parse(tokenString, nil)  // Skips validation!

// GOOD: with key function
token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
    return []byte(secret), nil
})
```

### Step 3: Check for missing expiration

```java
// BAD: no expiration
Jwts.builder()
    .setSubject(userId)
    .signWith(SignatureAlgorithm.HS256, secret)
    .compact();
```

## 修复指引

1. 使用强密钥（≥256 bits 随机生成），禁止硬编码 `"secret"` / `"my-secret-key"`
2. 固定 `alg` 参数（如 `RS256`），禁止 `alg: none`，白名单算法
3. 验证 `exp`/`iat`/`nbf` 时间声明
4. 不要在 URL/query string 中传递 JWT（日志泄露风险）

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| RSA/ECDSA keys from secure key store | Strong asymmetric keys, not guessable |
| JWT with short expiration (< 15 min) | Limited window of exploitability |
| JWKS endpoint with key rotation | Key management via standard protocol |

## Detection Pattern Summary

```
# Java: weak JWT configuration
setSigningKey\(.*(\"password\"|\"secret\"|\"123\")|parseClaimsJws\(
→ No requireIssuer or requireAudience

# Python: verify=False
jwt\.decode\(.*verify=False|jwt\.decode\(.*verify_signature

# Go: nil key function
jwt\.Parse\(.*nil|jwt\.ParseWithClaims\(.*nil
```
