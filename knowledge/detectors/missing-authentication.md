---
detector: missing-authentication
severity: critical
cwe: CWE-306
language: [java, python, go]
tags: [web, authentication, access-control]
---

# 缺失认证 (Missing Authentication for Critical Function)

## 检测概要

检查关键功能端点是否要求用户认证。与 auth-bypass（CWE-287）关注绕过已存在的认证不同，本检测器关注完全不要求认证的端点。

## 检测逻辑

### Step 1: 识别关键功能端点

```java
@GetMapping("/api/orders")              // 用户订单（需认证）
@GetMapping("/api/profile")             // 用户资料（需认证）
@PostMapping("/api/transfer")           // 转账（需认证）
```

```python
@app.route("/api/orders")
@app.route("/api/transfer", methods=["POST"])
```

```go
http.HandleFunc("/api/profile", profileHandler)
http.HandleFunc("/api/transfer", transferHandler)
```

### Step 2: 检查认证机制

```java
// BAD: 无认证检查
@GetMapping("/api/profile")
public Profile getProfile() {
    return userService.getCurrentUser();  // 但未验证请求者身份
}

// GOOD: 有认证检查
@GetMapping("/api/profile")
public Profile getProfile(@AuthenticationPrincipal User user) {
    return userService.getProfile(user.getId());
}
```

```python
# BAD: 无认证
@app.route("/api/profile")
def get_profile():
    return jsonify(get_user_data())

# GOOD: 有认证
@app.route("/api/profile")
@login_required
def get_profile():
    return jsonify(get_user_data(current_user.id))
```

### Step 3: 检查 Session/Token 验证

```java
// BAD: 未验证 session 有效性
HttpSession session = request.getSession();
// 未检查 session.getAttribute("user") == null

// BAD: 未验证 JWT token
String token = request.getHeader("Authorization");
// 没有 token 解析和验证步骤
```

### Step 4: 检查认证绕过路径

```java
// BAD: 某些路径跳过认证过滤器
@Override
public void configure(WebSecurity web) {
    web.ignoring()
        .antMatchers("/api/admin/**");    // 误放行！
}

// BAD: 条件认证逻辑
if (request.getHeader("X-Internal") != null) {
    chain.doFilter(request, response);    // 内部请求也不应跳过
    return;
}
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 公开 API 端点（健康检查 /health） | 设计上不需要认证 |
| OAuth2/OIDC Gateway 层已处理 | 全局认证 |
| 静态资源（/css/, /js/, /images/） | 公开内容 |
| Webhook 接收端点（签名验证代替） | 非认证机制 |

## 检测模式汇总

```
# 敏感端点 + 无认证注解/检查
/api/(profile|orders|transfer|payment|settings)
→ 无 @AuthenticationPrincipal|@login_required|@PreAuthorize
→ 无 getAttribute.*user|getPrincipal|verifyToken

# API 组前缀无全局认证
/api/(admin|internal|private|secret)
→ 无全局 Filter|Interceptor|Middleware 覆盖

# JWT/Token 缺失验证
Header.*Authorization|Bearer
→ 无 jwt\.verify|parseClaims|parseToken (在同一请求处理中)
```

## CWE 映射

- CWE-306: Missing Authentication for Critical Function
- CWE-862: Missing Authorization（功能级授权）
- CWE-287: Improper Authentication（认证绕过）
