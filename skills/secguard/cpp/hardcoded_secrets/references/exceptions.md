# 硬编码密钥例外规则

## 安全模式（不报告）

1. **测试代码**: test/ mock/ fixture/ 目录中的非生产前缀假密钥
2. **占位符**: `${VAR}` / `{{VAR}}` / 全零（`0000...`）/ 重复字符（`xxxx...`）
3. **公开证书**: `BEGIN CERTIFICATE` / `BEGIN PUBLIC KEY` / `BEGIN RSA PUBLIC KEY`
4. **配置名而非值**: 变量名为 `*_name` / `*_type` / `*_min_length` 等配置标识
5. **版本标识**: 仅用于标识产品版本的字符串（如 `API-Version: 1.0`）
6. **示例代码**: examples/ 目录中的演示凭据，含明确注释标记

## 边界情况

1. **默认密码后立即提示修改**: `password = "admin"; // PLEASE CHANGE IMMEDIATELY` → 可接受但有风险，报告并标记
2. **密钥派生种子（固定盐值）**: 固定 salt 用于密钥派生 → 降低强度，报告
3. **内联 SSL 证书指纹**: 用于固定证书验证的 SHA256 指纹 → 不报告（这是安全机制）
