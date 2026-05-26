---
detector: ssrf
severity: high
cwe: CWE-918
language: [java, python, go]
tags: [web, ssrf, network]
---

# Server-Side Request Forgery (SSRF)

## Detection Summary

Check whether user-controlled URLs are used in server-side HTTP requests without validation.

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
