# 10 — 漏洞 SLA 管理 (Vulnerability SLA Management)

> **对应 Sheet:** `10_Vuln_SLA`  
> **牵引方向:** SecGuardian 漏洞生命周期管理——从发现、评估、修复到验证的全流程 SLA 管控。

---

## 1. 概述

漏洞 SLA (Service Level Agreement) 定义了不同类型漏洞的**发现-修复-验证时限**。本 sheet 涵盖 **4 个严重度等级**，每类 10 条要求，共计 **40 条 SLA 控制项**。

---

## 2. 分类体系

| 严重度 | CVSS 3.1 评分 | SLA 时效 - 发现到确认 | SLA 时效 - 确认到修复 | SLA 总时效 |
|---|---|---|---|---|
| **Critical** | 9.0 - 10.0 | ≤ 8 小时 | ≤ 24 小时 | ≤ 32 小时 |
| **High** | 7.0 - 8.9 | ≤ 24 小时 | ≤ 7 天 | ≤ 8 天 |
| **Medium** | 4.0 - 6.9 | ≤ 7 天 | ≤ 30 天 | ≤ 37 天 |
| **Low** | 0.1 - 3.9 | ≤ 30 天 | 下个发布周期 | ≤ 60 天 |

---

## 3. 各等级 SLA 详解

### 3.1 Critical（严重漏洞）

**时间线要求：**

```
T+0h   发现漏洞（自动化扫描或外部报告）
T+8h   确认漏洞有效并制定缓解计划 (MTTK)
T+24h  完成修复或部署缓解措施 (MTTR)
T+32h  验证修复有效并关闭工单
```

**典型 Critical 场景：**
- RCE（远程代码执行）— Log4Shell / Shellshock
- 认证绕过 — CVE-2022-22965 (Spring4Shell)
- 公开 PoC 且已被利用的零日漏洞
- 数据泄露（公有存储桶可读）

**响应流程：**

| 步骤 | 责任方 | 产出 |
|---|---|---|
| 1. 确认 | SecOps 团队 | 漏洞工单创建 |
| 2. 影响评估 | SecOps + 开发 | 受影响业务和资产清单 |
| 3. 制定方案 | 开发团队 | 修复 PR / 临时缓解措施 |
| 4. 审批 | 安全负责人 | 紧急变更审批 |
| 5. 部署 | DevOps | Hotfix 上线 |
| 6. 验证 | SecOps | 扫描验证确认修复 |

### 3.2 High（高风险）

**时间线要求：**

```
T+0d   发现漏洞
T+1d   确认漏洞有效
T+7d   完成修复
T+8d   验证修复
```

**典型 High 场景：**
- 反射型 XSS
- SQL 注入（非认证前）
- 越权漏洞（水平）
- 弱密码策略
- TLS 1.0/1.1 支持

### 3.3 Medium（中风险）

**时间线要求：**

```
T+0d   发现漏洞
T+7d   确认漏洞有效并排期
T+30d  完成修复
T+37d  验证修复
```

**典型 Medium 场景：**
- CSP 头缺失
- Cookie 缺少 Secure 标志
- 信息泄露（非 PII）
- 缺少 HTTP Security Headers
- 非必要的开放端口

### 3.4 Low（低风险）

**时间线要求：**

```
T+0d   发现漏洞
T+30d  评估并排期
下个发布周期修复
60 天内验证
```

**典型 Low 场景：**
- 缺少版本头
- 轻微信息泄露（服务器类型）
- 优化建议
- 非安全相关的最佳实践偏离

---

## 4. 业界标准对标

### 4.1 行业标准 SLA 对比

| 标准/规范 | Critical | High | Medium | Low |
|---|---|---|---|---|
| **PCI DSS v4.0** | ≤ 7 天 | ≤ 30 天 | ≤ 90 天 | ≤ 120 天 |
| **ISO 27001** | 按风险判定 | — | — | — |
| **SOC 2** | ≤ 30 天 (所有漏洞) | — | — | — |
| **OWASP SSVM** | ≤ 24h / ≤ 7d | ≤ 30d | ≤ 60d | ≤ 90d |
| **NIST SSDF** | 组织自定 | — | — | — |

> 注意：PCI DSS v4.0 要求所有漏洞必须在特定时限内修复，但时限定义是从**发现**而不是从**确认**开始。

### 4.2 MTTR (Mean Time to Remediation) 行业基准

| 严重度 | 行业平均 | 行业最佳 |
|---|---|---|
| Critical | 23 天 | < 3 天 |
| High | 68 天 | < 14 天 |
| Medium | 167 天 | < 30 天 |
| Low | 300+ 天 | < 60 天 |

**SecGuardian 目标 SLA 比行业最佳更严格（见上文表格）。**

---

## 5. 漏洞 SLA 的自动化

### 5.1 SLA 跟踪流程

```
漏洞发现
   │
   ├─ 自动分类 (CVSS 评分 + 上下文修正)
   ├─ 自动分配 (根据分类/服务归属)
   │
   ▼
修复中 (SLA 倒计时开始)
   │
   ├─ < 50% → 正常
   ├─ 50%-80% → 黄色预警 (通知责任方)
   ├─ 80%-100% → 橙色告警 (通知管理者)
   └─ > 100% → 红色违约 (上报安全委员会)
   │
   ▼
修复验证 → 工单关闭 (SLA 停止)
```

### 5.2 Slack/邮件自动通知模板

```
[SLA 告警 - {severity}] {vuln_name}
  项目: {project}
  组件: {component} v{version}
  CVE: {cve_id}
  发现: {found_date}
  剩余时间: %{remaining} ({remaining_hours}小时)
  责任方: @{assignee}
```

---

## 6. SecGuardian 牵引方向

### 6.1 功能需求

| 功能 | 说明 | 优先级 |
|---|---|---|
| 漏洞发现与自动分类 | 集成 SAST/SCA 结果 → CVSS 打分 | P0 |
| SLA 倒计时看板 | 显示每个开放漏洞的剩余时间 | P0 |
| SLA 违约告警 | 按阶段通知责任人和管理者 | P1 |
| 报告 | 月度 SLA 达成率报告 | P1 |
| 豁免管理 | 经审批的延迟修复 | P2 |

### 6.2 与 SecGuardian 现有能力整合

```
secguard/secreview/secaudit
   │
   ▼
统一漏洞库 (Vulnerability Database)
   │
   ├─ 严重度自动判定
   ├─ SLA 计时启动
   ├─ 责任自动分配
   └─ 修复追踪
   │
   ▼
SLA 仪表盘
```

### 6.3 数据模型

```yaml
# vulnerability-record.yaml
id: VULN-2026-00123
cve: CVE-2026-12345
severity: critical
cvss: 9.8
found_by: secguard-sast
found_at: 2026-05-15T08:30:00Z
project: user-service
component: org.apache.logging.log4j:log4j-core
version: 2.14.0
sla:
  confirm_deadline: 2026-05-15T16:30:00Z
  fix_deadline: 2026-05-16T08:30:00Z
  confirmed_at: null
  fixed_at: null
  status: open
assignee: team-user-service
notifications:
  - level: warning  # 50%
    sent: false
  - level: alert    # 80%
    sent: false
  - level: breach   # 100%
    sent: false
```

---

> **本文档指引 SecGuardian 构建漏洞 SLA 管理能力。**  
> 与 [09_Release_Gates](09_Release_Gates.md) 的发布门禁形成"发现 → 修复 → 发布"完整闭环。
