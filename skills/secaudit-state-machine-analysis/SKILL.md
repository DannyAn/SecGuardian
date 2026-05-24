---
name: secaudit-state-machine-analysis
description: 分析系统状态转换逻辑的安全性，检测非法的状态跃迁路径，发现认证绕过、权限提升和业务逻辑漏洞
category: analysis
---

# 状态机分析 (State Machine Analysis)

## 分析方法概述

很多安全漏洞不是代码错误，而是**状态跃迁逻辑的设计缺陷**。攻击者通过非预期的状态转换序列，绕过安全控制。

典型攻击模式：
- 跳过支付步骤直接进入"已支付"状态
- 绕过邮箱验证进入"已激活"状态
- 在"待审核"状态下执行需要"已通过"权限的操作

## 分析流程

### Phase 1: 状态枚举

识别系统中所有可能的状态：

```
枚举方法:
1. 搜索 enum / const 定义：
   grep "enum.*Status|enum.*State|const.*_STATUS|const.*_STATE"
2. 搜索数据库字段：
   SELECT DISTINCT status FROM orders/users/...
3. 搜索状态转换代码中的硬编码字符串
4. 阅读业务流程文档（PRD、设计文档）
```

**常见状态模式的审计关注点：**

| 业务场景 | 典型状态 | 安全敏感转换 |
|---------|---------|------------|
| 用户注册 | 未注册→待验证→已激活→已禁用 | 跳过验证直接激活 |
| 订单处理 | 待支付→已支付→已发货→已完成 | 跳过支付 |
| 审批流程 | 待提交→待审批→已通过/已驳回 | 自审批、越级审批 |
| 账户生命周期 | 正常→冻结→注销 | 冻结状态下操作 |
| 密码重置 | 请求→Token 验证→新密码设置 | Token 重用 |

### Phase 2: 转换规则验证

对每个状态转换函数，检查转换前的**前置条件**：

```java
// BAD: 无前置条件检查的状态转换
public void activateUser(Long userId) {
    user.setStatus(Status.ACTIVE);  // 直接激活，跳过验证！
}

// GOOD: 带前置条件的状态转换
public void activateUser(Long userId) {
    User user = userRepo.findById(userId);
    if (user.getStatus() != Status.PENDING_VERIFICATION) {
        throw new IllegalStateException("Cannot activate from " + user.getStatus());
    }
    if (!user.isEmailVerified()) {
        throw new SecurityException("Email not verified");
    }
    user.setStatus(Status.ACTIVE);
}
```

**检查点：**
- 每个状态转换是否检查了当前状态
- 每个转换是否有相应的权限检查
- 是否存在绕过前置条件的路径（API 直接调用、内部 RPC）
- 批量转换是否验证了每个元素的当前状态

### Phase 3: 攻击路径枚举

对关键业务目标，穷举所有可能的状态跃迁路径：

```
目标: 从"未登录"状态到达"管理员"状态

路径 1: 注册 → 登录 (正常)
  攻击路径: 注册 → SQL 注入修改 role 字段 → 登录成为管理员

路径 2: 注册 → 邮箱验证 → 登录 (正常)
  攻击路径: 注册 → 篡改验证链接中的 token → 激活他人账户

路径 3: 密码重置 → 新密码 → 登录 (正常)
  攻击路径: 密码重置 → 猜测/暴力破解重置 token → 接管账户

路径 4: 系统错误 → 回退到不安全状态
  攻击路径: 交易失败 → 状态回滚时未撤销权限 → 保留越权状态
```

### Phase 4: 并发状态安全

检查状态转换在高并发下的安全性：

```java
// BAD: 竞态条件——检查和转换不是原子的
if (order.getStatus() == Status.PENDING) {    // Time T1
    // 另一个线程在 T1 和 T2 之间也通过了检查!
    order.setStatus(Status.PAID);             // Time T2
}

// GOOD: 原子比较并交换
int updated = jdbc.update(
    "UPDATE orders SET status = 'PAID' WHERE id = ? AND status = 'PENDING'",
    orderId
);
if (updated == 0) {
    throw new ConcurrentModificationException();
}
```

### Phase 5: 输出

```markdown
## 状态机安全分析报告

### 总览
- 审计的状态机: X 个 (用户、订单、审批...)
- 发现的状态跃迁漏洞: X 个

### 状态转换表

| 当前状态 | 目标状态 | 前置条件 | 权限 | 漏洞 |
|---------|---------|---------|------|------|
| PENDING | ACTIVE | 邮箱验证 | 用户自操作 | 缺少当前状态检查 ✓ |
| PENDING | ACTIVE | - | 管理员手动 | 跳过了验证流程 |
| ACTIVE | ADMIN | 管理员审批 | 其他管理员 | 自提权漏洞 |

### 发现清单

#### [C-01] 用户激活跳过邮箱验证
- 函数: UserController.activateUser()
- 问题: 未检查 emailVerified 字段
- 攻击: POST /api/users/{id}/activate 可直接激活任意用户
- CVSS: 8.1
```
