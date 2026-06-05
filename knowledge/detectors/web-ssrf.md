---
detector: ssrf
severity: high
cwe: CWE-918
language: [java, python, go]
tags: [web, ssrf, network]
---

# Server-Side Request Forgery (SSRF)

## 威胁定义

攻击者诱导服务器向内部网络或自身发起请求，绕过防火墙访问内部服务（云元数据、内网数据库、管理接口）。

**核心原则：用户可控的 URL/地址不应被服务端直接请求。** 覆盖 URL 直接请求、重定向链跟随、DNS Rebinding 三种攻击模式。

## Detection Logic

### Step 1: Search for dangerous HTTP request patterns

**Java:**
```java
// BAD: user URL directly to HTTP client
URL url = new URL(userInput);
HttpURLConnection conn = (HttpURLConnection) url.openConnection();

// BAD: RestTemplate with user URL
restTemplate.getForObject(userInput, String.class);

// BAD: WebClient with user URL
webClient.get().uri(userInput).retrieve();
```

**Python:**
```python
# BAD: requests with user URL
requests.get(user_input)

# BAD: urllib with user URL
urllib.request.urlopen(user_input)
```

**Go:**
```go
// BAD: http.Get with user URL
http.Get(userURL)

// BAD: ReverseProxy with user target
httputil.NewSingleHostReverseProxy(url.Parse(userURL))
```

### Step 2: Safe alternatives

```java
// GOOD: Validate URL against allowlist
URI uri = new URI(userInput);
if (!ALLOWED_HOSTS.contains(uri.getHost())) {
    throw new SecurityException();
}
```

```python
# GOOD: Validate against internal IP blocklist
import ipaddress
parsed = urlparse(user_input)
ip = socket.gethostbyname(parsed.hostname)
if ipaddress.ip_address(ip).is_private:
    raise ValueError("Internal IP blocked")
```

```go
// GOOD: URL validation + allowlist
u, _ := url.Parse(userURL)
if u.Scheme != "https" {
    return errors.New("https only")
}
```

## 修复指引

1. **首选**：禁用用户完全控制的 URL 请求
2. **次选**：严格 DNS 白名单 + 禁止内网 IP 段（127.0.0.0/8, 10.0.0.0/8, 169.254.169.254）
3. **补充**：禁止跟随重定向 / 禁用非 HTTP 协议（file://、gopher://、dict://）

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| URL from allowlist (validated against known-good hosts) | Explicitly allowed |
| URL constructed from constants (not user-controlled) | No injection path |
| Schema validation (https only + host allowlist) | Multiple layers of defense |

## Detection Pattern Summary

```
# Java
new URL\(.*user|restTemplate.*get.*user|WebClient.*uri.*user

# Python
requests\.(get|post|put)\(.*user|urlopen\(.*user

# Go
http\.(Get|Post|NewRequest)\(.*user|url\.Parse\(.*user
```
