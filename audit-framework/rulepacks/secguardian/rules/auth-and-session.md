---
name: auth-and-session
description: 审计认证机制和会话管理的安全性，检测凭证泄露、会话固定、认证绕过等常见漏洞。当用户请求认证审计、会话管理审查、登录安全检测、凭证安全、OAuth/SSO安全时使用。
category: domain
topic: [web]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 认证与会话管理安全审计

## 审计概览

认证是系统安全的第一道防线。本次审计覆盖三个方面：
- **认证机制**：用户如何证明身份
- **会话管理**：认证后如何维持身份
- **凭证安全**：密码、Token、密钥如何保护

## 审计流程

### Phase 1: 资产识别

首先识别系统中所有与认证相关的组件：

```
□ 登录入口（Web 表单、API 端点、SSO 回调）
□ 注册/密码重置/找回密码流程
□ 会话存储机制（Cookie、JWT、服务端 Session）
□ 凭证存储位置（数据库、配置文件、密钥管理服务）
□ 多因素认证（MFA/TOTP/SMS/硬件 Key）
□ 外部身份提供商（OAuth、SAML、LDAP）
□ 登出/会话终止逻辑
```

**关键问题**：列出所有用户可以"证明身份"的路径。攻击者只需找到最弱的一条。

### Phase 2: 检查清单

按严重度分层检查。每个检查项标注：[C] Critical / [H] High / [M] Medium。

#### 2.1 认证机制

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否存在认证绕过路径 | 检查所有 Controller/Handler 的认证注解/中间件覆盖 |
| [C] | 登录接口是否有速率限制 | 检查是否使用 rate limiter，失败的登录是否延迟响应 |
| [C] | 是否存在硬编码的管理员凭证 | grep `admin.*password\|root.*passwd\|superuser.*secret` |
| [H] | 密码策略是否执行 | 最小长度≥8、复杂度要求、禁用常见密码 |
| [H] | 失败登录是否返回模糊信息 | "用户名或密码错误" 而非 "用户名不存在" |
| [H] | 注册流程是否验证邮箱/手机 | 检查是否存在未验证账户可登录的路径 |
| [H] | MFA 是否正确实施 | 检查 MFA 是否可以绕过（直接访问受保护 URL） |
| [M] | 密码重置令牌是否安全 | Token 是否随机（≥128bit）、是否过期（≤15min）、是否一次性 |
| [M] | 是否支持 passkey/WebAuthn | 检查是否实现了防钓鱼的认证方式 |

#### 2.2 会话管理

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 会话 Token 是否具有足够熵 | JWT: 检查签名算法（禁止 none/HS256 用弱密钥） |
| [C] | 会话是否可被固定 | 检查登录前后 session ID 是否轮换 |
| [H] | 会话是否有超时机制 | 绝对超时（≤12h）和空闲超时（≤30min） |
| [H] | 登出是否真正销毁会话 | 检查服务端是否删除 session，客户端是否清除 Cookie |
| [H] | Cookie 属性是否安全 | HttpOnly + Secure + SameSite=Strict/Lax |
| [H] | 并发登录控制 | 同一账户多设备登录是否需要通知或限制 |
| [M] | 会话是否绑定设备指纹 | IP 变更、User-Agent 变更是否需要重新认证 |
| [M] | Remember-Me Token 是否安全 | 检查 token 熵、存储位置、轮换策略 |

#### 2.3 凭证存储

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 密码是否使用安全哈希 | bcrypt/scrypt/argon2，禁止 MD5/SHA-1/SHA-256 单次 |
| [C] | API Key 是否硬编码 | grep 常见 key 前缀 + regex 高熵字符串 |
| [H] | 密钥是否与代码分离 | 检查配置文件和环境变量 vs 密钥管理服务 |
| [H] | 数据库连接串是否含明文密码 | 检查 JDBC URL、连接配置 |
| [M] | 日志是否包含凭证 | grep `password\|token\|secret\|authorization` 在日志输出中 |

### Phase 3: 常见漏洞模式

#### 模式 1: 认证中间件覆盖不全

```java
// BAD: 只有部分端点有 @Authenticated
@GetMapping("/api/public")      // 公开
public Data getPublic() { ... }

@GetMapping("/api/admin/users") // BAD: 忘记加认证注解!
public List<User> getUsers() { ... }

// 审计方法: 对比所有 Controller 的路由和认证注解
```

```python
# BAD: Flask 装饰器顺序错误，auth 未生效
@app.route("/admin")
@login_required                  # 装饰器在路由之后不生效
def admin():
    ...

# GOOD
@app.route("/admin")
@login_required
def admin():
    ...
```

#### 模式 2: JWT 算法降级攻击

```python
# BAD: 接受 alg=none 或 HS256 用弱密钥
jwt.decode(token, verify=True)   # 如果库允许 alg=none 则危险

# GOOD: 指定允许的算法
jwt.decode(token, key=public_key, algorithms=["RS256"])
```

#### 模式 3: 会话固定

```java
// BAD: 登录后不更换 session ID
request.getSession().setAttribute("user", user);  // session ID 不变

// GOOD: 登录后更换 session ID
request.changeSessionId();
request.getSession().setAttribute("user", user);
```

#### 模式 4: 密码重置 Token 可预测

```python
# BAD: 使用时间戳或可预测值
reset_token = hashlib.md5(str(time.time())).hexdigest()

# GOOD: 使用加密安全随机数
reset_token = secrets.token_urlsafe(32)
```

### Phase 4: 风险评级

| 发现 | CVSS 基准 | 典型分值 |
|------|----------|---------|
| 认证绕过 | AV:N/AC:L/PR:N/UI:N | 9.8 Critical |
| 会话固定 | AV:N/AC:L/PR:N/UI:R | 6.5 Medium |
| 弱密码哈希 (MD5) | AV:N/AC:H/PR:L/UI:N | 7.5 High |
| 硬编码密钥 | AV:N/AC:L/PR:N/UI:N | 9.8 Critical |
| 缺少会话超时 | AV:P/AC:L/PR:N/UI:N | 2.4 Low |

## 输出格式

```markdown
## 认证与会话管理审计报告

### 总览
- 审计范围: {模块/服务名称}
- 发现总数: X (Critical: X, High: X, Medium: X, Low: X)

### 发现清单

#### [C-01] 认证中间件覆盖不全
- 文件: AdminController.java:42
- 描述: /api/admin/users 端点缺少 @Authenticated 注解
- 影响: 未认证用户可直接访问管理接口
- CVSS: 9.8
- 修复: 添加 @Authenticated 注解或在 SecurityConfig 中配置全局拦截

#### [H-01] 弱密码哈希算法
- 文件: UserService.java:156
- 描述: 使用 SHA-256 单次哈希存储密码，未加盐
- 影响: 数据库泄露后密码可被彩虹表破解
- 修复: 迁移到 bcrypt，cost factor ≥ 10
```
