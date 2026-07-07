---
detector: missing-authentication
severity: critical
cwe: CWE-306
cvss: 9.8
language: [java, python, go]
tags: [web, authentication, access-control]
precision: very-high
confidence: dynamic
target_functions: [admin, antMatchers, code_context, configure, doFilter, getAttribute, getCurrentUser, getHeader, getId, getPrincipal, getProfile, getSession, get_profile, get_user_data, ignoring, ilter, internal, jsonify, judgment_rationale, login_required, nterceptor, orders, parseClaims, parseToken, payment, private, profile, route, secret, settings, transfer, user, uthenticationPrincipal, uthorization, verify, verifyToken]
match_patterns: [/api/(profile|orders|transfer|payment|settings), /api/(admin|internal|private|secret), Header.*Authorization|Bearer]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

关键功能端点（管理接口、敏感数据API、用户操作）完全不需要认证即可访问 — 任何人都可调用。对于已部署认证机制的绕过缺陷，参考 `auth-bypass` 检测器。

**核心原则：所有非公开端点必须经过认证中间件/拦截器。框架路由定义时即指定认证要求。**

## 检测逻辑 (Detection Logic)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：关键功能端点的完整代码，包含路由映射（@GetMapping/@PostMapping/@app.route/HandleFunc）、方法签名、以及所有认证相关注解/装饰器（@AuthenticationPrincipal/@login_required/@PreAuthorize 等）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析端点是否被认证机制保护——是否存在认证注解/装饰器、是否有 Session/Token 验证代码（getAttribute("user")/jwt.verify）、请求中携带的凭证是否被实际验证（非仅读取）；特别关注是否存在认证绕过路径（web.ignoring/条件跳过）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：请求从 HTTP 入口 → 认证 Filter/Interceptor/Middleware → Handler 的完整数据流，标注认证检查点的位置和覆盖范围
      → findings.evidence.data_flow_path
- [ ] **call_stack**：FilterChain/InterceptorChain 的完整顺序，确认 SecurityFilter/AuthenticationFilter 是否覆盖了当前端点
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：Session 中 user 属性的存在性、JWT token 的验证状态、请求中 Authorization header 的值
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：Spring Security 全局配置是否覆盖所有路由（.anyRequest().authenticated()）、API Gateway 是否有统一的 Token 验证、是否存在 whitelist/ignoring 配置误放行
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 全局认证中间件/拦截器覆盖所有路由
2. 使用框架注解：`@PreAuthorize`/`@Authenticated`/`@UseGuards(AuthGuard)`
3. 默认拒绝：所有端点默认要求认证，公开端点显式标记白名单

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 公开 API 端点（健康检查 /health） | 设计上不需要认证 | 确认端点路径在公开白名单中（如 spring security permitAll），且端点不返回敏感数据 |
| OAuth2/OIDC Gateway 层已处理 | 全局认证 | 确认网关配置了 OAuth2 client 验证，所有请求经过网关后带有已验证的 principal |
| 静态资源（/css/, /js/, /images/） | 公开内容 | 确认路径为静态资源目录，且 web 服务器配置为直接 serve，不经过业务逻辑 |
| Webhook 接收端点（签名验证代替） | 非认证机制 | 确认使用 HMAC 签名验证（非 session/token 认证），签名密钥安全存储 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 敏感端点 + 无认证注解/检查
/api/(profile|orders|transfer|payment|settings)
                                                       # → MUST: code_context (端点路由+认证相关代码)
→ 无 @AuthenticationPrincipal|@login_required|@PreAuthorize
→ 无 getAttribute.*user|getPrincipal|verifyToken
                                                       # → MUST: judgment_rationale (认证机制缺失分析)

# API 组前缀无全局认证
/api/(admin|internal|private|secret)
→ 无全局 Filter|Interceptor|Middleware 覆盖

# JWT/Token 缺失验证
Header.*Authorization|Bearer
→ 无 jwt\.verify|parseClaims|parseToken (在同一请求处理中)

# === EXCLUDE (不报告) ===
→ @AuthenticationPrincipal|@login_required             # 认证注解/装饰器
→ @PreAuthorize.*authenticated                         # Spring Security 认证
→ session\.getAttribute.*user|getUserPrincipal         # Session/Token 验证
→ jwt\.verify|parseClaimsJws|jwt\.parse                 # JWT 验证
→ \.authenticated\(\)|\.hasRole\(                       # 全局安全配置
→ \.permitAll\(\)\s*/\*\*health|public                    # 公开白名单
→ SecurityFilterChain|WebSecurityConfigurerAdapter       # Spring Security 配置
→ HMAC|hmac_sha256|sign\.verify                          # Webhook 签名验证
```
