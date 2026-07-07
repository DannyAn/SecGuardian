---
confidence: dynamic
cwe: CWE-798
detector: hardcoded-secrets
language: [c, cpp, java, python, go, js]
precision: very-high
severity: high
tags: [crypto, secrets, credentials]
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "crypto.hardcoded-secrets",
  "type": "guard-rule",
  "namespace": "crypto",
  "severity": "High",
  "cwe": "CWE-798",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "very-high",
  "languages": [
    "c",
    "cpp",
    "java",
    "python",
    "go",
    "js"
  ],
  "target_functions": [
    "_max_length",
    "_min_length",
    "_name",
    "admin_pass",
    "api_key",
    "api_secret",
    "code_context",
    "encryption_key",
    "equals",
    "getenv",
    "judgment_rationale",
    "jwt_secret",
    "length",
    "master_key",
    "passwd",
    "password",
    "private_key",
    "secret_key",
    "strcmp",
    "strlen",
    "strncmp"
  ],
  "match_patterns": [
    "(password|passwd|api_key|api_secret|secret_key|private_key|encryption_key|jwt_secret|admin_pass|master_key)\\s*=\\s*\"[^\"]",
    "(strcmp|strncmp|\\.equals|==)\\s*\\([^)]*\"[^\"]{3,}\"[^)]*\\)"
  ],
  "exclude_patterns": [
    "getenv\\(|System\\.getenv\\(|os\\.environ|process\\.env|os\\.Getenv\\(",
    "-----BEGIN CERTIFICATE-----|-----BEGIN PUBLIC KEY-----",
    "\\$\\{\\w+\\}|\\{\\{[^}]*\\}\\}",
    "*_min_length|*_max_length|*_name|*_type\\s*=",
    "^\\s*\\w+\\s+\\*?\\w+\\s*;|=\\s*\\w+\\(",
    "0x00,\\s*0x00|=\\{0\\}"
  ]
}
```
## 威胁定义 (Threat Definition)

API Key、密码、私钥、Token 等敏感凭证硬编码在源代码中，进入版本控制后永久暴露。攻击者可通过源码泄露、供应链分析或反编译获取这些凭证。

**核心原则：代码中不得包含任何形式的敏感凭证。** 检测时要区分"看起来像秘密"和"真的是秘密"——变量命名线索 + 赋值字面量 + 上下文。

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation Guide)

1. **首选**：密钥管理服务（AWS KMS / HashiCorp Vault / K8s Secrets），运行时注入
2. **次选**：环境变量（`getenv("DB_PASS")` / `process.env.DB_PASS`），配置文件不入库
3. **最低要求**：配置文件模板化（`config.template.json` 入仓库，`config.json` 不入仓库）
4. **补救**：已泄露密钥立即轮换 + Git 历史清除（`git filter-branch` / `BFG Repo-Cleaner`）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `getenv("KEY")` / `System.getenv()` | 运行时读取，非硬编码 | 确认调用的是标准环境变量 API，且变量名在部署文档中有定义 |
| 变量名为配置项 (`password_min_length`, `key_name`) | 非凭证值 | 确认变量值类型为整数/配置常量，非字符串密码 |
| 变量值来自函数返回值 | 非字面量 | 确认赋值右侧为函数调用表达式，非字符串字面量 |
| `-----BEGIN CERTIFICATE-----` / 公钥 | 公开信息 | 确认内容为 X.509 证书或公钥格式（PEM header 匹配） |
| 测试代码中的假凭证 (`"test_key_123"`) | 非生产 — 但 `sk-live-` 格式仍报告 | 确认文件路径匹配 test/mock/fixture 模式，且凭证值不含生产前缀 |
| `${API_KEY}` / `{{ secret }}` 模板变量 | 运行时替换 | 确认为模板占位符语法，非实际凭证值 |
| 仅变量声明无初始化 | 无值不报告 | 确认变量声明语句无赋值表达式 |
| 0x00... 全零数组 | 占位符，非真实密钥 | 确认所有字节均为 0x00 |
| Base64 编码的图片/字体/icons | 非机密数据 | 确认上下文为 UI 资源加载（img src、icon font、CSS background） |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 敏感变量名 + 字符串字面量赋值
(password|passwd|api_key|api_secret|secret_key|private_key|encryption_key|jwt_secret|admin_pass|master_key)\s*=\s*"[^"]
→ 排除 "$\{|"\{\{|getenv\(|System.getenv\(
→ 排除 *_min_length|*_max_length|*_name|*_type\s*=
→ MUST: code_context (变量声明行及周边代码)
→ MUST: judgment_rationale (是否为真实凭证 vs 配置项/占位符)

# 密码字面量比较
(strcmp|strncmp|\.equals|==)\s*\([^)]*"[^"]{3,}"[^)]*\)
→ 排除 strlen|\.length|\.size
→ 排除 "$\{|"\{\{
→ MUST: code_context (比较操作的完整上下文)
→ MUST: judgment_rationale (硬编码密码 vs 格式/长度验证)

# 高熵字符串（需额外上下文确认）
→ (base64长度≥40 或 hex长度≥32) AND (变量名/注释暗示密钥)
→ MUST: judgment_rationale (熵分析 + 上下文确认)

# === EXCLUDE (不报告) ===

# 环境变量读取
getenv\(|System\.getenv\(|os\.environ|process\.env|os\.Getenv\(

# 公开证书
-----BEGIN CERTIFICATE-----|-----BEGIN PUBLIC KEY-----

# 模板变量
\$\{\w+\}|\{\{[^}]*\}\}

# 测试文件（路径匹配）
# — *_test.c, *_test.cpp, Test*.java, test_*.py
# — *test*/, *mock*/, *fixture*/ 目录

# 配置项变量名（非凭证）
*_min_length|*_max_length|*_name|*_type\s*=

# 仅声明无初始化或来自函数调用
^\s*\w+\s+\*?\w+\s*;|=\s*\w+\(

# 全零占位数组
0x00,\s*0x00|=\{0\}
```
