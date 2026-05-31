# 04 — 威胁建模 (Threat Modeling)

> **对应 Sheet:** `04_Threat_Modeling`  
> **牵引方向:** SecGuardian 威胁建模自动化——基于 STRIDE 分类的系统化威胁分析能力。

---

## 1. 概述

威胁建模是在设计阶段主动识别、评估和缓解安全威胁的结构化方法。本 sheet 基于 **Microsoft STRIDE 分类法**，涵盖 **6 大威胁分类**，每类 14 条要求，共计 **80 条威胁建模控制项**。

---

## 2. STRIDE 分类体系

| 威胁 | 英文 | 破坏目标 | 严重度分布 | 每类示例 |
|---|---|---|---|---|
| 冒充 | **S**poofing | 身份认证 | 4×Medium, 6×High, 4×Critical | 伪造 JWT Token |
| 篡改 | **T**ampering | 数据完整性 | 4×Medium, 6×High, 4×Critical | 参数篡改 |
| 抵赖 | **R**epudiation | 不可否认性 | 2×Medium, 6×High, 6×Critical | 无审计日志 |
| 信息泄露 | **I**nformation Disclosure | 机密性 | 4×Medium, 6×High, 4×Critical | 数据明文存储 |
| 拒绝服务 | **D**enial of Service | 可用性 | 4×Medium, 6×High, 4×Critical | 资源耗尽攻击 |
| 提权 | **E**levation of Privilege | 授权 | 2×Medium, 6×High, 6×Critical | 垂直越权 |

---

## 3. 各威胁分类详解与最佳实践

### 3.1 Spoofing（冒充攻击）

**威胁描述：** 攻击者伪装成合法用户、系统或服务来获取未授权访问。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| S-001 | 所有用户认证使用标准协议 (OAuth 2.0 / OIDC / SAML) | Medium |
| S-002 | 禁止使用弱密码算法和默认凭证 | High |
| S-003 | 高敏操作要求 MFA | Medium |
| S-004 | API 密钥和 Token 使用最小期限 | High |
| S-005 | 服务间通信使用 mTLS | Critical |
| S-006 | JWT Token 使用强签名算法 (RS256 或 ES256) | High |
| S-007 | 会话 ID 使用加密安全的随机数生成器 | Medium |
| S-008 | Cookie 设置 Secure + HttpOnly + SameSite 标志 | High |

**最佳实践：**
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [NIST SP 800-63B Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)

### 3.2 Tampering（篡改攻击）

**威胁描述：** 攻击者在传输或存储过程中恶意修改数据或代码。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| T-001 | 敏感数据在传输中使用 TLS 1.2+ | Medium |
| T-002 | 重要配置文件完整性校验 | High |
| T-003 | 软件制品签名验证 (如 Docker Image 签名) | Critical |
| T-004 | 数据库敏感字段加密存储 | Medium |
| T-005 | 请求参数完整性校验 (如 HMAC) | High |
| T-006 | 禁止客户端侧修改后提交的数据不验证 | Critical |

**最佳实践：**
- 使用 Integrity 字段 (如 Subresource Integrity)
- Docker Content Trust 签名
- gRPC 使用双向 TLS

### 3.3 Repudiation（抵赖攻击）

**威胁描述：** 用户或系统否认其执行的操作。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| R-001 | 所有安全事件记录审计日志 | High |
| R-002 | 审计日志不可篡改 (追加写入 + 签名) | Critical |
| R-003 | 日志包含完整上下文 (时间戳、用户、来源 IP、操作) | Medium |
| R-004 | 日志集中存储并备份 | Medium |
| R-005 | 关键操作日志保留 ≥ 1 年 (合规要求) | High |
| R-006 | 日志存储访问受 RBAC 控制 | Critical |

**最佳实践：**
- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
- PCI DSS 要求审计日志保留 12 个月
- 使用 SIEM 系统（如 Splunk / ELK）进行日志分析

### 3.4 Information Disclosure（信息泄露）

**威胁描述：** 敏感信息被未授权方获取。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| I-001 | 敏感数据在静态存储时加密 | Medium |
| I-002 | 最小数据原则——只收集和展示必要数据 | High |
| I-003 | API 响应不泄露堆栈跟踪和调试信息 | Medium |
| I-004 | 错误消息中不包含数据库结构、路径、SQL | High |
| I-005 | PII 数据采用字段级脱敏 | Critical |
| I-006 | 非生产环境使用脱敏数据 | Medium |

**最佳实践：**
- AWS/GCP/Azure 密钥管理服务 (KMS) 加密
- 数据分类：公开 / 内部 / 敏感 / 机密
- 日志脱敏工具（如 logback 的 Filter）

### 3.5 Denial of Service（拒绝服务）

**威胁描述：** 通过资源耗尽或异常输入导致服务不可用。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| D-001 | API 端点配置速率限制 (每用户/每 IP) | High |
| D-002 | 关键资源使用连接池和限制池大小 | Medium |
| D-003 | 启用自动弹性伸缩 | Medium |
| D-004 | 文件上传大小和类型限制 | High |
| D-005 | 查询语句添加超时和结果集限制 | Medium |
| D-006 | 正则表达式防范 ReDoS 攻击 | Critical |

**最佳实践：**
- [OWASP DoS Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Denial_of_Service_Cheat_Sheet.html)
- 云层防护：CloudFlare / AWS WAF / GCP Cloud Armor
- 使用 API 网关进行全局速率限制

### 3.6 Elevation of Privilege（提权攻击）

**威胁描述：** 攻击者从低权限提升到高权限。

| 控制项 | 要求 | 严重度 |
|---|---|---|
| E-001 | 严格实施 RBAC 模型 | Critical |
| E-002 | 每个 API 端点进行权限校验 (非前端控制) | High |
| E-003 | 管理后台单独部署且访问受限 | High |
| E-004 | 水平越权检测——每个资源操作校验所有权 | Critical |
| E-005 | 权限变更需审批流程 | High |
| E-006 | 禁止使用通配符 * 权限分配 | Medium |

**最佳实践：**
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- 零信任架构 (ZTA) 原则：永不信任，始终验证

---

## 4. 威胁建模工具与方法论

### 4.1 主流工具对比

| 工具 | 类型 | 自动化程度 | 集成度 |
|---|---|---|---|
| Microsoft Threat Modeling Tool | 桌面 App | 低 | Visio 风格 |
| OWASP Threat Dragon | Web/桌面 | 中 | GitHub 集成 |
| IriusRisk | SaaS | 高 | CI/CD 集成 |
| STRIDE-per-Element | 方法论 | — | 可用于任何架构 |

### 4.2 SecGuardian 威胁建模愿景

```
输入: 架构描述 (C4 YAML / 数据流图)
         │
         ▼
    威胁建模引擎
         │
         ├─ STRIDE 分析器 — 对每个组件/数据流应用 STRIDE
         ├─ 风险评估器 — CVSS 3.1 打分
         └─ 缓解建议器 — 自动推荐缓解措施
         │
         ▼
输出: 威胁矩阵 + 风险热力图 + 缓解推荐清单
```

---

## 5. SecGuardian 牵引方向

### 5.1 短期目标

1. **威胁建模知识库** — 在 `knowledge/concepts/` 中建立 STRIDE 知识体系
2. **模板化输入** — 支持常见的架构模式 (微服务/单体/Serverless) 威胁建模模板
3. **STRIDE 检查清单** — 预置 80+ 威胁检查项

### 5.2 中期目标

1. **集成威胁建模引擎** — 解析架构 YAML 自动生成威胁矩阵
2. **与 SAST 联动** — 威胁建模识别出的高风险组件 → SAST 重点扫描
3. **威胁库更新** — 定期从 NVD / CWE / MITRE ATT&CK 同步最新威胁

### 5.3 长期目标

1. **AI 辅助威胁识别** — 基于 LLM 提出架构中的隐藏威胁
2. **持续威胁建模** — 架构变更时自动增量更新威胁模型
3. **攻击路径生成** — 根据威胁模型自动生成攻击路径图和渗透测试建议

---

## 6. 威胁建模与开发活动的关系

```
需求阶段 → 威胁建模启动 (识别数据、信任边界)
   │
设计阶段 → 详细威胁分析 (STRIDE 遍历)
   │
开发阶段 → SAST/SCA 扫描 (代码级验证)
   │
测试阶段 → DAST/渗透测试 (动态验证威胁模型)
   │
上线阶段 → 威胁模型确认 + 门禁
   │
运维阶段 → 持续监控 + 威胁模型更新
```

---

> **本文档指引 SecGuardian 构建自动化威胁建模能力。**  
> 与 [03_Architecture_Review](03_Architecture_Review.md) 的架构评审流程紧密结合形成完整设计阶段安全闭环。
