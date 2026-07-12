---
name: secguard-go-ssrf
description: "Detect server-side request forgery via http.Get/http.Post with user URL — attackers redirect internal services"
language: go
topic: [web, network]
skill_id: go.web.ssrf
signal_filter: go.web.ssrf*
signal_source: call_sites[callee="Get|Post|Do|NewRequest|Dial|Listen"]
severity: high
cwe: [CWE-918]
trigger_functions: [http.Get, http.Post, http.NewRequest, http.Client.Do, httputil.NewSingleHostReverseProxy, url.Parse]
---

# ssrf 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.web.ssrf` |
| signal_filter | `go.web.ssrf*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `http.Get`, `http.Post`, `http.NewRequest`, `http.Client.Do`, `httputil.NewSingleHostReverseProxy`, `httputil.ReverseProxy` |
| 默认严重度 | High |
| CWE | CWE-918 (Server-Side Request Forgery) |
| Guard-rule | `web-ssrf` |

## Scenario 1: 用户 URL 直接请求

### 威胁定义

Go 中 `http.Get(userURL)` 如果 URL 来自用户输入，攻击者可构造请求访问内网服务（云元数据 `169.254.169.254`、内网数据库、管理接口）。`httputil.ReverseProxy` 如果目标来自用户输入同样可被 SSRF 利用。

**核心原则：用户可控的 URL/地址不应被服务端直接发起 HTTP 请求。**

### 检测逻辑

```go
// 脆弱 — 用户 URL 直接请求
resp, err := http.Get(userURL)

// 脆弱 — ReverseProxy 用户目标
url, _ := url.Parse(userURL)
proxy := httputil.NewSingleHostReverseProxy(url)

// 脆弱 — http.Client 发请求
req, _ := http.NewRequest("GET", userURL, nil)
client.Do(req)

// 安全 — URL 验证 + HTTPS 白名单
u, err := url.Parse(userURL)
if err != nil || u.Scheme != "https" {
    return errors.New("https only")
}
if !isAllowedHost(u.Host) {
    return errors.New("host not allowed")
}

// 安全 — 禁止内网 IP
ips, _ := net.LookupIP(u.Hostname())
for _, ip := range ips {
    if ip.IsPrivate() || ip.IsLoopback() {
        return errors.New("internal IP blocked")
    }
}
```

### 检测模式

```
# MATCH（触发检测）
→ http.Get(userParam) — URL 来自用户输入
→ http.NewRequest(method, userURL, body) — URL 来自用户
→ httputil.NewSingleHostReverseProxy(url.Parse(userURL)) — 代理目标来自用户
→ http.Client.Do(req) 中 req.URL 来自用户构造

# EXCLUDE（不报告）
→ URL 有 Scheme+Host 双重验证（https only + 白名单）
→ URL 来自编译期常量
→ 有内网 IP 黑名单检查（net.IP.IsPrivate）
→ ReverseProxy 目标为硬编码内部服务地址
```

### 修复指引

1. URL Scheme 白名单（仅允许 `https`）
2. DNS Host 白名单或内网 IP 黑名单（`net.IP.IsPrivate` / `IsLoopback`）
3. 禁止跟随重定向，禁用非 HTTP 协议（`file://`, `gopher://`）

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | URL 构造及 HTTP 请求发起代码 |
| judgment_rationale | MUST | URL 是否来自用户可控输入；是否有白名单验证 |
| data_flow_path | SHOULD | 用户输入 → URL 解析 → HTTP 请求的完整路径 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
