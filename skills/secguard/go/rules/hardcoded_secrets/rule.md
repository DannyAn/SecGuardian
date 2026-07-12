---
name: secguard-go-hardcoded-secrets
description: "Detect hardcoded cryptographic keys, passwords, API tokens, and JWT secrets in Go source code"
language: go
topic: [crypto, secrets]
skill_id: go.crypto.secrets
signal_filter: go.crypto.secrets*
signal_source: call_sites[callee="Sum|New|Sign|Verify|GenerateKey"]+string_literals
severity: high
cwe: [CWE-798]
trigger_functions: [os.Getenv, os.LookupEnv, flag]
---

# hardcoded_secrets 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.crypto.secrets` |
| signal_filter | `go.crypto.secrets*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | 变量赋值模式（非函数调用驱动） |
| 默认严重度 | High |
| CWE | CWE-798 (Use of Hardcoded Credentials) |
| Guard-rule | `crypto-hardcoded-secrets` |

## Scenario 1: 敏感变量名 + 字符串字面量赋值

### 威胁定义

API Key、密码、JWT Secret、私钥等敏感凭证硬编码在 Go 源代码中。攻击者可通过源码泄露、供应链分析或反编译获取。Go 中常见的硬编码模式是变量赋值或 `var`/`const` 声明中的字符串字面量。

**核心原则：敏感凭证必须从环境变量（`os.Getenv`）、密钥管理服务或配置文件注入，不得出现在代码中。**

### 检测逻辑

```go
// 脆弱 — 硬编码密码
const dbPassword = "admin123"

// 脆弱 — 硬编码 API Key
var apiKey = "sk-live-abc123def456"

// 脆弱 — 硬编码 JWT Secret
jwtSecret := "my-secret-key"

// 脆弱 — 字面量比较
if input == "secretpassword" { ... }

// 安全 — 环境变量读取
dbPassword := os.Getenv("DB_PASSWORD")

// 安全 — 配置文件
apiKey := config.APIKey

// 安全 — 密钥管理服务
secret, _ := vault.GetSecret("api-key")
```

### 检测模式

```
# MATCH（触发检测）
→ 变量名匹配 password/passwd/api_key/secret/jwt_secret/private_key + 字符串字面量赋值
→ const/var 声明中包含密码/密钥字符串字面量
→ 字符串比较（== / strings.EqualFold）中操作数为硬编码密码字面量

# EXCLUDE（不报告）
→ os.Getenv / os.LookupEnv 环境变量读取
→ flag.String / flag 命令行参数
→ 测试文件中的假凭证（*_test.go）
→ 公开证书内容（-----BEGIN CERTIFICATE-----）
→ 占位符值（"your-api-key-here"）
```

### 修复指引

1. 使用 `os.Getenv("KEY")` 从环境变量读取
2. 密钥管理服务（AWS KMS / HashiCorp Vault）运行时注入
3. 已泄露的密钥立即轮换 + Git 历史清除（`git filter-branch`）

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 变量声明行及周边代码 |
| judgment_rationale | MUST | 是否为真实凭证 vs 配置项/占位符 |
| data_flow_path | SHOULD | 凭证从定义到使用的完整数据流 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
