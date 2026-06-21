---
detector: auth-bypass
severity: critical
cwe: CWE-287
language: [java, python, go]
tags: [web, authentication]
precision: medium
confidence: dynamic
---

# 认证绕过 (Authentication Bypass)

## 威胁定义 (Threat Definition)

认证检查缺失、配置错误或可被绕过，导致未认证用户访问受保护的功能和数据。常见的绕过方式：直接访问URL、修改认证参数、利用框架配置缺陷。

**核心原则：所有受保护端点必须在进入业务逻辑前完成认证校验。框架中间件必须全局覆盖所有路由。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索缺少认证的端点 (Missing Authentication)

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

### Step 2: 检查认证中间件顺序 (Auth Middleware Order)

```
// BAD: CSRF middleware after handler (won't protect)
app → handler → middleware
// GOOD: Auth middleware before handler
app → middleware → handler
```

### Step 3: 检查绕过路径 (Bypass Paths)

```java
// BAD: overlapping path patterns
.antMatchers("/api/**").permitAll()
// But /api/admin/* should be authenticated!
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：受保护端点的完整路由配置/装饰器/中间件链，以及对应 Handler/Controller 的完整代码，标注认证检查点的位置和类型
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析每个端点的认证覆盖率——安全配置（Spring Security config / Django MIDDLEWARE / Go middleware chain）中哪些路由被 permitAll 或未覆盖；分析路由匹配冲突（通配符覆盖 sensitive 路径）；分析认证逻辑本身的正确性（条件反转、短路求值）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：HTTP 请求从入口 → 中间件链 → 路由匹配 → Handler 的完整处理链，标注认证检查在链中的位置以及请求是否可以跳过检查到达 Handler
      → findings.evidence.data_flow_path
- [ ] **call_stack**：中间件注册顺序 → 路由匹配 → Handler 执行的全调用栈，确认认证中间件是否在所有业务 Handler 之前执行
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：请求上下文中的认证状态（isAuthenticated / principal / user 对象），以及路由匹配器中命中的具体模式
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在全局认证过滤器（如 OncePerRequestFilter / Django AuthenticationMiddleware）、API Gateway 是否在外部已完成认证
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 全局认证中间件覆盖所有路由（Spring Interceptor / Django Middleware / Express middleware）
2. 认证逻辑在进入业务代码前执行，不要依赖业务代码内部的手动检查
3. 使用框架提供的认证注解（`@PreAuthorize`/`@login_required`/`@UseGuards`）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 公开端点（login、register、health） | 登录、注册、健康检查等端点设计为无需认证 | 确认端点路径为 /login、/register、/health、/actuator/health 等公认公开路径 |
| API Gateway 已完成认证 | 认证在外部网关层完成，请求到达服务时已携带已验证的身份 token/header | 确认网关配置了认证插件，服务仅验证 x-user-id / x-auth-token 等 header |
| 内部路由（不对外暴露） | 仅集群内部通信使用，通过网络策略/防火墙限制访问 | 确认路由绑定到 localhost/内部网络接口，或 Kubernetes 网络策略限制 |
| WebSocket 升级端点 | WebSocket 认证在协议握手时通过 token 参数完成，不走常规认证中间件 | 确认 WebSocket 连接建立时有 token 验证逻辑（如 URL query param 或 first message） |
| 框架级认证中间件全局注册 | 认证中间件在框架初始化时自动注入所有路由，无需在每个Handler上显式声明 | 确认中间件在框架配置中注册为全局中间件（如 app.use(authMiddleware)） |
| 静态资源/资产路径 | 静态文件（CSS/JS/images）无需认证，路径有明确的前缀区分 | 确认路由匹配 /static/**、/assets/**、/public/** 等公开资源路径模式 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: permitAll on sensitive paths
permitAll\(\) .* admin|permitAll\(\) .* manage|permitAll\(\) .* secret
                                                           # → MUST: code_context (安全配置+端点代码)
                                                           # → MUST: judgment_rationale (认证覆盖率分析)
\.antMatchers\("/api/\*\*"\)\.permitAll\(\)               # 过度宽松的通配符覆盖了敏感路径
@PermitAll.*@PostMapping|@PermitAll.*@DeleteMapping       # Jakarta EE 注解绕过

# Python: missing login_required on views
def (admin|dashboard|settings|config):                     # 疑似管理功能
→ 无 @login_required 装饰器                                # 缺少认证检查
                                                           # → SHOULD: data_flow_path (请求处理链)
def \w+\(request\):.*\n(?!.*@login_required)               # 视图函数无认证装饰器

# Go: handler without auth middleware
HandleFunc\(.*(admin|config|secret)                        # 敏感路径
→ 无中间件包装                                                # → SHOULD: call_stack (中间件顺序)

# Auth 逻辑缺陷
if not request\.user\.is_authenticated:                    # 不认证的逻辑反转
if !user\.IsAuthenticated                                  # Go: 不认证的逻辑反转
→ (执行敏感操作)                                             # ↑ 这些实际放行了不认证用户

# === EXCLUDE (不报告) ===
→ /login|/register|/signup|/signin                        # 公认公开端点
→ /health|/ready|/ping|/actuator                           # 健康检查/监控端点
→ @PreAuthorize|@Secured|@RolesAllowed                     # 框架级认证注解
→ @login_required|@permission_required|@authentication_classes  # Django/DRF 认证装饰器
→ app\.Use\(auth|router\.Use\(auth|mux\.Use\(auth          # 全局认证中间件
→ /static/|/assets/|/public/|/favicon                      # 静态资源路径
→ /api/public/|/api/v1/public/                             # 显式公开API前缀
→ @csrf_exempt.*@login_required                            # CSRF豁免但有认证
```
