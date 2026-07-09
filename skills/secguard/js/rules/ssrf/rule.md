---
name: secguard-js-ssrf
description: "Detects server-side request forgery where user input controls outbound HTTP requests"
language: javascript
topic: [ssrf, network, web]
skill_id: js.ssrf
signal_filter: js.ssrf*
signal_source: call_sites[category="http"]
severity: high
cwe: [CWE-918]
trigger_functions: [http.get, http.request, axios.get, axios.post, fetch, node-fetch, got, request]
---

# ssrf 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.ssrf` |
| signal_source | `call_sites[cat="http"]` |
| trigger_functions | `http.get(userURL)`, `axios.get(req.query.url)`, `fetch(userInput)`, `got(url)` |
| severity | High |
| CWE | CWE-918 |

## Scenario 1: URL 可控的 SSRF

### 威胁定义

攻击者诱导服务器向内部网络发起请求，绕过防火墙访问云元数据（169.254.169.254）、内网数据库和管理接口。

### 检测逻辑

```javascript
// BAD: axios 请求用户可控 URL
const response = await axios.get(req.query.url);
// 攻击: ?url=http://169.254.169.254/latest/meta-data/

// BAD: fetch 用户可控 URL
app.get('/proxy', async (req, res) => {
    const response = await fetch(req.body.targetUrl);
    const data = await response.text();
    res.send(data);  // SSRF + 数据回显
});

// GOOD: URL 白名单校验
const ALLOWED = ['https://api.example.com'];
const url = new URL(req.query.url);
if (!ALLOWED.includes(url.origin)) throw new Error('Blocked');
```

### 检测模式

```
# MATCH
axios\.(get|post|put|request)\(.*req\.|fetch\(.*req\.
http\.(get|request)\(.*req\.|got\(.*req\.
new\s+URL\(.*req\. 且后续无校验
request\(.*req\.url|request\(.*req\.query

# EXCLUDE
url\.hostname(.*allowlist|.*ALLOWED)           # 白名单校验
url\.protocol\s*===\s*['"]https['"]            # 协议限制
ipaddr\.isPrivate|isLoopback                   # 内网 IP 检测
ALLOWED_HOSTS\.(includes|has)
```

### 修复指引

1. 禁用用户完全控制的 URL 请求 / URL 白名单
2. 禁止内网 IP 段（127.0.0.0/8, 10.0.0.0/8, 169.254.169.254）
3. 禁用重定向跟随，禁用 `file://`/`gopher://`/`dict://`

## 证据收集指引

- **code_context**: URL 构造及 HTTP 请求发起代码
- **judgment_rationale**: URL 是否来自用户可控输入，是否有 host 白名单/内网过滤

## 输出格式

三段式: Source（req.query.url/req.body.targetUrl）→ Propagate（URL 解析/拼接）→ Sink（axios.get/fetch/http.get）。
