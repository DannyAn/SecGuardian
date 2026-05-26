---
detector: auth-bypass
severity: critical
cwe: CWE-287
language: [java, python, go]
tags: [web, authentication]
---

# Authentication Bypass

## Detection Summary

Check whether authentication checks are missing, misconfigured, or bypassable.

## Detection Logic

### Step 1: Search for missing authentication

**Java (Spring Security):**
```java
// BAD: permitAll on sensitive endpoints
http.authorizeRequests()
    .antMatchers("/admin/**").permitAll()  // No auth required!

// BAD: @PermitAll on method
@PermitAll
@PostMapping("/admin/delete-user")
```

**Python (Django):**
```python
# BAD: missing @login_required on view
def admin_dashboard(request):
    pass  # @login_required missing

# BAD: !request.user.is_authenticated reversed
if not request.user.is_authenticated:
    # Treat unauthenticated as allowed — logic error
```

**Go (net/http):**
```go
// BAD: handler without auth middleware
http.HandleFunc("/admin", adminHandler)  // No auth middleware applied
```

### Step 2: Check auth middleware order

```
// BAD: CSRF middleware after handler (won't protect)
app → handler → middleware
// GOOD: Auth middleware before handler
app → middleware → handler
```

### Step 3: Check for bypass paths

```java
// BAD: overlapping path patterns
.antMatchers("/api/**").permitAll()
// But /api/admin/* should be authenticated!
```

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| Public endpoints (login, register) | No auth needed by design |
| API gateway handles auth externally | Authentication delegated upstream |
| Internal-only routes (not exposed) | Network-level protection |
| WebSocket upgrade endpoints | Auth via protocol handshake |

## Detection Pattern Summary

```
# Java: permitAll on admin paths
permitAll\(\) .* admin|permitAll\(\) .* manage|permitAll\(\) .* secret

# Python: missing login_required on views
def (admin|dashboard|settings|config):  # without @login_required

# Go: handler without auth middleware
HandleFunc\(.*(admin|config|secret)
```
