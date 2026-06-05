---
detector: csrf
severity: high
cwe: CWE-352
language: [java, python, go]
tags: [web, csrf, access-control]
---

# Cross-Site Request Forgery (CSRF)

## 威胁定义

攻击者诱导已认证用户点击恶意链接/表单，利用用户的已认证状态执行非预期的状态变更操作（转账、修改密码、删除数据）。CSRF 依赖"浏览器自动携带Cookie"的特性。

**核心原则：所有状态变更的请求（POST/PUT/DELETE）必须包含 CSRF Token 或验证 `Origin`/`Referer` 头。**

## Detection Logic

### Step 1: Search for endpoints without CSRF protection

**Java (Spring Security):**
```java
// BAD: disabling CSRF completely
http.csrf().disable();

// BAD: public POST endpoint without CSRF token validation
@PostMapping("/api/transfer")
public String transfer(@RequestParam String to, @RequestParam int amount) {
    // No CSRF token check
}
```

**Python (Django):**
```python
# BAD: per-view CSRF exemption
@csrf_exempt
def transfer_money(request):
    pass

# BAD: middleware disabled
MIDDLEWARE = [
    # 'django.middleware.csrf.CsrfViewMiddleware',  # DISABLED
]
```

**Python (Flask):**
```python
# BAD: Flask-WTF CSRF disabled
app.config['WTF_CSRF_ENABLED'] = False
```

**Go (Gin):**
```go
// BAD: no CSRF middleware
r.POST("/transfer", handler)
```

### Step 2: Check for CSRF token validation

```java
// GOOD: Spring Security CSRF enabled by default
// GOOD: Manually validate token on state-changing endpoints
```

### Step 3: Check non-GET endpoints

Focus on POST/PUT/DELETE/PATCH endpoints that change state without token verification.

## 修复指引

1. 使用框架 CSRF 保护：Spring Security CSRF / Django `{% csrf_token %}` / Express `csurf`
2. 对 API（非浏览器客户端）使用 `Authorization` header 而非 Cookie 认证
3. SameSite Cookie 设置为 `Strict` 或 `Lax`

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| API-only backend (no browser clients) | CSRF only applies to cookie-based auth |
| Token auth (JWT, OAuth2 Bearer) | CSRF irrelevant for token-based auth |
| Same-Origin-only endpoints | CORS + Origin check provide alternative protection |
| Idempotent GET requests | Only state-changing methods need CSRF |

## Detection Pattern Summary

```
# Java: CSRF disabled
csrf\(\)\.disable\(\)|@csrf_exempt|CsrfViewMiddleware.*comment

# Python: CSRF exemption
@csrf_exempt|csrf_exempt|CSRF_ENABLED.*False|WTF_CSRF_ENABLED.*False

# Go: Missing CSRF middleware
r\.(POST|PUT|DELETE|PATCH)\(
→ No CSRF middleware in router group
```
