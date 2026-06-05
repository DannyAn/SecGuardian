---
detector: open-redirect
severity: medium
cwe: CWE-601
language: [java, python, go]
tags: [web, redirect, phishing]
---

# Open Redirect

## 威胁定义

用户可控制的 URL 作为重定向目标且未经验证，攻击者可利用此漏洞将用户重定向到钓鱼网站，窃取凭证或令牌。常用于鱼叉式钓鱼和社会工程攻击。

**核心原则：重定向目标必须在服务端白名单中，或使用相对路径/内部路由标识符而非完整URL。**

## Detection Logic

### Step 1: Search for redirect with user input

```java
// BAD: redirect URL from request parameter
@GetMapping("/redirect")
public String redirect(@RequestParam String url) {
    return "redirect:" + url;  // Open redirect!
}

// BAD: forward with user input
request.getRequestDispatcher(userPath).forward(request, response);
```

```python
# BAD: redirect with user-controlled URL
def redirect(request):
    next_url = request.GET.get('next')
    return redirect(next_url)  # Open redirect!
```

```go
// BAD: redirect with user-supplied path
http.Redirect(w, r, r.URL.Query().Get("redirect"), http.StatusFound)
```

### Step 2: Check for safe alternatives

```go
// GOOD: validate against allowlist
safeRedirects := map[string]bool{"/dashboard": true, "/profile": true}
if safeRedirects[r.URL.Query().Get("redirect")] {
    http.Redirect(w, r, r.URL.Query().Get("redirect"), http.StatusFound)
}
```

```python
# GOOD: verify against allowed domains
ALLOWED_DOMAINS = {'example.com', 'app.example.com'}
parsed = urlparse(next_url)
if parsed.netloc in ALLOWED_DOMAINS:
    return redirect(next_url)
```

## 修复指引

1. 使用服务端维护的重定向目标白名单（URL → Token 映射）
2. 使用相对路径或内部路由标识符（`redirect=/dashboard`）替代完整 URL
3. 验证目标 URL 的域名在白名单中

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| Redirect to hardcoded paths only | No user-controlled input |
| Allowlist validation in place | Only approved target URLs allowed |
| Hash fragments (non-URL redirect) | Server-side unchanged |

## Detection Pattern Summary

```
# Java: redirect with user input
redirect:.*\+|sendRedirect\(.*request|forward\(.*user|request.*param

# Python: redirect with user URL
redirect\(request\.GET|redirect\(request\.POST|redirect\(.*input

# Go: redirect with user param
http\.Redirect.*r\.URL\.Query|Redirect.*c\.Query|Redirect.*param
```
