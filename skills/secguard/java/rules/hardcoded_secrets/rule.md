---
name: secguard-java-hardcoded-secrets
description: "检测 Java 硬编码密钥/密码/Token — API Key / Password / Secret 字面量赋值"
language: java
topic: [crypto, secrets, credentials]
skill_id: java.crypto.hardcoded-secrets
signal_source: call_sites[callee="getConnection|getPassword|getSecret|getKey|getToken"]
severity: high
cwe: CWE-798
trigger_functions: [password, api_key, secret_key, encryption_key, jwt_secret, private_key, master_key]
---

# hardcoded_secrets 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `crypto.hardcoded-secrets` | `call_sites[cat="crypto"]` | `password`, `api_key`, `secret_key`, `encryption_key`, `jwt_secret` | High | CWE-798 |

## Scenario 1: 敏感凭证字面量赋值

### 威胁定义
API Key、密码、JWT Secret、私钥等敏感凭证硬编码在 Java 源代码中。Spring Boot `application.yml`、`@Value("${secret}")` 占位符安全，但硬编码字面量（`private String password = "admin123"`）进入版本控制后永久暴露。

### 检测逻辑
```java
// BAD: 硬编码字面量赋值
String apiKey = "sk-live-abc123def456";
String password = "admin123";
String jwtSecret = "my-jwt-secret-2024";
final String encryptionKey = "0123456789abcdef";

// BAD: 密码字面量比较
if (password.equals("admin123")) { ... }

// GOOD: 环境变量读取
String dbPassword = System.getenv("DB_PASSWORD");
String apiKey = System.getenv("API_KEY");

// GOOD: Spring @Value 占位符
@Value("${app.jwt.secret}")
private String jwtSecret;
```

### 检测模式
**MATCH**: 敏感变量名（`password|api_key|secret_key|private_key|encryption_key|jwt_secret`）`=` 字符串字面量；密码比较（`.equals("xxx")` 或 `== "xxx"`）

**EXCLUDE**: `System.getenv()` / `@Value("${...}")` 占位符从环境读取；`@Value("${...}")` 占位符语法；变量名为配置项（`_min_length`, `_max_length`, `_name`, `_type`）

### 修复指引
1. 首选：密钥管理服务（AWS KMS / HashiCorp Vault / K8s Secrets）运行时注入
2. 次选：环境变量 + Spring `@Value("${KEY}")`，配置文件不入库
3. 补救：已泄露密钥立即轮换 + Git 历史清除

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 变量声明行及周边代码 |
| judgment_rationale | MUST | 是否为真实凭证 vs 配置项/占位符 |
| data_flow_path | SHOULD | 凭证的来源和用途路径 |

## 输出格式
`[High][CWE-798] {file}:{line} — 硬编码密钥（{variable}）`
