---
detector: ssrf
severity: high
cwe: CWE-918
language: [java, python, go]
tags: [web, ssrf, network]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "web.ssrf",
  "type": "guard-rule",
  "namespace": "web",
  "severity": "High",
  "cwe": "CWE-918",
  "cvss": 7.8,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "java",
    "python",
    "go"
  ],
  "target_functions": [
    "contains",
    "get",
    "getForObject",
    "getHost",
    "gethostbyname",
    "ip_address",
    "openConnection",
    "retrieve",
    "uri",
    "urlopen",
    "urlparse"
  ],
  "match_patterns": [],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

攻击者诱导服务器向内部网络或自身发起请求，绕过防火墙访问内部服务（云元数据、内网数据库、管理接口）。

**核心原则：用户可控的 URL/地址不应被服务端直接请求。** 覆盖 URL 直接请求、重定向链跟随、DNS Rebinding 三种攻击模式。

## 检测逻辑 (Detection Logic)

### Step 1: Search for dangerous HTTP request patterns

**Java:**
```java
// BAD: user URL directly to HTTP client
URL url = new URL(userInput);
HttpURLConnection conn = (HttpURLConnection) url.openConnection();

// BAD: RestTemplate with user URL
restTemplate.getForObject(userInput, String.class);

// BAD: WebClient with user URL
webClient.get().uri(userInput).retrieve();
```

**Python:**
```python
# BAD: requests with user URL
requests.get(user_input)

# BAD: urllib with user URL
urllib.request.urlopen(user_input)
```

**Go:**
```go
// BAD: http.Get with user URL
http.Get(userURL)

// BAD: ReverseProxy with user target
httputil.NewSingleHostReverseProxy(url.Parse(userURL))
```

### Step 2: Safe alternatives

```java
// GOOD: Validate URL against allowlist
URI uri = new URI(userInput);
if (!ALLOWED_HOSTS.contains(uri.getHost())) {
    throw new SecurityException();
}
```

```python
# GOOD: Validate against internal IP blocklist
import ipaddress
parsed = urlparse(user_input)
ip = socket.gethostbyname(parsed.hostname)
if ipaddress.ip_address(ip).is_private:
    raise ValueError("Internal IP blocked")
```

```go
// GOOD: URL validation + allowlist
u, _ := url.Parse(userURL)
if u.Scheme != "https" {
    return errors.New("https only")
}
```

## 修复指引 (Remediation)

1. **首选**：禁用用户完全控制的 URL 请求
2. **次选**：严格 DNS 白名单 + 禁止内网 IP 段（127.0.0.0/8, 10.0.0.0/8, 169.254.169.254）
3. **补充**：禁止跟随重定向 / 禁用非 HTTP 协议（file://、gopher://、dict://）

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：URL 构造及 HTTP 请求发起代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：URL 是否来自用户可控输入
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入→URL 解析→HTTP 请求的完整路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：从请求入口到 HTTP 客户端的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：URL 值/主机白名单/DNS 解析结果
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否有 allowlist 验证或内网 IP 过滤
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|----------|--------|--------|
| URL from allowlist (validated against known-good hosts) | Explicitly allowed | 提供 allowlist 常量定义及 host 校验代码 |
| URL constructed from constants (not user-controlled) | No injection path | 提供 URL 拼接来源为编译期常量的证明 |
| Schema validation (https only + host allowlist) | Multiple layers of defense | 提供 schema 校验 + host allowlist 双层防御代码 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# Java
new URL\(.*user|restTemplate.*get.*user|WebClient.*uri.*user
→ evidence: code_context, data_flow_path

# Python
requests\.(get|post|put)\(.*user|urlopen\(.*user
→ evidence: code_context, data_flow_path

# Go
http\.(Get|Post|NewRequest)\(.*user|url\.Parse\(.*user
→ evidence: code_context

# ReverseProxy 用户目标
httputil\.NewSingleHostReverseProxy\(.*user|httputil\.ReverseProxy
→ evidence: code_context, judgment_rationale
```

### 排除模式 (EXCLUDE)

```
# URL 来自已验证白名单
→ evidence: sanitizer_analysis (allowlist 验证存在)

# URL 由编译期常量构造
→ evidence: judgment_rationale (非用户可控来源)

# Schema 校验 + host 白名单双层防御
→ evidence: sanitizer_analysis (多层防护已实施)
```
