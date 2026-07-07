---
name: secguard-cpp-hardcoded_secrets
description: "Detects hardcoded cryptographic keys, passwords, API tokens, and other secrets in C/C++ source code"
category: language-specific
language: cpp
topic: [crypto]
signal_source: static_analysis[pattern_high_entropy_strings, variable_naming_heuristics]
---

# Hardcoded Secrets 检视算子

## 元数据

- id: crypto.hardcoded_secrets
- severity: critical
- cwe: CWE-798
- category: crypto
- signal_source: (无 call_site — 静态分析模式)

## 信号预筛

本 skill 不由 call_sites 驱动。信号来源为静态代码分析：
1. 变量命名启发: 敏感变量名（password, secret, key, token, api_key）赋值字符串字面量
2. 高熵字符串: Base64 编码 ≥ 40 字符、Hex 字符串 ≥ 32 字符
3. 密码比较: strcmp/strncmp 与字符串字面量比较密码/密钥
4. 加密 API 的密钥参数为字面量: AES_set_encrypt_key 传入字符串、DES_set_key 传入字符串
5. 连接字符串含嵌入式凭据: jdbc://user:pass@host、mysql://user:pass@host 等

## 检视协议

### Step 1: 信号确认

基于静态分析扫描以下模式：

**模式 A — 敏感变量名 + 字面量赋值**

```c
const char *password = "abc123";           // MATCH
char *api_key = "sk-live-abc123def456";    // MATCH
static const uint8_t aes_key[] = {0x01, ...};  // MATCH（密钥材料数组）
char secret[32] = "my-secret-key";         // MATCH
```

排除: 变量名为配置项（password_min_length）、值来自 getenv/函数调用

```c
char *pass = getenv("DB_PASS");            // EXCLUDE: 运行时读取
int password_min_length = 8;               // EXCLUDE: 配置常量
```

**模式 B — 密码字面量比较**

```c
strcmp(input, "admin123") == 0             // MATCH: 硬编码验证密码
strncmp(pass, "secret!", 6)                // MATCH
```

排除: strlen/length 检查（仅长度验证，非密码比较）

```c
strlen(password) >= 8                      // EXCLUDE: 仅长度检查
```

**模式 C — 加密 Key 参数为字面量**

```c
AES_set_encrypt_key((const uint8_t*)"1234567890123456", 128, &key);  // MATCH
DES_set_key(&des_key, (const_DES_cblock*)"8bytekey");                 // MATCH
```

**模式 D — 连接字符串嵌入式凭据**

```c
#define DB_URL "mysql://admin:secret@localhost:3306/db"  // MATCH
char conn[] = "jdbc:postgresql://host:5432/db?user=user&password=pass"; // MATCH
```

### Step 2: 证据链构建 (Source→Propagate→Sink)

- Source: 字符串字面量赋值位置、strcmp 比较位置
- Propagate: 变量传递、函数参数传递、全局变量存储
- Sink: 加密 API 调用（AES_set_encrypt_key、DES_set_key 等）、网络发送（send/write with key）、日志输出（printf with key）、连接字符串使用

### Step 3: 参数审计

对每个匹配，进行以下审计：

1. **变量名语义分析**: 变量名是否明确表明其持有机密数据（password, secret, key, token, credential）？若只是配置项名或枚举值，可能是误报。
2. **值特征分析**: 字符串是否具有密钥特征（高熵、特定格式前缀如 sk-live-/AKIA/github_pat）？简短的常见单词（"password", "admin", "test"）可能是测试数据。
3. **使用上下文分析**: 该值最终流向何处？流向加密 API/网络认证/数据库连接 → 真实密钥；流向调试输出/长度验证 → 可能是误报。
4. **文件路径分析**: 是否在 test/ / mock/ / example/ 目录？测试代码中的假密钥通常抑制，但带有生产前缀（sk-live- / AKIA）的仍报告。

### Step 4: 跨函数补证 (max depth 1)

当密钥变量作为参数跨函数传递时，追踪目标函数内部的使用方式。深度 1 层。

见 `references/cross-function.md`。

### Step 5: 5 轮反思

1. 匹配的是硬编码的字面量还是运行时读取的值（getenv/函数调用/文件读取）？后者不报告。
2. 变量名是否明确标识其为凭证（password/secret/key/token）？如仅是配置项（*_min_length/*_name/*_type），是误报。
3. 文件是否在 test/mock/fixture/demo 目录？测试目录中的（非生产前缀）假凭证可抑制。
4. 值是否为模板变量占位符（${VAR} / {{VAR}} / 全零 / 重复字符）？是则抑制。
5. 是否为公开证书/公钥（BEGIN CERTIFICATE / BEGIN PUBLIC KEY）？是则抑制。

## 参考文件

- [规则模式](./references/rule.md) — 脆弱 vs 安全代码模式
- [例外规则](./references/exceptions.md) — 误报抑制规则
- [跨函数追踪](./references/cross-function.md) — 跨函数密钥追踪 (max depth 1)
- [误报策略](./references/false-positive.md) — 误报抑制策略
