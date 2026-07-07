---
detector: missing-authorization
severity: high
cwe: CWE-862
cvss: 7.8
language: [java, python, go]
tags: [web, authorization, access-control]
precision: high
confidence: dynamic
target_functions: [admin, admin_users, code_context, deleteUser, ecured, eleteMapping, findById, hasAdminRole, hasRole, judgment_rationale, listUsers, ostMapping, reAuthorize, role, route, utMapping]
match_patterns: [/admin|/api/admin|DELETE|管理, @PostMapping|@PutMapping|@DeleteMapping|@PatchMapping, 公共函数有授权 → 内部函数跳过 → 外部可通过内部函数绕过]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

已认证用户访问超出其权限的功能或数据——普通用户执行管理员操作。与 IDOR（对象级授权缺失）不同，本检测器关注功能级授权缺失。

**核心原则：每个端点/服务方法必须在执行前验证当前用户的角色/权限。`@PreAuthorize`/`@RolesAllowed`/Django `permission_required` 等注解应全局覆盖。**

## 检测逻辑 (Detection Logic)

### Step 1: 识别需授权访问的端点

```java
// Java
@GetMapping("/api/admin/users")          // 需 ADMIN 角色
@PostMapping("/api/delete-user")         // 需 ADMIN 角色
@DeleteMapping("/api/orders/{id}")       // 需认证 + 自有权
```

```python
# Python Flask
@app.route("/api/admin/dashboard")
@app.route("/api/users/delete", methods=["POST"])
```

```go
// Go
http.HandleFunc("/api/admin/settings", handler)
http.HandleFunc("/api/users/delete", handler)
```

### Step 2: 检查是否存在授权注解/检查

```java
// BAD: 无授权注解
@GetMapping("/api/admin/users")          // 任何人都可访问
public String listUsers() { ... }

// GOOD: 有授权检查
@PreAuthorize("hasRole('ADMIN')")
@GetMapping("/api/admin/users")
public String listUsers() { ... }
```

```python
# BAD: 无授权检查
@app.route("/api/admin/users")
def admin_users():
    return "sensitive data"

# GOOD: 有角色检查
@app.route("/api/admin/users")
@admin_required           # 或自定义装饰器
def admin_users():
    return "sensitive data"
```

### Step 3: 检查管理员路径是否正确保护

```
BAD pattern: /api/admin/* 无 @PreAuthorize/Auth check
BAD pattern: 管理后台 /admin/ 无 session 验证
BAD pattern: DELETE API 无角色检查
```

### Step 4: 检查授权绕过模式

```java
// BAD: 授权检查在数据查询之后
User user = userRepo.findById(id);         // 先查
if (!currentUser.hasAdminRole()) { ... }   // 后判断
// TOCTOU: 检查和数据访问顺序反了

// GOOD: 授权检查在操作之前
@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(Long id) { ... }
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：敏感端点/服务方法的完整代码，包含路由映射（@GetMapping/@PostMapping/@app.route/HandleFunc）、方法签名以及所有注解/装饰器（@PreAuthorize/@RolesAllowed/@login_required 等）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析端点是否被授权机制保护——方法上是否有授权注解、路径是否被全局 Filter/Interceptor/Middleware 覆盖、函数体内是否有角色/权限的条件判断；确认检查是否在业务逻辑执行之前（非 TOCTOU 反序）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：请求从 HTTP 入口 → 认证 Filter/Interceptor → 授权检查点 → 业务逻辑的完整数据流，标注授权检查是否存在及其位置（注解/中间件/函数体内）
      → findings.evidence.data_flow_path
- [ ] **call_stack**：中间件链的完整顺序——AuthenticationFilter → AuthorizationFilter → Controller/Handler，确认授权在认证之后、业务逻辑之前
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：当前用户的角色/权限集合、端点所需的角色要求、Spring Security 配置中的 .hasRole()/.hasAuthority() 规则
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：全局 SecurityConfig 是否配置了 .anyRequest().authenticated() 或 .anyRequest().hasRole()、API Gateway 层是否有统一授权策略
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 每个端点/方法在执行业务逻辑前验证角色权限
2. Spring: `@PreAuthorize("hasRole('ADMIN')")` / Django: `@permission_required`
3. 角色检查在业务逻辑之前执行，不要依赖业务逻辑内部的权限判断

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 公开 API（登录、注册、密码重置） | 设计上不需要授权 | 确认端点文档标注为 "public"，且 spring security 配置中对这些路径使用 .permitAll() |
| 框架级 Spring Security 已全局配置 | 隐式保护 | 确认 SecurityConfig 中有 .anyRequest().authenticated() 或 .hasRole() 全局规则 |
| API Gateway 层已处理授权 | 网关层保护 | 确认网关配置了路由级授权策略，且后端服务不直接暴露公网 |
| 仅返回公开数据的端点 | 非敏感信息 | 确认端点返回的数据结构中无用户私有信息、内部系统信息或管理员数据 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 敏感路径 + 无授权
/admin|/api/admin|DELETE|管理
                                                       # → MUST: code_context (端点路由+方法注解)
→ 方法上无 @PreAuthorize|@Secured|@admin_required
→ 函数内无 if.*role|if.*admin|if.*permission
                                                       # → MUST: judgment_rationale (授权检查完整性分析)

# 数据修改操作 + 无授权校验
@PostMapping|@PutMapping|@DeleteMapping|@PatchMapping
→ 无 @PreAuthorize|自定义装饰器
→ 函数内无权限检查

# 跨函数授权不一致
公共函数有授权 → 内部函数跳过 → 外部可通过内部函数绕过

# === EXCLUDE (不报告) ===
→ @PreAuthorize|@RolesAllowed|@Secured            # 框架授权注解
→ @admin_required|@permission_required             # 自定义装饰器
→ hasRole|hasAuthority|hasPermission               # 函数内权限检查
→ SecurityConfig.*authenticated|permitAll           # 全局安全配置
→ @PermitAll|@DenyAll                               # JEE 安全注解
→ \.antMatchers.*permitAll                          # 显式公开路径
```
