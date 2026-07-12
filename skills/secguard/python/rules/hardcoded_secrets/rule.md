---
name: secguard-python-hardcoded-secrets
description: "检测硬编码密钥 — API Key / SECRET_KEY / Password 硬编码"
language: python
topic: [crypto, secrets, credentials]
skill_id: python.crypto.hardcoded-secrets
signal_filter: python.crypto.hardcoded*
signal_source: call_sites[callee="token_hex|token_bytes|urandom"]+string_literals
severity: high
cwe: CWE-798
trigger_functions: [api_key, api_secret, SECRET_KEY, password, secret_key, encryption_key, jwt_secret, access_key, auth_token, db_password, token]
---

# 硬编码密钥检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.hardcoded-secrets.key` | `call_sites[cat="crypto"]` | `SECRET_KEY`, `api_key`, `password`, `secret_key` | High | CWE-798 | `hardcoded-secrets` |

## Scenario 1: 敏感凭证字符串字面量

### 威胁定义
API Key、密码、SECRET_KEY、JWT secret 等敏感凭证以字符串字面量形式写在源码中，进入版本控制后永久暴露。涉及框架: Django SECRET_KEY、Flask secret_key、JWT 密钥、数据库密码。

### 检测逻辑
```python
# BAD: Django SECRET_KEY 硬编码
SECRET_KEY = 'django-insecure-abc123...'

# BAD: API Key 硬编码
api_key = 'sk-live-xxxxxxxxxxxx'

# BAD: Flask secret_key 硬编码
app.secret_key = 'my-secret-key'

# BAD: 数据库密码硬编码
DATABASES = {
    'default': {
        'PASSWORD': 'root123',
    }
}

# GOOD: 环境变量
import os
SECRET_KEY = os.environ['SECRET_KEY']
api_key = os.getenv('API_KEY')
app.secret_key = os.environ.get('FLASK_SECRET_KEY')
```

### 检测模式
- **MATCH**: `SECRET_KEY\s*=\s*['"][^'"]+` | `(api_key|api_secret|secret_key|password|jwt_secret|encryption_key|admin_pass)\s*=\s*['"][^'"]+`
- **EXCLUDE**: `os\.environ\|os\.getenv\|os\.environ\.get` | `process\.env` | `getenv\(` | `['"][$]{\w+}`（模板占位符） | 测试文件假凭证

### 修复指引
1. 使用环境变量 `os.environ['KEY']`
2. 密钥管理服务（AWS KMS / Vault / K8s Secrets）
3. Django `python-decouple` / python-dotenv
4. 已泄漏密钥立即轮换 + `git filter-branch` 清理

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 变量名 + 赋值行 |
| judgment_rationale | MUST — 真实凭证 vs 测试/配置项 |
| sanitizer_analysis | MAY — 是否有 getenv 调用替代硬编码 |

## 输出格式

记录为 finding，标注 `severity: high`，`cwe: CWE-798`。
