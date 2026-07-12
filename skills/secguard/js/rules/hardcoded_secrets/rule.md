---
name: secguard-js-hardcoded_secrets
description: "Detects hardcoded API keys, passwords, JWT secrets, and other credentials in source code"
language: javascript
topic: [crypto, secrets, credentials]
skill_id: js.crypto.hardcoded_secrets
signal_filter: js.crypto.hardcoded*
signal_source: call_sites[category="crypto"]
severity: high
cwe: [CWE-798]
trigger_functions: [api_key, api_secret, password, jwt_secret, secret_key, process.env, JSON.parse, dotenv, config]
---

# hardcoded_secrets 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.hardcoded_secrets` |
| signal_source | `call_sites[cat="crypto"]` |
| trigger_functions | `api_key = "sk-xxx"`, `jwt_secret = "mysecret"`, `password = "abc123"` |
| severity | High |
| CWE | CWE-798 |

## Scenario 1: 硬编码凭证

### 威胁定义

API Key、JWT Secret、数据库密码等敏感凭证硬编码在 JS/TS 源码中，进入 Git 后永久暴露。攻击者可通过源码泄露、CI 日志或供应链攻击获取。

### 检测逻辑

```javascript
// BAD: 硬编码 API Key
const apiKey = 'sk-live-abc123def456';  // 直接暴露

// BAD: 硬编码 JWT Secret
const jwt = jwt.sign({ user: id }, 'mySecretKey123');  // 泄露后可伪造任意 token

// BAD: 硬编码数据库密码
const db = mongoose.connect('mongodb://admin:password123@localhost/db');

// GOOD: 环境变量
const apiKey = process.env.API_KEY;
const jwtSecret = process.env.JWT_SECRET;
```

### 检测模式

```
# MATCH
(password|api_key|api_secret|secret_key|jwt_secret)\s*=\s*"[^"']
mongoose\.connect\(['"].*://.*:.*@  # URL 中含密码
jwt\.sign.*['"]  # JWT 签名密钥
process\.env\s*=\s*{  # 硬编码环境变量

# EXCLUDE
getenv\(|process\.env\.|os\.environ  # 环境变量读取
\$\{\w+\}|\{\{[^}]*\}\}              # 模板变量
*_min_length|*_max_length|*_name     # 配置项非凭证
-----BEGIN CERTIFICATE-----           # 公开证书
```

### 修复指引

1. 密钥管理服务（AWS KMS / HashiCorp Vault / K8s Secrets）
2. 环境变量（`process.env.DB_PASS`），配置文件不入库
3. 已泄露密钥立即轮换 + BFG Repo-Cleaner 清除 Git 历史

## 证据收集指引

- **code_context**: 变量声明/赋值行及周边代码
- **judgment_rationale**: 是否为真实凭证 vs 配置项/占位符

## 输出格式

三段式: Source（变量赋值字面量）→ Propagate（使用该凭证的代码路径）→ Sink（泄露到 Git/日志/客户端）。
