---
name: data-protection
description: 审计敏感数据的存储、传输、处理和销毁全生命周期的安全保护措施，检测数据泄露和隐私合规风险。当用户请求数据保护审计、敏感数据存储安全、GDPR合规、数据加密、数据脱敏时使用。
category: domain
topic: [system]
severity: Medium
cwe: CWE-000
cvss: 5.5
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。


# 数据保护安全审计

## 审计概览

数据保护不仅关乎安全，也关乎合规（GDPR、个人信息保护法、PCI DSS）。审计覆盖：
- **数据识别**：哪些数据在哪
- **数据存储**：加密和访问控制
- **数据传输**：加密和认证
- **数据处理**：脱敏和最小化
- **数据销毁**：安全删除和保留期限

## 审计流程

### Phase 1: 敏感数据识别

搜索代码和配置中敏感数据的痕迹：

```
PII (个人身份信息):
□ 姓名、身份证号、护照号
□ 手机号、邮箱、地址
□ IP 地址、设备指纹 (在某些法域属于 PII)
□ Cookie/广告 ID

金融数据:
□ 银行卡号 (PAN)、CVV、有效期
□ 交易记录、余额、信用评分

认证凭证:
□ 密码、密码哈希、密码重置 Token
□ API Key、Access Token、Refresh Token
□ SSH 私钥、TLS 证书私钥、签名密钥

健康数据:
□ 病历、诊断、处方 (HIPAA)
□ 生物特征 (指纹、人脸、声纹)

其他敏感数据:
□ 种族、宗教、政治观点、性取向
□ 地理位置（实时追踪）
□ 通信内容（聊天记录、邮件正文）
```

### Phase 2: 检查清单

#### 2.1 数据存储安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 密码是否使用安全哈希 | bcrypt/argon2，禁止 SHA/MD5 |
| [C] | 敏感字段是否加密存储 | 检查数据库 schema 中 PII/金融字段的加密状态 |
| [H] | 数据库备份是否加密 | 检查备份存储的加密配置 |
| [H] | 静态密钥是否使用 KMS 加密 | 禁止密钥明文存储在数据库中 |
| [H] | 是否有字段级加密 | 特别敏感字段（SSN/CVV）应单独加密 |
| [M] | 测试环境是否有生产数据 | 检查测试数据库是否包含真实用户数据 |

#### 2.2 数据传输安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 公网传输是否使用 TLS 1.2+ | 检查外部 API 调用和 CDN 配置 |
| [H] | 内部服务间是否使用 mTLS | 微服务间通信是否加密 |
| [H] | 敏感数据是否出现在 URL 中 | GET 请求参数中是否包含 token/id |
| [M] | 数据导出是否有加密 | CSV/Excel 导出是否加密 + 密码保护 |

#### 2.3 数据处理安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 日志中是否包含敏感数据 | grep 日志输出中的 password/token/card 字段 |
| [H] | API 响应是否返回多余字段 | 检查序列化配置是否过滤了敏感字段 |
| [H] | 错误消息是否泄露数据 | 错误响应中是否包含 SQL 语句、文件路径、用户数据 |
| [H] | 数据脱敏是否正确 | 手机号/邮箱/卡号显示格式是否符合合规要求 |
| [M] | 第三方共享数据是否脱敏 | 发送到 Analytics/推送服务的数据是否经过去标识化 |

#### 2.4 数据生命周期

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 是否有数据保留策略 | 用户注销后数据是否在规定时间内删除 |
| [H] | 是否有用户数据导出接口 | GDPR 要求提供数据可携带性 |
| [H] | 是否有用户数据删除接口 | GDPR "被遗忘权" |
| [M] | 软删除数据是否被扫描到 | 标记为"删除"但数据库中实际仍存在的数据 |

### Phase 3: 常见漏洞模式

#### 模式 1: API 响应泄露敏感字段

```java
// BAD: 直接序列化 Entity，返回了密码哈希和安全问题答案
@GetMapping("/api/user/profile")
public User getProfile() {
    return userRepo.findById(currentUserId());
    // 响应中包含了 password_hash, security_question_answer 等字段!
}

// GOOD: 使用 DTO 明确暴露字段
@GetMapping("/api/user/profile")
public UserProfileDTO getProfile() {
    User u = userRepo.findById(currentUserId());
    return new UserProfileDTO(u.getId(), u.getNickname(), u.getEmail());
    // 仅暴露必要的非敏感字段
}
```

#### 模式 2: 日志泄露敏感数据

```python
# BAD: 日志中记录了完整请求体
logger.info(f"Processing payment: {request.body}")
# 日志输出: Processing payment: {"card_number": "4111111111111111", "cvv": "123"}

# GOOD: 脱敏后记录
logger.info(f"Processing payment for card: {mask_card(request.card_number)}")
# 日志输出: Processing payment for card: 411111****1111
```

#### 模式 3: 测试环境泄露生产数据

```sql
-- BAD: 生产数据库直接克隆到测试环境
mysqldump production_db | mysql staging_db
-- 测试工程师看到了真实用户的手机号、地址、订单

-- GOOD: 使用脱敏脚本处理后再导入
mysqldump production_db | anonymize.sh | mysql staging_db
```

### Phase 4: 合规映射

| 法规 | 关键要求 | 对应检查项 |
|------|---------|-----------|
| GDPR | 数据最小化、被遗忘权、数据可携带 | Phase 2.4 |
| 个人信息保护法 | 单独同意、影响评估、境内存储 | Phase 1 + 2.1 |
| PCI DSS | 卡号加密存储、禁止存储 CVV、传输加密 | Phase 2.1 + 2.2 |
| HIPAA | PHI 加密、访问审计、最小必要原则 | Phase 2.1 + 2.3 |
