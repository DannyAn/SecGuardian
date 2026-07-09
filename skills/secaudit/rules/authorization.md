---
name: authorization
description: 审计权限模型的实现安全性，检测水平越权、垂直越权、IDOR、权限缺失和权限提升路径。当用户请求权限审计、越权检测、IDOR检测、访问控制审查、RBAC/ABAC审计时使用。
category: domain
topic: [web]
severity: High
cwe: CWE-200
mapped_to: OWASP ASVS V4 (Access Control)
cvss: 7.5
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。


# 授权与访问控制安全审计

## 审计概览

授权漏洞是最常见的应用安全漏洞之一（OWASP A01:2021）。审计覆盖：
- **垂直越权**：普通用户执行管理员操作
- **水平越权 (IDOR)**：用户 A 访问用户 B 的数据
- **权限缺失**：需要授权的接口无任何权限检查
- **权限提升**：通过组合操作获取更高权限

## 审计流程

### Phase 1: 权限模型梳理

首先理解系统的授权架构：

```
□ 权限模型: RBAC / ABAC / ACL / ReBAC / 自定义混合
□ 角色定义: 列出所有角色及其权限矩阵
□ 资源类型: 哪些资源需要访问控制（用户数据、订单、文件、管理功能）
□ 操作类型: CRUD + 特殊操作（导出、分享、删除、转让）
□ 检查机制: 中间件 / 注解 / AOP / 手动检查
□ 数据隔离: 租户级 / 用户级 / 组织级
```

### Phase 2: 检查清单

#### 2.1 垂直越权

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 管理接口是否有权限保护 | 列举所有 `/admin` `/manage` `/api/internal` 路径，检查认证+授权 |
| [C] | 权限检查是否可被绕过 | 尝试直接 HTTP 方法修改 (GET→POST)、参数修改、Header 修改 |
| [H] | 敏感操作是否有二次确认 | 删除、转让、导出等操作是否有多因素确认 |
| [H] | 是否有隐藏的管理接口 | 搜索无路由注册但存在的 Controller/Servlet |
| [M] | 角色变更是否有审批流程 | 检查升权操作（赋予管理员角色）是否经过审批 |

#### 2.2 水平越权 (IDOR)

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 资源 ID 是否可枚举 | 遍历 user_id/order_id 等参数，验证是否有归属检查 |
| [C] | 批量操作是否有权限检查 | 批量删除、批量导出是否逐一验证所有权 |
| [H] | 嵌套资源是否验证父资源归属 | `/users/{id}/orders/{oid}` 是否同时验证 user 和 order 的关联 |
| [H] | API 响应是否包含他人数据 | 用户列表 API 是否返回了其他用户的 PII |
| [M] | UUID 是否被误认为是安全的 | 检查是否依赖"不可猜测"而非实际的权限检查 |

#### 2.3 权限缺失

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 所有 Controller/Handler 是否有权限注解 | 扫描所有路由，对比权限注解覆盖度 |
| [H] | 文件/静态资源是否有访问控制 | 是否可通过直接 URL 访问他人上传的文件 |
| [H] | WebSocket/SSE/长连接是否有权限 | 检查连接建立时是否验证权限 |
| [M] | GraphQL 字段级权限 | 检查 resolver 中是否对敏感字段做了权限控制 |

### Phase 3: 常见漏洞模式

#### 模式 1: IDOR — 资源归属缺失

```java
// BAD: 仅验证用户已登录，未验证订单归属
@GetMapping("/api/orders/{orderId}")
public Order getOrder(@PathVariable Long orderId) {
    return orderRepo.findById(orderId);  // 任何登录用户可看任何订单!
}

// GOOD: 验证资源归属
@GetMapping("/api/orders/{orderId}")
public Order getOrder(@PathVariable Long orderId, @CurrentUser User user) {
    Order order = orderRepo.findById(orderId);
    if (!order.getUserId().equals(user.getId())) {
        throw new AccessDeniedException("Not your order");
    }
    return order;
}
```

#### 模式 2: 权限检查遗漏

```python
# BAD: 部分操作缺少权限检查
class UserViewSet(ModelViewSet):
    permission_classes = [IsAuthenticated]

    def list(self, request):          # 列出所有用户 — 有权限检查 ✓
        ...

    def delete(self, request, pk):    # 删除用户 — 依赖装饰器，但装饰器配置错误 ✗
        ...

# GOOD: 每个操作都显式检查
class UserViewSet(ModelViewSet):
    def delete(self, request, pk):
        if not request.user.is_admin:
            raise PermissionDenied()
        ...
```

#### 模式 3: 前端权限检查不可靠

```javascript
// BAD: 仅前端隐藏了管理按钮
if (user.role !== 'admin') {
    document.getElementById('admin-panel').style.display = 'none';
}
// 但后端 /api/admin/* 没有任何权限检查!

// 审计方法: 直接 curl 后端 API，不经过前端
```

#### 模式 4: 租户隔离漏洞

```java
// BAD: 查询中忘记加租户过滤
@GetMapping("/api/documents")
public List<Document> listDocs(@CurrentUser User user) {
    return docRepo.findAll();  // 返回了所有租户的文档!
}

// GOOD: 强制租户过滤
@GetMapping("/api/documents")
public List<Document> listDocs(@CurrentUser User user) {
    return docRepo.findByTenantId(user.getTenantId());
}
```

### Phase 4: 风险评级

| 发现 | CVSS 基准 | 典型分值 |
|------|----------|---------|
| IDOR 可读写他人数据 | AV:N/AC:L/PR:L/UI:N/C:H/I:H | 8.1 High |
| 管理接口无权限保护 | AV:N/AC:L/PR:N/UI:N/C:H/I:H | 9.8 Critical |
| 租户数据泄露 | AV:N/AC:L/PR:L/UI:N/C:H/I:N | 6.5 Medium |
| 权限提升路径 | AV:N/AC:L/PR:L/UI:N/C:H/I:H | 8.8 High |
