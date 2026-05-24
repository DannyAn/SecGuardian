---
category: concept
threat_type: secrets
severity: critical
cwe: CWE-798
owasp: A07:2021 - Identification and Authentication Failures
---

# 硬编码密钥 (Hardcoded Secrets)

API Key、密码、私钥、Token 等敏感凭证硬编码在源代码中，进入版本控制后永久暴露。

## 检测策略

### 核心原则
**代码中不得包含任何形式的敏感凭证。** 检测高熵字符串和已知模式。

1. **高熵字符串模式**
   - Base64 编码的长字符串（≥20 字符）
   - Hex 编码的长字符串
   - 符合 JWT/PEM/SSH Key 格式的字符串

2. **已知前缀模式**
   - `sk-` / `pk-`（Stripe/OpenAI 风格 API Key）
   - `AKIA`（AWS Access Key）
   - `eyJ`（JWT Header）
   - `-----BEGIN`（PEM 格式密钥）

3. **命名线索**
   - 变量名包含：password, secret, key, token, api_key, private
   - 配置文件中的 credential 字段

### 误报排除
- 测试用例中的 mock/dummy 凭证
- 示例代码中明确标注的占位符
- 环境变量名引用（`os.getenv("KEY")` 而非 KEY 的值）

## 修复指引

1. **首选**：使用密钥管理服务（AWS KMS、HashiCorp Vault、K8s Secrets）
2. **次选**：环境变量注入，运行时读取
3. **补救**：已泄露密钥立即轮换 + 从 Git 历史中清除
