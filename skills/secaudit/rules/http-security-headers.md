---
name: http-security-headers
description: 审计 HTTP 响应安全头配置，检测缺失、错误配置或相互冲突的安全头，确保浏览器安全策略正确实施。当用户请求HTTP安全头审计、CSP配置审查、CORS安全、浏览器安全策略、HSTS检测时使用。
category: domain
topic: [web]
severity: High
cwe: CWE-200
cvss: 7.5
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。


# HTTP 安全头审计

## 审计概览

HTTP 安全头是 Web 应用安全的第一道浏览器端防线。正确配置可以防御 XSS、点击劫持、MIME 嗅探、信息泄露等攻击。

## 审计流程

### Phase 1: 响应头采集

采集目标应用的所有 HTTP 响应头：

```bash
# 采集主页和关键 API 的响应头
curl -sI https://target.com | grep -iE 'content-security|x-frame|x-content|strict-transport|referrer|permissions'
```

### Phase 2: 检查清单

#### 2.1 Content-Security-Policy (CSP)

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | CSP 是否存在 | 检查是否有 Content-Security-Policy 头 |
| [C] | CSP 是否包含 `unsafe-inline` | `script-src 'unsafe-inline'` 使大部分 XSS 防护失效 |
| [C] | CSP 是否包含 `unsafe-eval` | 允许 eval() 等动态代码执行 |
| [H] | default-src 是否为 `none` 或安全值 | 默认拒绝，按需放开 |
| [H] | CSP 是否使用了 nonce/hash | `script-src 'nonce-{random}'` 比 `unsafe-inline` 安全 |
| [M] | report-uri 是否配置 | 是否有 CSP 违规报告端点 |

```text
# BAD: CSP 过于宽松
Content-Security-Policy: default-src *; script-src 'unsafe-inline' 'unsafe-eval' *

# GOOD: CSP 严格
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{random}'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'
```

#### 2.2 HTTPS 相关安全头

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | HSTS 是否配置 | Strict-Transport-Security 头是否存在 |
| [H] | max-age 是否 ≥ 31536000 (1年) | 短期 HSTS 容易被 strip |
| [H] | 是否包含 includeSubDomains | 子域名也需要 HTTPS |
| [M] | 是否配置 preload | 是否在 hstspreload.org 提交 |

```text
# GOOD
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

#### 2.3 内容类型安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | X-Content-Type-Options | 是否设置为 `nosniff`，阻止 MIME 嗅探 |
| [H] | 下载文件是否设置正确的 Content-Type | 避免浏览器将 HTML 文件作为 text/plain 渲染 |

#### 2.4 点击劫持防护

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | X-Frame-Options 或 CSP frame-ancestors | 检查是否阻止页面被 iframe 嵌入 |
| [H] | 是否同时使用了 X-Frame-Options 和 frame-ancestors | CSP frame-ancestors 优先，但兼容性考虑两者都设 |

#### 2.5 其他安全头

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | Referrer-Policy | 是否限制了 Referer 信息泄露 |
| [H] | Permissions-Policy | 是否限制了浏览器 API（摄像头、麦克风、定位） |
| [M] | Cross-Origin-Opener-Policy (COOP) | 是否防护 Spectre 类侧信道攻击 |
| [M] | Cross-Origin-Resource-Policy (CORP) | 是否限制跨域资源加载 |
| [M] | Cross-Origin-Embedder-Policy (COEP) | 是否配合 COOP 启用跨域隔离 |

### Phase 3: CORS 审计

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | Access-Control-Allow-Origin 是否为 `*` + credentials | 反射型 Origin 配合 credentials=true 极度危险 |
| [H] | 是否反射 Origin 头 | 检查服务端是否直接返回请求中的 Origin 值 |
| [H] | 是否允许 null Origin | `null` Origin 可被 sandboxed iframe/sandbox 利用 |
| [M] | Access-Control-Allow-Methods | 是否不必要地开放了 PUT/DELETE/PATCH |
| [M] | Access-Control-Allow-Headers | 是否不必要地开放了 Authorization 等敏感头 |
| [M] | Access-Control-Allow-Credentials | 是否必须开启（如果不需要跨域 cookie 就不要开启） |

```java
// BAD: 极度危险的 CORS 配置
response.setHeader("Access-Control-Allow-Origin", request.getHeader("Origin"));
response.setHeader("Access-Control-Allow-Credentials", "true");
// 任何域都可以带着用户 Cookie 发起跨域请求!

// GOOD: 白名单 Origin
String origin = request.getHeader("Origin");
if (ALLOWED_ORIGINS.contains(origin)) {
    response.setHeader("Access-Control-Allow-Origin", origin);
    response.setHeader("Access-Control-Allow-Credentials", "true");
}
```

### Phase 4: 检测工具

```bash
# Mozilla Observatory
curl -s https://http-observatory.security.mozilla.org/api/v1/analyze?host=target.com

# securityheaders.com style check
curl -sI https://target.com | grep -E '^[A-Z].*-.*:'
```

### Phase 5: 输出格式

```markdown
## HTTP 安全头审计报告

### 评分: D (60/100)

| 检查项 | 期望 | 实际 | 结果 |
|--------|------|------|------|
| CSP | 严格策略 | 缺失 | ✗ Critical |
| HSTS | max-age≥1年 | max-age=3600 | ✗ Low |
| X-Frame-Options | DENY/SAMEORIGIN | 缺失 | ✗ High |
| X-Content-Type-Options | nosniff | nosniff | ✓ |
| Referrer-Policy | strict-origin | 缺失 | ✗ Medium |

### 修复优先级
1. [Critical] 添加 CSP: `default-src 'self'; script-src 'self'; object-src 'none'`
2. [High] 添加 `X-Frame-Options: DENY`
3. [Medium] 添加 `Referrer-Policy: strict-origin-when-cross-origin`
```
