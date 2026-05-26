---
detector: open-redirect
severity: medium
cwe: CWE-601
language: [java, python, go]
tags: [web, redirect, phishing]
---

# Open Redirect

## Detection Summary

Check whether user-controlled URLs are used as redirect targets without validation.

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
