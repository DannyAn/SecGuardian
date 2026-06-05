---
detector: idor
severity: high
cwe: CWE-639
language: [java, python, go]
tags: [web, authorization]
---

# Insecure Direct Object Reference (IDOR)

## 威胁定义

用户通过修改请求中的对象标识符（如 `/users/123` → `/users/456`）访问其他用户的资源，而服务端未验证当前用户对该资源的访问权限。IDOR 是 Web 应用中最常见的授权缺陷。

**核心原则：每次通过标识符访问资源时，必须验证当前认证用户对该资源的所有权或访问权限。**

## Detection Logic

### Step 1: Search for object references from request parameters

```java
// BAD: using user-supplied ID without ownership check
@GetMapping("/api/order/{orderId}")
public Order getOrder(@PathVariable Long orderId) {
    return orderRepo.findById(orderId);  // No ownership check!
}

// BAD: file access with user-supplied path
Files.readAllBytes(Paths.get("/data/" + userId + "/" + fileName));
```

```python
# BAD: direct object reference without authorization
def view_order(request, order_id):
    order = Order.objects.get(id=order_id)  # No user_id filter!
    return render(request, 'order.html', {'order': order})
```

```go
// BAD: parameter directly into DB query
func getOrder(w http.ResponseWriter, r *http.Request) {
    id := r.URL.Query().Get("id")
    db.Query("SELECT * FROM orders WHERE id = ?", id)  // No user check!
}
```

### Step 2: Check for ownership verification

```java
// GOOD: verify object ownership
@GetMapping("/api/order/{orderId}")
public Order getOrder(@PathVariable Long orderId, Principal principal) {
    Order order = orderRepo.findById(orderId);
    if (!order.getUserId().equals(principal.getUserId())) {
        throw new AccessDeniedException();
    }
    return order;
}
```

## 修复指引

1. 每次通过 ID 访问资源时验证所有权：`if (resource.ownerId != currentUser.id) return 403`
2. 使用不可预测的资源标识符（UUID）替代自增 ID
3. ORM 查询时加入用户过滤条件：`WHERE id = ? AND user_id = ?`

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| IDs are UUIDs (non-guessable) | Reduces but does not eliminate risk |
| Multi-tenant isolation at DB level | Data separation by tenant ID enforced |
| IDs derived from session token | User context tied to identifier |

## Detection Pattern Summary

```
# Java: ID from path/param without ownership
@PathVariable|@RequestParam|@PathParam
→ findById|getById|findOne (no ownership check before return)

# Python: ORM query with user-controlled ID
.objects\.get\(id=|\.objects\.filter\(pk=  (without request.user filter)

# Go: DB query with param without user check
r\.URL\.Query\(\)\.Get\(|c\.Param\(
→ db\.Query|db\.Exec (no user_id check)
```
