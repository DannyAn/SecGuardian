---
detector: jwt-misuse
severity: high
cwe: CWE-347
cvss: 7.8
language: [java, python, go]
tags: [web, authentication, jwt]
precision: high
confidence: dynamic
target_functions: [builder, byte, compact, decode, func, parseClaimsJws, parser, requireIssuer, setSigningKey, setSubject, signWith, specified]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

JWT 实现不当：弱签名密钥（可被暴力破解）、算法混淆攻击（`alg: none`/RS256→HS256）、缺少过期验证（永不过期token）。OWASP #2 API 安全风险。

**核心原则：JWT 签名必须使用强密钥（≥256 bits）、固定 `alg` 参数、设置合理 `exp`/`iat` 并验证。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. 使用强密钥（≥256 bits 随机生成），禁止硬编码 `"secret"` / `"my-secret-key"`
2. 固定 `alg` 参数（如 `RS256`），禁止 `alg: none`，白名单算法
3. 验证 `exp`/`iat`/`nbf` 时间声明
4. 不要在 URL/query string 中传递 JWT（日志泄露风险）

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：JWT verify/decode 调用及密钥配置
      → findings.evidence.code_context
- [ ] **judgment_rationale**：算法验证/过期检查是否缺失
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：JWT Token 从接收端到验证的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：JWT 解析和验证的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：签名密钥/算法参数/过期时间设置
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否有算法白名单或 requireIssuer 等强制验证
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|----------|--------|--------|
| RSA/ECDSA keys from secure key store | Strong asymmetric keys, not guessable | 提供密钥存储证明（KMS/HSM/环境变量来源，非硬编码） |
| JWT with short expiration (< 15 min) | Limited window of exploitability | 提供 exp/iat 声明配置及验证代码，确认 exp <= 15 min |
| JWKS endpoint with key rotation | Key management via standard protocol | 提供 JWKS 端点 URL 及密钥轮转策略文档 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# Java: weak JWT configuration
setSigningKey\(.*(\"password\"|\"secret\"|\"123\")|parseClaimsJws\(
→ 缺少 requireIssuer 或 requireAudience
→ evidence: code_context, variable_state

# Python: verify=False
jwt\.decode\(.*verify=False|jwt\.decode\(.*verify_signature
→ evidence: code_context, judgment_rationale

# Go: nil key function
jwt\.Parse\(.*nil|jwt\.ParseWithClaims\(.*nil
→ evidence: code_context

# 缺少过期验证
Jwts\.builder\(\)
→ 链式调用中无 setExpiration/requireExpiration
→ evidence: variable_state
```

### 排除模式 (EXCLUDE)

```
# RSA/ECDSA 来自安全密钥存储
→ evidence: sanitizer_analysis (密钥来源非硬编码)

# JWT 显式算法验证 + requireIssuer/requireAudience/requireExpiration
→ evidence: sanitizer_analysis (完整验证链)

# JWKS 端点 + 密钥轮转
→ evidence: sanitizer_analysis (标准协议管理)
```
