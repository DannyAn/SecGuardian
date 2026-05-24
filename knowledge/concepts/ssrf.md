---
category: concept
threat_type: injection
severity: high
cwe: CWE-918
owasp: A10:2021 - Server-Side Request Forgery
---

# 服务端请求伪造 (SSRF)

攻击者诱导服务器向内部网络或自身发起请求，绕过防火墙访问内部服务。

## 检测策略

### 核心原则
**用户可控的 URL/地址不应被服务端直接请求。**

1. **URL 作为请求目标**
   - HTTP 客户端（curl、requests、HttpClient）的 URL 参数来自用户输入
   - 文件包含/下载的远程地址可控

2. **URL 重定向链**
   - 服务端跟随重定向时可能跳转到内网地址
   - 禁用重定向跟随或验证每个跳转目标

3. **DNS Rebinding**
   - 首次 DNS 解析返回公网 IP，二次解析返回内网 IP

### 误报排除
- 硬编码的固定外部地址
- 经过白名单验证的域名
- 内网地址在允许列表中

## 修复指引

1. **首选**：禁用用户完全控制的 URL 请求
2. **次选**：严格 DNS 白名单 + 禁止内网 IP 段
3. **补充**：禁止跟随重定向 / 禁用非 HTTP 协议（file://、gopher://）
