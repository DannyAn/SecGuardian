---
name: logging-and-monitoring
description: 审计安全日志的完整性、可追溯性、防篡改和监控覆盖度，检测日志注入、敏感信息泄露和安全事件遗漏。当用户请求日志安全审计、监控覆盖审查、安全事件追溯、日志注入检测、SIEM配置审查时使用。
category: domain
topic: [system]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 日志与监控安全审计

## 审计概览

日志和监控是安全事件的"事后追溯"基础，也是合规的底线要求。审计覆盖：
- **日志完整性**：该记录的事件是否都记录了
- **日志注入**：用户输入是否会污染日志
- **敏感信息泄露**：日志中是否包含凭证/PII
- **日志安全存储**：日志是否防篡改、防删除
- **监控覆盖**：关键安全事件是否触发告警

## 审计流程

### Phase 1: 日志事件覆盖检查

检查以下安全事件的日志记录情况：

```
认证事件 (必须记录):
□ 登录成功/失败
□ 登出
□ 密码修改
□ 密码重置请求/完成
□ MFA 成功/失败
□ 账户锁定/解锁

授权事件 (必须记录):
□ 权限变更（角色分配/撤销）
□ 越权访问被拒绝
□ 特权操作执行

数据访问 (按需记录):
□ 敏感数据查询（用户列表、订单导出）
□ 批量操作（批量删除、批量导出）
□ 管理员查看用户数据

异常事件 (必须记录):
□ 输入验证失败（可能的攻击尝试）
□ 速率限制触发
□ 异常 HTTP 状态码（4xx/5xx 激增）
□ 异常流量模式
```

### Phase 2: 检查清单

#### 2.1 日志完整性

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 认证事件是否记录 | 检查登录/登出/密码变更的日志输出 |
| [C] | 授权失败是否记录 | 403/权限拒绝是否产生日志 |
| [H] | 输入验证失败是否记录 | WAF/过滤器拒绝的请求是否记录 |
| [H] | 是否记录了足够的上下文 | IP、User-Agent、Timestamp、User ID、Action |
| [M] | 是否记录了请求追踪 ID | Trace ID 关联跨服务日志 |

#### 2.2 日志注入防护

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 用户输入是否直接写入日志 | `log.info(userInput)` 可能注入换行伪造日志条目 |
| [H] | 是否有日志换行过滤 | 检查是否过滤了 `\r\n`、`\n`、`%0d%0a` |
| [M] | 是否有日志级别注入 | 用户输入是否可能触发错误的日志级别 |

```java
// BAD: 日志注入
log.info("User login: " + username);
// username = "admin\n[CRITICAL] System compromised"
// 日志输出:
// [INFO] User login: admin
// [CRITICAL] System compromised ← 伪造的日志条目!

// GOOD: 参数化日志 + 数据脱敏
log.info("User login: username={}", sanitize(username));
```

#### 2.3 敏感信息泄露

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 日志中是否有明文密码 | grep 日志中的 password/passwd 字段值 |
| [C] | 日志中是否有 Token/Key | grep 日志中的 Authorization 头、API Key |
| [H] | 请求体是否被全文记录 | 检查 HTTP request logging 中间件配置 |
| [H] | 异常堆栈是否返回客户端 | 检查错误响应中是否包含敏感路径/代码 |
| [H] | 日志中是否有 PII | 手机号、身份证、银行卡号是否脱敏 |

```python
# BAD: 日志中间件记录了完整请求体
@app.middleware
async def log_requests(request):
    logger.info(f"Request: {await request.body()}")  # 包含 password!
    
# GOOD: 选择性记录，过滤敏感字段
@app.middleware
async def log_requests(request):
    safe_body = {k: v for k, v in body.items() 
                 if k not in ['password', 'token', 'secret']}
    logger.info(f"Request: {safe_body}")
```

#### 2.4 日志安全存储

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 日志是否防篡改 | 是否使用了 append-only 存储 / WORM |
| [H] | 日志是否有保留期限 | 是否符合合规要求（≥90天到≥1年） |
| [H] | 日志访问是否有权限控制 | 谁可以查看/删除日志 |
| [M] | 日志是否集中存储 | 分散在容器/实例中的日志可能丢失 |
| [M] | 日志是否以结构化格式输出 | JSON 格式便于 SIEM 解析 |

#### 2.5 监控告警

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否对关键事件设置告警 | 暴力破解、异常登录、权限变更 |
| [H] | 是否有基线异常检测 | 异常时间登录、异常地理位置、异常流量 |
| [H] | 告警是否有响应流程 | 谁接收告警、响应 SLA |
| [M] | 是否定期演练 | 告警是否真的有人响应 |

### Phase 3: 输出格式

```markdown
## 日志与监控审计报告

### 日志完整性评估

| 安全事件 | 是否记录 | 记录内容 |
|---------|---------|---------|
| 登录成功 | ✓ | username, IP, timestamp, user-agent |
| 登录失败 | ✓ | username, IP, reason, timestamp |
| 密码变更 | ✗ | 未记录 — 缺失关键审计事件 |
| 权限提升 | ✗ | 仅记录了 SQL UPDATE |
| 数据导出 | ✓ | user, export_type, record_count |

### 发现清单

#### [C-01] 密码变更未记录
- 影响: 账户被接管无法追溯
- 修复: 在 UserService.changePassword() 添加审计日志

#### [C-02] 日志中包含 JWT Token
- 位置: APIGateway 请求日志
- 示例: `Authorization: Bearer eyJhbGci...`
- 影响: 日志系统被攻破后 Token 泄露
- 修复: 中间件过滤 Authorization 头
```
