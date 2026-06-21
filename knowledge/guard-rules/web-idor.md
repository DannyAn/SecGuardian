---
detector: idor
severity: high
cwe: CWE-639
language: [java, python, go]
tags: [web, authorization]
precision: low
confidence: dynamic
---

# 不安全的直接对象引用 (Insecure Direct Object Reference — IDOR)

## 威胁定义 (Threat Definition)

用户通过修改请求中的对象标识符（如 `/users/123` → `/users/456`）访问其他用户的资源，而服务端未验证当前用户对该资源的访问权限。IDOR 是 Web 应用中最常见的授权缺陷。

**核心原则：每次通过标识符访问资源时，必须验证当前认证用户对该资源的所有权或访问权限。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索来自请求参数的对象引用 (Object References from Request)

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

### Step 2: 检查所有权验证 (Ownership Verification Check)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：资源访问端点/函数的完整代码，包含对象 ID 来源（@PathVariable/@RequestParam/query/body）和数据库/存储查询语句，标注查询条件中是否包含 user_id/owner_id 过滤
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析从请求到资源返回的完整路径——是否存在授权检查点；若存在，分析检查是否覆盖所有资源访问路径（GET/POST/PUT/DELETE）；检查用户身份（session/JWT token）是否被传递到数据访问层
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：对象 ID 从 HTTP 请求参数 → Controller/Handler → Service层 → DAO/ORM查询的完整数据流，标注每层是否追加了用户身份过滤条件
      → findings.evidence.data_flow_path
- [ ] **call_stack**：Controller/Handler → Service → Repository/DAO 的完整调用链，确认每一层是否存在访问控制检查的缺口
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：对象 ID 的类型（自增整数/UUID/随机字符串）、认证用户的身份标识（user ID/session ID）、查询结果中 resource.ownerId 的值
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在全局授权中间件/拦截器、ORM层是否配置了自动 tenant/user 过滤、API Gateway 是否实现行级访问控制
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 每次通过 ID 访问资源时验证所有权：`if (resource.ownerId != currentUser.id) return 403`
2. 使用不可预测的资源标识符（UUID）替代自增 ID
3. ORM 查询时加入用户过滤条件：`WHERE id = ? AND user_id = ?`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 资源 ID 为 UUID/随机字符串（不可猜测） | 虽降低了枚举风险，但仅依赖不可猜测性属于 "security by obscurity"，不能替代授权检查。但若同时结合其他机制可降低风险 | 确认 ID 由 crypto.randomUUID()/uuid.uuid4() 生成，且资源无敏感数据 |
| 多租户隔离在数据库层实现 | 数据库行级安全策略（RLS）或视图层自动根据当前用户过滤，应用层无需手动追加 user_id 条件 | 确认数据库层配置了 RLS policy 或 tenant-aware view |
| ID 从 Session Token 派生 | 资源标识符与用户会话绑定，无法单独修改（如 JWT 中包含的资源列表） | 确认 ID 从已验证的 session/JWT claim 中提取，非独立请求参数 |
| 公开资源（无需授权） | 资源设计为公开可读（如公开文章、商品详情），无所有权概念 | 确认端点文档标注为 "public" 且资源不含用户私有数据 |
| 管理员端点 | 管理员有权访问所有用户的资源，但权限验证在更高层完成 | 确认端点有管理员角色检查（@PreAuthorize("hasRole('ADMIN')")），且审计日志完整 |
| ORM 查询条件包含 user_id | 虽然未显式做 if-else 检查，但 WHERE 条件中间接限制了结果范围 | 确认查询条件为 WHERE id = ? AND user_id = ?，且 user_id 来自当前认证会话 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: ID from path/param without ownership
@PathVariable|@RequestParam|@PathParam                # 用户可控的对象ID来源
                                                       # → MUST: code_context (端点+查询语句)
→ findById|getById|findOne                            # 直接查询，无所有权过滤
→ (无 .getUserId()|.getOwnerId() 比较)                  # 缺少所有权验证
→ return.*order|return.*resource                       # 返回资源给用户
                                                       # → MUST: judgment_rationale (授权检查点分析)

# Python: ORM query with user-controlled ID
\.objects\.get\(id=|\.objects\.filter\(pk=             # Django ORM 仅按ID查询
→ (无 request\.user|\.user_id|owner_id 过滤)            # 缺少用户过滤
\.get_object_or_404\(.*id=|query\.get\(                # 通用ORM模式

# Go: DB query with param without user check
r\.URL\.Query\(\)\.Get\(|c\.Param\(                    # 用户输入的ID
→ db\.Query|db\.Exec                                    # 数据库查询
→ (无 user_id|owner_id WHERE条件)                       # 缺少所有权过滤

# === EXCLUDE (不报告) ===
→ \.getUserId\(\)|\.getOwnerId\(\)|\.owner_id|user_id  # 所有权验证存在
→ @PreAuthorize|@RolesAllowed|@Secured                 # 框架级授权注解
→ WHERE.*AND user_id =|WHERE.*AND owner_id =            # SQL/O RM 包含用户过滤
→ AccessDeniedException|PermissionDenied|Forbidden      # 显式禁止访问处理
→ ADMIN|admin.*role|hasRole.*ADMIN                      # 管理员端点（需审计日志）
→ public.*resource|public.*endpoint                     # 明确标注为公开资源
→ request\.user\.is_staff|request\.user\.is_superuser   # Django 超级用户检查
```
