---
name: secure-transport
description: 审计网络通信的TLS/SSL配置和传输层安全，检测证书问题、降级攻击风险、协议配置缺陷和不安全的加密套件。当用户请求传输安全审计、TLS配置审查、证书管理检测、中间人攻击防护、加密套件安全时使用。
category: domain
topic: [system]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 安全传输审计

## 审计概览

传输层安全（TLS）是保护数据在网络上传输的基础。配置错误可能导致中间人攻击（MITM）、降级攻击和敏感数据泄露。审计覆盖：

> **参考**: 详细 TLS 配置检查清单、加密套件速查、证书检查项见 [`references/tls-config.md`](references/tls-config.md)。
- **TLS 版本和加密套件**
- **证书管理和验证**
- **客户端和服务端双向认证**
- **内部服务间通信安全**

## 审计流程

### Phase 1: TLS 端点发现

识别所有需要 TLS 的网络端点：

```
外部端点:
□ HTTPS (443)
□ WSS (WebSocket Secure)
□ gRPC TLS
□ SMTP/SMTPS、IMAPS、POP3S

内部端点:
□ 服务间 RPC/gRPC
□ 数据库连接 (MySQL 3306、PostgreSQL 5432、Redis 6379)
□ 消息队列 (Kafka 9093、RabbitMQ 5671)
□ 服务发现/配置中心 (Consul、etcd)
□ 监控导出 (Prometheus、metrics endpoint)

管理端点:
□ SSH (22)
□ K8s API Server (6443)
□ 数据库管理面板
□ CI/CD Runner
```

### Phase 2: 检查清单

#### 2.1 TLS 版本和加密套件

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否禁用 SSLv2/SSLv3 | `sslscan` / `testssl.sh` 枚举支持的协议 |
| [C] | 是否禁用 TLS 1.0/1.1 | PCI DSS 要求 TLS 1.2+ (2018年起) |
| [C] | 是否禁用 NULL/EXPORT/匿名加密套件 | `openssl s_client -connect host:port -cipher 'NULL'` |
| [H] | 是否禁用 RC4/3DES/IDEA 等弱加密 | 检查加密套件列表 |
| [H] | 是否优先使用 AEAD 加密套件 | GCM/ChaCha20-Poly1305 > CBC |
| [H] | 是否使用前向安全性 (PFS) | ECDHE/DHE 密钥交换 |
| [M] | 是否启用 TLS 1.3 | TLS 1.3 移除了所有已知不安全的算法 |

```bash
# 检测: testssl.sh
testssl.sh --color 3 https://target.com

# 检测: nmap 枚举加密套件
nmap --script ssl-enum-ciphers -p 443 target.com

# 检测: OpenSSL 测试特定版本
openssl s_client -connect target.com:443 -tls1_0  # 如果连接成功则不安全
openssl s_client -connect target.com:443 -tls1_1  # 同上
```

#### 2.2 证书管理

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 证书是否在有效期内 | 检查 notBefore / notAfter |
| [C] | 证书链是否完整且可信 | 检查 intermediate CA 是否正确配置 |
| [H] | 证书是否由可信 CA 签发 | 禁止自签名证书在生产环境 |
| [H] | 证书域是否匹配 | CN/SAN 是否包含实际域名 |
| [H] | 证书是否即将过期 | 是否有证书到期监控和自动续期 |
| [H] | 私钥是否安全存储 | 私钥文件权限 (600)、存储在 HSM/KMS |
| [M] | 证书吊销配置是否正确 | OCSP Stapling / CRL 是否启用 |
| [M] | 是否使用通配符证书 | `*.example.com` 的风险评估 |

#### 2.3 客户端安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | HTTP → HTTPS 重定向是否正确 | 所有 HTTP 请求是否 301 到 HTTPS |
| [H] | HSTS 是否配置 | `Strict-Transport-Security: max-age=31536000` |
| [H] | 证书固定 (HPKP) 是否慎用 | 配置错误会导致站点不可访问 |

#### 2.4 服务端安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 客户端证书是否正确验证 | 检查 SSLContext 是否配置了 TrustManager |
| [C] | 是否有不安全的 TrustManager | 检查是否使用了接受所有证书的 TrustManager |
| [H] | 主机名验证是否启用 | HTTPS 连接是否验证了 CN/SAN 匹配 |
| [H] | 是否支持双向 TLS (mTLS) | 服务间通信是否使用客户端证书 |

#### 2.5 数据库/中间件连接安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 数据库连接是否启用 TLS | JDBC: `useSSL=true`、`sslMode=VERIFY_CA` |
| [H] | 数据库证书是否验证 | `verifyServerCertificate=true` vs `useSSL=true` 不验证 |
| [H] | Redis 连接是否启用 TLS | `rediss://` vs `redis://` |
| [H] | Kafka 是否启用 TLS | listener 配置 `SSL://` |
| [M] | 消息队列是否启用 TLS | RabbitMQ AMQPS、MQTT TLS |

### Phase 3: 常见漏洞模式

#### 模式 1: 信任所有证书

```java
// BAD: TrustManager 接受所有证书——完全绕过 TLS 验证!
SSLContext ctx = SSLContext.getInstance("TLS");
ctx.init(null, new TrustManager[] {
    new X509TrustManager() {
        public void checkClientTrusted(X509Certificate[] c, String a) {}
        public void checkServerTrusted(X509Certificate[] c, String a) {}
        public X509Certificate[] getAcceptedIssuers() { return null; }
    }
}, null);
HttpsURLConnection.setDefaultSSLSocketFactory(ctx.getSocketFactory());

// GOOD: 使用系统默认的 TrustManager，必要时添加特定证书
TrustManagerFactory tmf = TrustManagerFactory.getInstance("PKIX");
tmf.init((KeyStore) null);  // 使用系统信任库
```

#### 模式 2: 主机名验证绕过

```python
# BAD: 禁用主机名验证
import ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False  # MITM 攻击!
ctx.verify_mode = ssl.CERT_NONE  # 甚至不验证证书!

# GOOD: 正确的主机名验证
ctx = ssl.create_default_context()
# check_hostname=True 和 verify_mode=CERT_REQUIRED 是默认值
```

```go
// BAD: InsecureSkipVerify 跳过所有验证
client := &http.Client{
    Transport: &http.Transport{
        TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
    },
}

// GOOD: 使用系统 CA 池
client := &http.Client{} // 默认验证
```

#### 模式 3: 混合内容

```html
<!-- BAD: HTTPS 页面加载 HTTP 资源——浏览器阻止或降级安全 -->
<img src="http://cdn.example.com/image.png">
<script src="http://api.example.com/config.js"></script>

<!-- GOOD: 使用协议相对 URL 或 HTTPS -->
<img src="https://cdn.example.com/image.png">
<!-- 或通过 CSP 强制升级: upgrade-insecure-requests -->
```

#### 模式 4: 数据库连接无 TLS

```properties
# BAD: JDBC 连接字符串未启用 SSL
spring.datasource.url=jdbc:mysql://db.internal:3306/mydb
# 流量明文! 内网中的嗅探攻击可获取所有数据

# GOOD: 启用 TLS + 证书验证
spring.datasource.url=jdbc:mysql://db.internal:3306/mydb?useSSL=true&requireSSL=true&verifyServerCertificate=true
```

### Phase 4: 内部服务间通信

| 场景 | 推荐方案 |
|------|---------|
| 微服务间 HTTP/gRPC | mTLS (如 Istio/Consul Connect) |
| 数据库连接 | TLS with certificate validation |
| 消息队列 | TLS + SASL/SCRAM 认证 |
| 服务网格内部 | Istio/Linkerd 默认 mTLS |
| K8s Pod 间 | 依赖 NetworkPolicy + mTLS |

### Phase 5: 输出格式

```markdown
## 安全传输审计报告

### TLS 配置审计 (target.com:443)

| 检查项 | 测试结果 | 期望 | 状态 |
|--------|---------|------|------|
| TLS 1.0 | Enabled ✗ | Disabled | Critical |
| TLS 1.1 | Enabled ✗ | Disabled | Critical |
| TLS 1.2 | Enabled | Enabled | ✓ |
| TLS 1.3 | Disabled | Enabled | Medium |
| RC4 ciphers | Not supported | Not supported | ✓ |
| PFS (ECDHE) | Supported | Supported | ✓ |
| Certificate | Valid until 2026-06-01 | ≥30d margin | ✓ |

### 发现清单

#### [C-01] 内部 MySQL 无 TLS
- 连接: jdbc:mysql://db.internal:3306/orderdb (useSSL=false)
- 影响: 内网嗅探可获取订单数据
- 修复: 启用 useSSL=true + verifyServerCertificate=true
```
