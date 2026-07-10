> **定位**: 定义哪些看似硬编码密钥的场景不应报告为漏洞 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 硬编码密钥例外规则

## 安全模式（不报告）

1. **测试代码**: test/ mock/ fixture/ 目录中的非生产前缀假密钥
2. **占位符**: `${VAR}` / `{{VAR}}` / 全零（`0000...`）/ 重复字符（`xxxx...`）
3. **公开证书**: `BEGIN CERTIFICATE` / `BEGIN PUBLIC KEY` / `BEGIN RSA PUBLIC KEY`
4. **配置名而非值**: 变量名为 `*_name` / `*_type` / `*_min_length` 等配置标识
5. **版本标识**: 仅用于标识产品版本的字符串（如 `API-Version: 1.0`）
6. **示例代码**: examples/ 目录中的演示凭据，含明确注释标记

## 外部密钥管理（不报告）

以下运行时密钥加载模式不视为硬编码，**不报告**：

1. **环境变量检索**: 通过 `getenv("SECRET_KEY")` / `secure_getenv("API_TOKEN")` 从进程环境获取密钥
   - CWE-798 将环境变量视为可接受的密钥存储（非嵌入）
   - 注意：环境变量可被子进程继承，敏感场景应使用 `secure_getenv`
2. **KMS/HSM 密钥查找**: 通过 AWS KMS、Azure Key Vault、Hashicorp Vault 等外部密钥管理服务获取
   ```c
   // 安全：运行时从 KMS 获取，非硬编码
   const char *key = kms_decrypt("alias/prod-key");
   ```
3. **配置文件加载**: 从受保护的配置文件（`/etc/secrets/`, `~/.config/`）读取，而非嵌入源码
   ```c
   // 安全：运行时从外部配置加载
   config_t cfg = config_load("/etc/myapp/secrets.conf");
   const char *key = config_get(cfg, "database.password");
   ```
4. **编译期注入**: 构建系统通过 `-DSECRET_KEY=\"$(cat /secure/key)\"` 注入，密钥不在源码中
   - SEI CERT C MSC41-C 建议：永不将凭证嵌入代码
   - 确认：密钥确实来自外部源（非 Makefile 硬编码）
5. **测试专用令牌**: 含明确标记的测试令牌，且仅在测试构建中使用
   ```c
   // 安全：受 `#ifdef TEST_BUILD` 保护
   #ifdef TEST_BUILD
   static const char *test_token = "test-token-12345";
   #endif
   ```

## 边界情况

1. **默认密码后立即提示修改**: `password = "admin"; // PLEASE CHANGE IMMEDIATELY` → 可接受但有风险，报告并标记
2. **密钥派生种子（固定盐值）**: 固定 salt 用于密钥派生 → 降低强度，报告
3. **内联 SSL 证书指纹**: 用于固定证书验证的 SHA256 指纹 → 不报告（这是安全机制）
4. **开发环境默认凭据**: `minioadmin:minioadmin` 类仅在 DEV/CI 有效的凭据 → 检查 `#ifdef DEBUG` 或构建配置保护，若有条件编译保护则抑制

## CWE 映射

| CWE | 说明 | 本规则覆盖 |
|-----|------|-----------|
| CWE-798 | Use of Hard-coded Credentials | 核心覆盖 |
| CWE-259 | Use of Hard-coded Password | 密码类硬编码 |
| CWE-321 | Use of Hard-coded Cryptographic Key | 密钥类硬编码 |
| CWE-547 | Use of Hard-coded Security-relevant Constants | 安全常量硬编码 |

## SEI CERT C 参考

- **MSC41-C**: Never hard-code sensitive information — 所有凭证必须通过外部机制管理
- **MSC40-C**: Do not violate secure coding practices for the sake of backward compatibility
