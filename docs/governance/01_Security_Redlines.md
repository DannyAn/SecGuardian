# 01 — 安全红线 (Security Redlines)

> **对应 Sheet:** `01_Security_Redlines`
> **牵引方向:** SecGuardian 安全红线的**类别体系**与**等级分布**。红线是任何发布必须通过的门槛，SecGuardian 需能自动检测并标记红线违规。

---

## 1. 概述

安全红线是**不可妥协的安全底线要求**。无论业务优先级如何，违反红线的代码/配置不可发布。本 sheet 定义了 **10 个红线分类**，每类 12 条要求，共计 **120 条安全红线控制项**。

---

## 2. 红线分类体系

| 分类 | 控制目标 | 典型行业标准对标 | 严重度分布 |
|---|---|---|---|
| **Authentication** (认证) | 防止认证绕过、弱口令、会话固定 | OWASP ASVS V2 | 5×Medium, 5×High, 2×Critical(Gate) |
| **Authorization** (授权) | 防止越权、水平/垂直提权 | OWASP ASVS V4 | 6×Medium, 5×High, 1×Critical(Gate) |
| **Secrets** (密钥管理) | 防止硬编码密钥、凭证泄露 | NIST SSDF PS.3 | 3×Medium, 6×High, 3×Critical(Gate) |
| **Cryptography** (密码学) | 强制使用安全算法、禁止弱密码 | OWASP ASVS V6 | 6×Medium, 3×High, 3×Critical(Gate) |
| **Web Security** (Web安全) | XSS/CSRF/点击劫持防护 | OWASP Top 10 | 5×Medium, 5×High, 2×Critical(Gate) |
| **API Security** (API安全) | API认证、速率限制、注入防护 | OWASP API Security Top 10 | 5×Medium, 5×High, 2×Critical(Gate) |
| **Infrastructure** (基础设施) | 基线加固、端口管理、TLS配置 | CIS Benchmarks | 6×Medium, 4×High, 2×Critical(Gate) |
| **Logging** (日志审计) | 安全事件日志记录与完整性 | ISO 27001 A.16 | 5×Medium, 4×High, 3×Critical(Gate) |
| **Privacy** (隐私合规) | PII保护、数据处理合规 | GDPR / PIPL | 5×Medium, 4×High, 3×Critical(Gate) |
| **Release Gate** (发布门禁) | 卡点规则、变更审批、回溯 | NIST SSDF RV.1 | 全部 Critical (每轮固定) |

> 每类红线按 12 轮迭代（12 requirements per category）重复，体现**持续增强原则**——每轮评估后提升要求严苛度。

---

## 3. 红线严重度示意

### 3.1 Medium（中等）

适用范围：最佳实践偏离，建议在下一轮迭代中修复
示例：
- 01-001: 认证机制需文档化且强制执行
- 01-002: 授权策略需文档化且强制执行
- 01-005: Web 安全头部需配置

### 3.2 High（高）

适用范围：存在可控风险，需在当前迭代中修复
示例：
- 01-003: 密钥管理需强制执行，禁止硬编码凭证
- 01-006: API 端点需强制执行认证与速率限制
- 01-012: 授权检查需贯穿所有 API 端点

### 3.3 Critical（严重 / Gate）

适用范围：必须阻塞发布，不可妥协
示例：
- 01-010/020/030...：发布门禁强制执行——安全扫描全绿通过
- 01-090/100/110...：治理评审——合规报告必须 approved

---

## 4. 业界最佳实践对标

### 4.1 认证 (Authentication)

| 红线要求 | OWASP ASVS | NIST |
|---|---|---|
| 密码复杂度策略 | V2.1 | SP 800-63B |
| MFA 强制 | V2.5 | SP 800-63B AAL2 |
| 会话管理 | V3 | — |
| Cookie Secure/SameSite | V3.4 | — |
| 凭据恢复安全 | V2.6 | SP 800-63B |

### 4.2 授权 (Authorization)

- **RBAC/ABAC 模型**：基于角色的访问控制或基于属性的访问控制
- **最小权限原则**：默认 Deny，显式 Allow
- **水平越权防范**：资源级权限校验（OWASP ASVS V4.1）
- **API 级权限粒度**：每个 API 端点校验用户身份与权限

### 4.3 密钥管理 (Secrets)

遵循 [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)：

| 类别 | 最低要求 |
|---|---|
| 源码中密钥 | 禁止——改为环境变量或密钥管理服务 |
| CI/CD 凭据 | 使用临时 Token / OIDC 代替长期密钥 |
| 加密密钥 | 使用 KMS 托管，轮转周期 ≤ 90 天 |
| 扫描频率 | 每次提交自动扫描 |

### 4.4 API 安全

基于 [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)：

| 风险 | 红线要求 |
|---|---|
| API1 - 对象级授权失效 | 每次请求校验对象所有权 |
| API2 - 用户认证失效 | 所有 API 端点强制认证 |
| API3 - 过度数据暴露 | 返回字段白名单，不超量返回 |
| API4 - 速率限制缺失 | 每用户/每 IP 请求速率限制 |
| API6 - 批量分配 | 禁止自动绑定全部请求参数 |

### 4.5 基础设施

基于 CIS Benchmark 核心基线：

- **TLS 1.2+ 强制**，禁用 TLS 1.0/1.1
- **HSTS 头部配置**
- **CSP (Content Security Policy) 设置**
- **非必要端口关闭**
- **SSH 密钥认证代替密码**

---

## 5. SecGuardian 牵引方向

### 5.1 短期（优先落地）

1. **红线检测器优先级矩阵**

   | 分类 | 现有 detectors | 优先级 |
   |---|---|---|
   | Authentication | 无 | 🔴 **最高** — 先建 |
   | Secrets | 部分（KeyLeak） | 🟡 高 — 增强 |
   | Web Security | 部分 | 🟡 高 — 扩展 |
   | Logging | 无 | 🟢 中 — 后期 |

2. **红线分类目录化** — 在 `knowledge/guard-rules/` 中建立 10 个分类的子目录
3. **红线输出标记** — `secguard` 扫描结果中标明 `redline: true/false`

### 5.2 中期

1. **红线阈值配置** — 用户可设置"当 High 红线 ≥ 3 时阻塞发布"
2. **红线豁免流程** — 经审批的红线豁免可跳过，但记录在审计日志
3. **多轮次联动** — 识别"Previous round 已修复，本轮又出现"的回弹问题

### 5.3 长期

1. **红线自动升级** — 同一分类连续违规，自动升级严重度
2. **红线趋势分析** — 12 轮迭代的红线消减曲线，度量团队安全成熟度
3. **行业红线模板** — 金融/医疗/游戏等行业预设红线集

---

## 6. 红线生命周期实现

```
                       ┌─────────────────┐
                       │  代码提交/PR     │
                       └────────┬────────┘
                                ▼
                    ┌───────────────────────┐
                    │  SecGuard 自动扫描     │
                    └────────┬──────────────┘
                             ▼
                   ┌─────────────────┐
                   │  红线检测匹配     │ ← 120 条规则引擎
                   └────────┬────────┘
                            ▼
           ┌─────────────────────────────────┐
           │  严重度 → 判定是否阻塞 Gate       │
           │  Critical → 阻塞                 │
           │  High ≥ N → 阻塞 (按配置)         │
           │  Medium → 警告                   │
           └─────────────────────────────────┘
```

---

> **本文档指引 SecGuardian 实现 120 条安全红线自动检测与发布门禁。**
> 详见 [00_Governance_Model](00_Governance_Model.md#6-与-secguardian-skills-映射关系) 的域-Skill 映射。
