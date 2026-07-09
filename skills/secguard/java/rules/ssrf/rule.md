---
name: secguard-java-ssrf
description: "检测 Java SSRF — HttpURLConnection / RestTemplate / WebClient URL 来自用户输入"
language: java
topic: [web, ssrf, network]
skill_id: java.ssrf.open-redirect
signal_source: call_sites[cat="http"]
severity: high
cwe: CWE-918
trigger_functions: [openConnection, getForObject, exchange, uri, RestTemplate, WebClient, HttpURLConnection]
---

# ssrf 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.ssrf.open-redirect` | `call_sites[cat="http"]` | `openConnection`, `getForObject`, `exchange`, `uri`, `RestTemplate`, `WebClient` | High | CWE-918 |

## Scenario 1: 用户输入控制出站请求 URL

### 威胁定义
攻击者诱导服务器向内部网络发起请求，绕过防火墙访问云元数据（`169.254.169.254`）、内网数据库或管理接口。Spring RestTemplate / WebClient 是 Java 中常见 SSRF 入口。

### 检测逻辑
```java
// BAD: HttpURLConnection 用户 URL
URL url = new URL(request.getParameter("url"));
HttpURLConnection conn = (HttpURLConnection) url.openConnection();

// BAD: RestTemplate 用户 URL
restTemplate.getForObject(userInput, String.class);

// BAD: WebClient 用户 URL
webClient.get().uri(userInput).retrieve().bodyToMono(String.class);

// GOOD: URL 白名单校验
URI uri = new URI(request.getParameter("url"));
if (!ALLOWED_HOSTS.contains(uri.getHost())) {
    throw new SecurityException();
}
```

### 检测模式
**MATCH**: `new URL(.*(getParameter|user|input)` + `openConnection()`；`RestTemplate.getForObject(.*(getParameter|user|input)`；`WebClient.*uri(.*(getParameter|user|input)`

**EXCLUDE**: URL 来自白名单常量（`ALLOWED_HOSTS.contains`）；Schema 校验（scheme=https only）+ Host 白名单双层防御

### 修复指引
1. 首选：禁用用户完全控制 URL 的请求，使用 URL 白名单
2. 次选：严格 DNS 白名单 + 禁止内网 IP 段（`127.0.0.0/8`, `10.0.0.0/8`, `169.254.169.254`）
3. 禁止重定向跟随 + 禁用非 HTTP 协议（`file://`, `gopher://`, `dict://`）

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | URL 构造及 HTTP 请求发起代码 |
| judgment_rationale | MUST | URL 是否来自用户可控输入 |
| data_flow_path | SHOULD | 用户输入到 HTTP 请求的完整路径 |
| sanitizer_analysis | SHOULD | 白名单 / 内网 IP 过滤分析 |

## 输出格式
`[High][CWE-918] {file}:{line} — SSRF（{client}）`
