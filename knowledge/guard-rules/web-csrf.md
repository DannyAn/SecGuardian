---
detector: csrf
severity: high
cwe: CWE-352
language: [java, python, go]
tags: [web, csrf, access-control]
precision: medium
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "web.csrf",
  "type": "guard-rule",
  "namespace": "web",
  "severity": "High",
  "cwe": "CWE-352",
  "cvss": 7.8,
  "confidence": "dynamic",
  "precision": "medium",
  "languages": [
    "java",
    "python",
    "go"
  ],
  "target_functions": [
    "csrf",
    "disable",
    "transfer",
    "transfer_money"
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

攻击者诱导已认证用户点击恶意链接/表单，利用用户的已认证状态执行非预期的状态变更操作（转账、修改密码、删除数据）。CSRF 依赖"浏览器自动携带Cookie"的特性。

**核心原则：所有状态变更的请求（POST/PUT/DELETE）必须包含 CSRF Token 或验证 `Origin`/`Referer` 头。**

## 检测逻辑 (Detection Logic)

### Step 1: Search for endpoints without CSRF protection

**Java (Spring Security):**
```java
// BAD: disabling CSRF completely
http.csrf().disable();

// BAD: public POST endpoint without CSRF token validation
@PostMapping("/api/transfer")
public String transfer(@RequestParam String to, @RequestParam int amount) {
    // No CSRF token check
}
```

**Python (Django):**
```python
# BAD: per-view CSRF exemption
@csrf_exempt
def transfer_money(request):
    pass

# BAD: middleware disabled
MIDDLEWARE = [
    # 'django.middleware.csrf.CsrfViewMiddleware',  # DISABLED
]
```

**Python (Flask):**
```python
# BAD: Flask-WTF CSRF disabled
app.config['WTF_CSRF_ENABLED'] = False
```

**Go (Gin):**
```go
// BAD: no CSRF middleware
r.POST("/transfer", handler)
```

### Step 2: Check for CSRF token validation

```java
// GOOD: Spring Security CSRF enabled by default
// GOOD: Manually validate token on state-changing endpoints
```

### Step 3: Check non-GET endpoints

Focus on POST/PUT/DELETE/PATCH endpoints that change state without token verification.

## 修复指引 (Remediation)

1. 使用框架 CSRF 保护：Spring Security CSRF / Django `{% csrf_token %}` / Express `csurf`
2. 对 API（非浏览器客户端）使用 `Authorization` header 而非 Cookie 认证
3. SameSite Cookie 设置为 `Strict` 或 `Lax`

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：状态变更端点及CSRF保护代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：是否缺少CSRF Token或Origin校验
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：请求到状态变更的完整路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：中间件链和过滤器配置
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：CSRF Token存在性/Cookie属性设置
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：框架CSRF配置是否被全局禁用
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| API-only backend (no browser clients) | CSRF only applies to cookie-based auth | 确认无浏览器客户端，认证方式为Token/API Key而非Cookie |
| Token auth (JWT, OAuth2 Bearer) | CSRF irrelevant for token-based auth | 确认Authorization header在所有状态变更请求中使用 |
| Same-Origin-only endpoints | CORS + Origin check provide alternative protection | 确认CORS配置严格限制同源且Origin/Referer校验存在 |
| Idempotent GET requests | Only state-changing methods need CSRF | 确认该端点仅处理GET请求，无状态变更副作用 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# Java: CSRF disabled
csrf\(\)\.disable\(\)
→ evidence: code_context (Spring Security配置代码)

# Python: CSRF exemption
@csrf_exempt|csrf_exempt|CSRF_ENABLED.*False|WTF_CSRF_ENABLED.*False
→ evidence: variable_state (CSRF配置标志位)

# Go: Missing CSRF middleware
r\.(POST|PUT|DELETE|PATCH)\(
→ evidence: call_stack (路由注册到中间件链)
→ No CSRF middleware in router group
```

### 排除模式 (EXCLUDE)

```
csrf\(\)\.csrfTokenRepository
→ 自定义Token仓库但CSRF保护仍在，无需报告
CsrfViewMiddleware.*['\"]  # 未注释
→ CSRF中间件已启用，无需报告
@app\.before_request.*csrf|@app\.after_request.*csrf
→ 自定义CSRF校验逻辑已实现，无需报告
```
