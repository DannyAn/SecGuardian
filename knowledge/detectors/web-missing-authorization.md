---
detector: missing-authorization
severity: high
cwe: CWE-862
language: [java, python, go]
tags: [web, authorization, access-control]
---

# 缺失授权检查 (Missing Authorization)

## 威胁定义

已认证用户访问超出其权限的功能或数据——普通用户执行管理员操作。与 IDOR（对象级授权缺失）不同，本检测器关注功能级授权缺失。

**核心原则：每个端点/服务方法必须在执行前验证当前用户的角色/权限。`@PreAuthorize`/`@RolesAllowed`/Django `permission_required` 等注解应全局覆盖。**

## 检测逻辑

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

## 修复指引

1. 每个端点/方法在执行业务逻辑前验证角色权限
2. Spring: `@PreAuthorize("hasRole('ADMIN')")` / Django: `@permission_required`
3. 角色检查在业务逻辑之前执行，不要依赖业务逻辑内部的权限判断

## 误报排除

| 场景 | 原因 |
|------|------|
| 公开 API（登录、注册、密码重置） | 设计上不需要授权 |
| 框架级 Spring Security 已全局配置 | 隐式保护 |
| API Gateway 层已处理授权 | 网关层保护 |
| 仅返回公开数据的端点 | 非敏感信息 |

## 检测模式汇总

```
# 敏感路径 + 无授权
/admin|/api/admin|DELETE|管理
→ 方法上无 @PreAuthorize|@Secured|@admin_required
→ 函数内无 if.*role|if.*admin|if.*permission

# 数据修改操作 + 无授权校验
@PostMapping|@PutMapping|@DeleteMapping|@PatchMapping
→ 无 @PreAuthorize|自定义装饰器
→ 函数内无权限检查

# 跨函数授权不一致
公共函数有授权 → 内部函数跳过 → 外部可通过内部函数绕过
```

## CWE 映射

- CWE-862: Missing Authorization
- CWE-285: Improper Authorization
- CWE-284: Improper Access Control
