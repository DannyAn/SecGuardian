---
detector: hardcoded-secrets
severity: high
cwe: CWE-798
language: [c, cpp]
tags: [crypto, secrets, credentials]
---

# 硬编码密钥/凭证 (Hardcoded Secrets)

## 检测概要

检查源代码中是否硬编码了密码、API Key、Token、加密密钥等敏感凭证。

## 检测逻辑

### Step 1: 搜索常见敏感变量名

```c
// 高危变量名模式
char *password = "...";
char *api_key = "...";
const char *secret = "...";
char *token = "...";
char *private_key = "...";
```

### Step 2: 搜索硬编码凭证值

```c
// BAD: 硬编码密码
if (strcmp(input, "admin123") == 0) { ... }

// BAD: 硬编码加密密钥
unsigned char key[] = {0x01, 0x02, 0x03, ...};

// BAD: 硬编码连接字符串
snprintf(conn, sizeof(conn), "host=db user=admin password=secret123");

// BAD: 硬编码 API Token
const char *api_token = "sk-1234567890abcdef";
```

### Step 3: 检查高熵字符串

对函数外的静态字符串常量进行熵检测：
- 高熵 base64 字符串可能为证书或密钥
- 长十六进制字符串可能为密钥
- 格式化的 PEM (-----BEGIN...) 为证书/密钥

## 误报排除

| 场景 | 原因 |
|------|------|
| 示例代码中的占位符 (`"your_key_here"`) | 非真实凭证 |
| 测试 fixture 中的测试密码 | 非生产环境 |
| 公开的 Nonce/Salt | 非机密 |
| 环境变量读取 | `${API_KEY}` 非硬编码 |
| 配置文件的模板变量 | `${VAR}` 格式 |

## 检测模式汇总

```
# 高危变量名 + 字面量初始化
(password|secret|key|token|api_key).*=.*".*"

# 密码比较
strcmp|strncmp.*".*"         # 字符串字面量作为比较目标

# 十六进制密钥数组
unsigned char.*\[\].*=.*\{0x

# 高熵 base64 字符串
[A-Za-z0-9+/]{40,}={0,2}    # 长 base64 字符串常量
```