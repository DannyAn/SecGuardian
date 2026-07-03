# TLS 安全配置检查清单

## TLS 版本检查

| 版本 | 状态 | 说明 |
|------|------|------|
| SSL 3.0 | ❌ 禁用 | POODLE 攻击，2015 年废弃 |
| TLS 1.0 | ❌ 禁用 | BEAST 攻击，PCI DSS 要求禁用 |
| TLS 1.1 | ❌ 禁用 | 不再维护，2021 年废弃 |
| TLS 1.2 | ✅ 推荐 | 当前主流，需配合安全加密套件 |
| TLS 1.3 | ✅ 最佳 | 简化握手、前向安全性、0-RTT |

## 加密套件检查

```bash
# 检测命令
nmap --script ssl-enum-ciphers -p 443 target.com
```

| 加密套件 | 状态 | 替代 |
|---------|------|------|
| NULL 套件 | ❌ | — |
| EXPORT 套件 | ❌ | — |
| RC4 套件 | ❌ | AES-GCM / ChaCha20-Poly1305 |
| 3DES 套件 | ❌ | AES-GCM / ChaCha20-Poly1305 |
| CBC 模式套件 | ⚠️ | GCM 模式 |
| ECDHE + AES-GCM | ✅ | — |
| ECDHE + ChaCha20-Poly1305 | ✅ | — |

### 推荐配置 (nginx)

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
```

## 证书检查清单

| 检查项 | 检测方法 | 风险 |
|--------|---------|------|
| 证书是否过期 | `openssl s_client -connect host:443 2>/dev/null \| openssl x509 -noout -dates` | 用户看到不安全警告 |
| 证书链是否完整 | `openssl s_client -connect host:443 -showcerts` | 部分客户端可能不信任 |
| 是否使用自签名证书 | 检查 Issuer == Subject | 中间人攻击风险 |
| 证书密钥长度 | RSA < 2048 位 → Critical | 可被暴力破解 |
| 签名算法 | SHA-1 → 禁用，MD5 → 禁用 | 碰撞攻击可行 |
| SAN 覆盖 | 检查 Subject Alternative Names | 域名不匹配导致无效 |
| 证书透明度 (CT) | 未提交 CT log → Chrome 不信任 | 浏览器显示不安全 |

## HSTS 配置检查

```bash
curl -sI https://target.com | grep -i strict-transport-security
```

| 配置 | 推荐值 | 说明 |
|------|--------|------|
| max-age | ≥ 31536000 (1年) | 过短等于未启用 |
| includeSubDomains | 必须 | 覆盖所有子域名 |
| preload | 推荐 | 加入浏览器预加载列表 |

## 内部服务通信检查

| 检查项 | 问题特征 | 修复 |
|--------|---------|------|
| 服务间明文通信 | `http://` 而非 `https://` | 启用 mTLS |
| 数据库连接未加密 | 连接字符串无 `ssl=true` | 启用 TLS + 证书验证 |
| 消息队列未加密 | Kafka/RabbitMQ 无 TLS | 启用传输层加密 |
| 缓存服务未加密 | Redis/Memcached 无 TLS | 启用 stunnel 或 TLS 代理 |
