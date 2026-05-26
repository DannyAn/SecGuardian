---
detector: jwt-misuse
severity: high
cwe: CWE-347
language: [java, python, go]
tags: [web, authentication, jwt]
---

# JWT Misuse

## Detection Summary

Check for improper JWT implementation: weak secrets, algorithm confusion, missing expiration.

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
