---
name: secguard-python-ssrf
description: "检测 SSRF — requests.get(user_url) 用户输入未验证"
language: python
topic: [web, ssrf, network]
skill_id: python.ssrf.requests
signal_filter: python.ssrf.requests*
signal_source: call_sites[callee="get|post|request|urlopen|Request|url"]
severity: high
cwe: CWE-918
trigger_functions: [requests.get, requests.post, requests.put, requests.request, urllib.request.urlopen, urllib.urlopen, httpx.get, httpx.post, httpx.AsyncClient, aiohttp.ClientSession.get]
---

# SSRF 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.ssrf.requests` | `call_sites[cat="network"]` | `requests.get`, `urllib.request.urlopen`, `httpx.get`, `aiohttp.ClientSession.get` | High | CWE-918 | `web-ssrf` |

## Scenario 1: 用户控制 URL 请求

### 威胁定义
攻击者通过控制服务端 HTTP 请求的 URL 参数，诱导服务器访问内网服务（AWS/GCP 元数据、Redis、数据库、管理接口）。涉及框架: requests、httpx、aiohttp、urllib。

### 检测逻辑
```python
# BAD: requests.get 用户 URL
resp = requests.get(user_input)

# BAD: urllib 用户 URL
import urllib.request
resp = urllib.request.urlopen(user_input)

# BAD: httpx 用户 URL
import httpx
resp = httpx.get(user_url)

# GOOD: URL 白名单 + 内网 IP 检查
from urllib.parse import urlparse
import socket, ipaddress
parsed = urlparse(user_input)
if parsed.hostname not in ALLOWED_HOSTS:
    raise ValueError()
ip = socket.gethostbyname(parsed.hostname)
if ipaddress.ip_address(ip).is_private:
    raise PermissionError()
```

### 检测模式
- **MATCH**: `requests\.(get|post|put|request)\(.*user\|input\|url\|args\|form\|data` | `urllib\.request\.urlopen\(.*user` | `httpx\.(get|post|AsyncClient)\(.*user`
- **EXCLUDE**: `ALLOWED_HOSTS\|whitelist\|is_private` | URL 来自配置常量 | 白名单 + DNS 校验

### 修复指引
1. URL 白名单（仅允许已知域名）
2. DNS 解析后校验是否为内网 IP
3. 禁止 `file://`/`gopher://`/`dict://` 等非 HTTP 协议
4. 禁止跟随重定向

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — URL 构造及 HTTP 请求代码 |
| judgment_rationale | MUST — URL 是否用户可控、有无验证 |
| data_flow_path | SHOULD — 用户输入到请求的路径 |
| sanitizer_analysis | MAY — 白名单/DNS 校验代码 |

## 输出格式

记录为 finding，标注 `severity: high`，`cwe: CWE-918`。
