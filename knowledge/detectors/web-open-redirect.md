---
detector: open-redirect
severity: medium
cwe: CWE-601
language: [java, python, go]
tags: [web, redirect, phishing]
precision: medium
confidence: dynamic
---

# 开放重定向 (Open Redirect)

## 威胁定义 (Threat Definition)

用户可控制的 URL 作为重定向目标且未经验证，攻击者可利用此漏洞将用户重定向到钓鱼网站，窃取凭证或令牌。常用于鱼叉式钓鱼和社会工程攻击。

**核心原则：重定向目标必须在服务端白名单中，或使用相对路径/内部路由标识符而非完整URL。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索用户输入驱动的重定向 (User-Controlled Redirect Targets)

```java
// BAD: redirect URL from request parameter
@GetMapping("/redirect")
public String redirect(@RequestParam String url) {
    return "redirect:" + url;  // Open redirect!
}

// BAD: forward with user input
request.getRequestDispatcher(userPath).forward(request, response);
```

```python
# BAD: redirect with user-controlled URL
def redirect(request):
    next_url = request.GET.get('next')
    return redirect(next_url)  # Open redirect!
```

```go
// BAD: redirect with user-supplied path
http.Redirect(w, r, r.URL.Query().Get("redirect"), http.StatusFound)
```

### Step 2: 安全替代 (Safe Alternatives)

```go
// GOOD: validate against allowlist
safeRedirects := map[string]bool{"/dashboard": true, "/profile": true}
if safeRedirects[r.URL.Query().Get("redirect")] {
    http.Redirect(w, r, r.URL.Query().Get("redirect"), http.StatusFound)
}
```

```python
# GOOD: verify against allowed domains
ALLOWED_DOMAINS = {'example.com', 'app.example.com'}
parsed = urlparse(next_url)
if parsed.netloc in ALLOWED_DOMAINS:
    return redirect(next_url)
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：重定向语句的完整代码行及其所在函数体，标注用户输入来源（request param / query string / body / header）和重定向目标变量名
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析用户输入到重定向目标的数据流是否经过验证——是否存在 allowlist/denylist 检查、URL 解析和域名验证、路径规范化；若存在验证，分析其充分性（如正则是否可绕过）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入入口（param/query/header/body） → 中间加工处理（拼接/解码/trim） → 重定向执行点，标注每步对 URL 值的变换
      → findings.evidence.data_flow_path
- [ ] **call_stack**：Controller/Handler 入口 → 重定向执行函数调用链，确认中间件/拦截器是否已做URL验证
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：重定向目标URL的最终值（含协议/域名/路径/查询参数）、是否经过 url.parse / URL 构造器解析
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在全局重定向过滤器/拦截器（如 Spring Interceptor / Django Middleware / Go middleware），以及该过滤器的 allowlist 配置
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 使用服务端维护的重定向目标白名单（URL → Token 映射）
2. 使用相对路径或内部路由标识符（`redirect=/dashboard`）替代完整 URL
3. 验证目标 URL 的域名在白名单中

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 重定向目标仅为硬编码路径 | 无用户可控输入，攻击者无法修改重定向目标 | 确认重定向参数为字符串字面量或编译期常量 |
| Allowlist 验证到位 | 重定向前已验证目标 URL 在白名单中（域名白名单或路径白名单） | 确认白名单逻辑在重定向执行前，且白名单覆盖所有可重定向目标 |
| Hash fragments（非 URL 重定向） | 仅使用 URL hash fragment 做前端路由跳转，服务端不处理 | 确认重定向值为 "#" 开头或仅用于前端 SPA 路由 |
| 相对路径重定向 | 仅允许相对路径（如 "/dashboard"），不含协议和域名，无法跳转到外部站点 | 确认重定向值以 "/" 开头且不含 "://" 或 "//" |
| 内部服务间重定向 | 仅用于微服务间内部通信，不暴露给终端用户 | 确认重定向端点仅被内部服务调用，有网络层隔离或内部认证 |
| URL Token 映射 | 用户提交的是 token/UUID，服务端查找对应的内部 URL | 确认用户输入为不透明标识符，非直接URL |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: redirect with user input
redirect:.*\+|sendRedirect\(.*request|forward\(.*user     # 用户输入拼接到重定向
                                                           # → MUST: code_context (重定向语句+用户输入来源)
                                                           # → MUST: judgment_rationale (验证充分性分析)
return "redirect:" + request\.\w+\(|ModelAndView.*redirect # Spring redirect: 前缀拼接

# Python: redirect with user URL
redirect\(request\.GET|redirect\(request\.POST             # Django/Flask 用户输入直传
redirect\(.*request\.args|redirect\(.*request\.form         # Flask request 数据
HttpResponseRedirect\(.*request\.                          # Django 用户输入

# Go: redirect with user param
http\.Redirect.*r\.URL\.Query\(\)\.Get\(                  # 查询参数直传到重定向
http\.Redirect.*c\.Query\(|http\.Redirect.*c\.Param\(     # Gin/Echo 框架

# === EXCLUDE (不报告) ===
→ redirect.*= "/"|redirect.*= "/[a-z]"                    # 硬编码相对路径
→ urlparse\(|URL\(.*\.netloc|\.hostname                   # URL解析后进行域名检查
→ ALLOWED_DOMAINS|ALLOWED_HOSTS|safeRedirects|allowedRedirects  # 白名单验证存在
→ redirect\("#"|redirect\("/#"                            # Hash-only 前端路由
→ redirect\(tokenMap\[|redirect\(urlMap\[                  # Token→URL 映射查找
→ redirect.*startsWith\("/"\)                              # 仅允许相对路径
→ 重定向目标为 .*://内部域名.* 且无外部输入                     # 内部服务间硬编码重定向
```
