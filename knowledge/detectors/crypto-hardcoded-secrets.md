---
detector: hardcoded-secrets
severity: high
cwe: CWE-798
language: [c, cpp, java, python, go, js]
tags: [crypto, secrets, credentials]
---

# 硬编码密钥/凭证 (Hardcoded Secrets)

## Indexer Input

- `symbols.variables`: 直接读取变量列表，筛选名称含 `password`/`api_key`/`secret`/`token`/`key` 且值为字符串字面量的变量
- 执行方式：遍历变量符号表 → 精准读取对应行检查赋值，**不扫描无敏感变量的文件**

## 威胁定义

API Key、密码、私钥、Token 等敏感凭证硬编码在源代码中，进入版本控制后永久暴露。攻击者可通过源码泄露、供应链分析或反编译获取这些凭证。

**核心原则：代码中不得包含任何形式的敏感凭证。** 检测时要区分"看起来像秘密"和"真的是秘密"——变量命名线索 + 赋值字面量 + 上下文。

## 检测逻辑

### Step 1: 变量命名 + 字面量赋值（高置信度）

当**同时满足**以下两个条件时报告：

**条件 A — 敏感变量名**（精确匹配，非子串）：
```
password, passwd, pass, pwd, secret, api_key, api_secret,
access_key, secret_key, private_key, encryption_key, jwt_secret,
db_password, db_pass, admin_pass, master_key, signing_key
```

**条件 B — 赋值为字符串字面量**：
```c
const char *password = "abc123";        // 报告
String apiKey = "sk-live-xxx";          // 报告
secret_key = "my-secret-here"           // 报告
```

**不报告**（变量名匹配但并非赋值字面量）：
```c
char *password = getenv("DB_PASS");     // 从环境变量读取 — 不报告
String apiKey = System.getenv("KEY");   // 运行时获取 — 不报告
const int password_min_length = 8;      // 配置值，非密码 — 不报告
char key_name[32] = "id_rsa";          // 密钥名称，非密钥内容 — 不报告
```

### Step 2: 密码/凭证比较（高置信度）

```
# C/C++: 字符串与字面量比较
strcmp(input, "admin123") == 0          // 报告：硬编码验证密码
strncmp(pass, "secret", 6)              // 报告

# Java:
if (password.equals("admin123"))        // 报告
input == "master_key"                   // 报告 (Python/JS)

# 不报告: 长度/格式验证
strlen(password) >= 8                   // 仅检查长度 — 不报告
password.length() > 0                   // 仅检查非空 — 不报告
```

### Step 3: 高熵字符串（低置信度，需额外上下文）

**仅当同时满足以下条件时报告**：

1. Base64 长度 ≥ 40 字符 或 Hex 长度 ≥ 32 字符
2. 字符串不在以下排除列表中：

```
# 不报告: 公开的证书/公钥
-----BEGIN CERTIFICATE----- / -----BEGIN PUBLIC KEY-----
# 不报告: 编码的非机密数据（字体、图标、图片 base64）
# 不报告: OSS 许可文件、已知的公钥指纹
```

3. 且**变量名或注释暗示这是密钥/凭证**

### Step 4: 测试/示例文件排除

路径匹配以下模式时**不报告**：
```
*test*/   *_test.c   *_test.cpp   Test*.java   test_*.py
*mock*/   *fixture*/   *example*/   *demo*/   *sample*/
```
例外：如果测试文件中包含真实生产凭证格式（如有效的 `sk-live-` 前缀），仍报告。

## 修复指引

1. **首选**：密钥管理服务（AWS KMS / HashiCorp Vault / K8s Secrets），运行时注入
2. **次选**：环境变量（`getenv("DB_PASS")` / `process.env.DB_PASS`），配置文件不入库
3. **最低要求**：配置文件模板化（`config.template.json` 入仓库，`config.json` 不入仓库）
4. **补救**：已泄露密钥立即轮换 + Git 历史清除（`git filter-branch` / `BFG Repo-Cleaner`）

## 误报排除

| 场景 | 原因 |
|------|------|
| `getenv("KEY")` / `System.getenv()` | 运行时读取，非硬编码 |
| 变量名为配置项 (`password_min_length`, `key_name`) | 非凭证值 |
| 变量值来自函数返回值 | 非字面量 |
| `-----BEGIN CERTIFICATE-----` / 公钥 | 公开信息 |
| 测试代码中的假凭证 (`"test_key_123"`) | 非生产 — 但 `sk-live-` 格式仍报告 |
| `${API_KEY}` / `{{ secret }}` 模板变量 | 运行时替换 |
| 仅变量声明无初始化 | 无值不报告 |
| 0x00... 全零数组 | 占位符，非真实密钥 |
| Base64 编码的图片/字体/icons | 非机密数据 |

## 检测模式汇总

```
# === MUST REPORT (高置信度) ===

# 敏感变量名 + 字符串字面量赋值
(password|passwd|api_key|api_secret|secret_key|private_key|encryption_key|jwt_secret|admin_pass|master_key)\s*=\s*"[^"]
→ 排除 "$\{|"\{\{|getenv\(|System.getenv\(
→ 排除 *_min_length|*_max_length|*_name|*_type\s*=

# 密码字面量比较
(strcmp|strncmp|\.equals|==)\s*\([^)]*"[^"]{3,}"[^)]*\)
→ 排除 strlen|\.length|\.size
→ 排除 "$\{|"\{\{

# === MUST NOT REPORT (白名单) ===

# 环境变量读取
getenv\(|System\.getenv\(|os\.environ|process\.env|os\.Getenv\(

# 公开证书
-----BEGIN CERTIFICATE-----|-----BEGIN PUBLIC KEY-----

# 模板变量
\$\{\w+\}|\{\{[^}]*\}\}

# 测试文件（路径匹配）
# — *_test.c, *_test.cpp, Test*.java, test_*.py
# — *test*/, *mock*/, *fixture*/ 目录
```
