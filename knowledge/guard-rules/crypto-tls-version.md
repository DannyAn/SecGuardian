---
confidence: dynamic
cwe: CWE-326
detector: crypto-tls-version
language: [c, cpp, java, python, go, js]
precision: very-high
severity: medium
tags: [crypto, tls, ssl, protocol]
---

# TLS/SSL 弱版本 (Weak TLS/SSL Version)

## 威胁定义 (Threat Definition)

检测代码中是否使用了已弃用的 SSL/TLS 协议版本（SSLv2/3、TLS 1.0/1.1），这些协议存在已知漏洞（POODLE/BEAST/Lucky13/RC4）。

## 检测逻辑 (Detection Logic)

### Step 1: C/C++ — OpenSSL TLS 版本

```c
// BAD: SSLv2/SSLv3
SSL_CTX_set_min_proto_version(ctx, SSL3_VERSION);
SSLv23_server_method();   // 兼容所有版本含 SSLv3
SSLv23_client_method();

// BAD: TLS 1.0
TLS1_VERSION
TLSv1_server_method();
TLSv1_client_method();

// BAD: TLS 1.1
TLS1_1_VERSION
TLSv1_1_server_method();
TLSv1_1_client_method();

// BAD: 未设置最小版本 (默认兼容)
SSL_CTX_new(SSLv23_method(...));  // 未设置 proto_version
```

**C/C++ 安全模式:**
```c
// GOOD: 最低 TLS 1.2
SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);
// 推荐: TLS 1.3
SSL_CTX_set_min_proto_version(ctx, TLS1_3_VERSION);
```

### Step 2: Java — TLS 配置

```java
// BAD: 允许 TLS 1.0/1.1
SSLContext.getInstance("TLSv1");
SSLContext.getInstance("TLSv1.1");
SSLContext.getInstance("SSLv3");

// BAD: 系统属性降低 TLS 版本
System.setProperty("jdk.tls.client.protocols", "TLSv1,TLSv1.1");

// BAD: Spring Boot 降级
server.ssl.protocol=TLSv1.1

// BAD: Apache HttpClient
SSLConnectionSocketFactory(sslContext, new String[]{"TLSv1", "TLSv1.1"}, ...);
```

**Java 安全模式:**
```java
// GOOD
SSLContext.getInstance("TLSv1.2");
SSLContext.getInstance("TLSv1.3");
```

### Step 3: Python — TLS 配置

```python
# BAD: SSL 版本
import ssl
ssl.SSLContext(ssl.PROTOCOL_TLSv1)   # TLS 1.0
ssl.SSLContext(ssl.PROTOCOL_TLSv1_1) # TLS 1.1
ssl.SSLContext(ssl.PROTOCOL_SSLv3)   # SSLv3

# BAD: requests 禁用验证
requests.get(url, verify=False)

# BAD: urllib 不安全上下文
ssl._create_unverified_context()
```

**Python 安全模式:**
```python
# GOOD
ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)  # 自动选择最安全版本
ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)
```

### Step 4: Go — TLS 配置

```go
// BAD: 设置低版本
tls.Config{MinVersion: tls.VersionTLS10}
tls.Config{MinVersion: tls.VersionTLS11}
tls.Config{MaxVersion: tls.VersionTLS11}  // 限制最高为 1.1

// BAD: 不验证证书
tls.Config{InsecureSkipVerify: true}

// BAD: 允许不安全密码套件
tls.Config{CipherSuites: []uint16{tls.TLS_RSA_WITH_RC4_128_SHA}}
```

### Step 5: JavaScript — TLS 配置

```javascript
// BAD: Node.js 设置低版本
const options = {
    secureProtocol: 'TLSv1_method',
    minVersion: 'TLSv1',
    maxVersion: 'TLSv1.1',
    rejectUnauthorized: false
};
https.createServer(options, app);

// BAD: HTTPS agent 不安全
new https.Agent({ rejectUnauthorized: false });
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
```

## 修复指引 (Remediation Guide)

1. 服务端最低 TLS 1.2，推荐 TLS 1.3
2. 移除 SSLv2/SSLv3/TLS 1.0/TLS 1.1 协议支持
3. 使用安全密码套件（TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384）
4. 定期使用 SSL Labs / testssl.sh 验证配置

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `TLSv1_2_method()` 及以上版本 | 安全版本 | 确认方法名为 TLSv1_2 或 TLSv1_3 系列 |
| `tls.VersionTLS12` / `tls.VersionTLS13` | 安全版本 | 确认 MinVersion 设置为 VersionTLS12 或 VersionTLS13 |
| `ssl.PROTOCOL_TLS_CLIENT` / `PROTOCOL_TLS_SERVER` | 自动选择安全版本 | 确认使用 TLS_CLIENT/TLS_SERVER 协议常量（Python 3.6+） |
| 测试代码 (Mock SSL) | 非生产 | 确认文件路径匹配 test/mock 模式，且非生产配置文件 |
| 仅作为服务端接收旧版本客户端（向后兼容区） | 有文档说明 | 确认有明确文档或注释说明兼容性需求及安全评估 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# C/C++ OpenSSL
SSL3_VERSION|TLS1_VERSION\b|TLS1_1_VERSION
SSLv23_method|TLSv1_method|TLSv1_1_method
SSL_OP_NO_TLSv1_2  (禁止 TLS 1.2)
→ MUST: code_context (SSL_CTX 初始化及版本设置的完整代码)
→ MUST: judgment_rationale (协议版本是否低于 TLS 1.2，是否有安全评估文档)

# Java
SSLContext\.getInstance\("SSL|SSLContext\.getInstance\("TLSv1"\)|SSLContext\.getInstance\("TLSv1\.1"\)
jdk\.tls\.client\.protocols.*TLSv1[^.]

# Python
PROTOCOL_TLSv1\b|PROTOCOL_TLSv1_1|PROTOCOL_SSLv
verify\s*=\s*False|_create_unverified_context

# Go
VersionTLS10|VersionTLS11|InsecureSkipVerify\s*:\s*true

# JS/Node
secureProtocol.*TLSv1_method|minVersion.*TLSv1[^12]
rejectUnauthorized\s*:\s*false
NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*.0.

# === EXCLUDE (不报告) ===

→ TLS1_2_VERSION|TLS1_3_VERSION|TLSv1_2_method|TLSv1_3_method           # 安全协议版本
→ VersionTLS12|VersionTLS13                                              # Go 安全版本
→ PROTOCOL_TLS_CLIENT|PROTOCOL_TLS_SERVER|PROTOCOL_TLSv1_2               # Python 安全协议
→ *test*/|*mock*/                                                        # 测试/Mock 代码
→ # backward.compat|legacy.support|兼容旧版                               # 有文档说明的向后兼容
```
