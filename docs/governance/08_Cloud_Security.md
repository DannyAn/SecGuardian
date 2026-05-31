# 08 — 云安全配置 (Cloud Security Configuration)

> **对应 Sheet:** `08_Cloud_Security`  
> **牵引方向:** SecGuardian 云安全基线检测能力——覆盖 IAM、存储、网络和密钥管理四大云安全领域。

---

## 1. 概述

云安全配置管理确保云资源按照最小权限和基线加固原则配置。本 sheet 涵盖 **4 大云安全分类**，每类 24~26 条要求，共计 **100 条控制项**。

---

## 2. 分类体系

| 分类 | 控制目标 | 严重度分布 | 业界对标 |
|---|---|---|---|
| **IAM** (身份与访问管理) | 最小权限、身份治理、访问分析 | 8×Medium, 8×High, 8×Critical | CIS AWS/GCP/Azure Benchmark |
| **Storage** (存储安全) | 数据存储的加密、访问控制 | 8×Medium, 8×High, 8×Critical | CIS Storage Benchmark |
| **Network** (网络安全) | 网络隔离、传输加密、防火墙规则 | 8×Medium, 8×High, 8×Critical | CIS Networking Benchmark |
| **Key Mgmt** (密钥管理) | 加密密钥生命周期管理 | 8×Medium, 8×High, 8×Critical | NIST SP 800-57 |

---

## 3. 分类详解与最佳实践

### 3.1 IAM（身份与访问管理）

**CIS 核心基线要求：**

| 控制项 | 要求 | 严重度 | AWS | GCP | Azure |
|---|---|---|---|---|---|
| IAM-01 | 禁用 root/超级管理员账号的密钥登录 | Critical | ✅ IAM.1 | ✅ | ✅ |
| IAM-02 | MFA 开启比例 > 90% | High | ✅ IAM.2 | ✅ | ✅ |
| IAM-03 | 最小权限策略（非 * 权限） | Critical | ✅ IAM.3 | ✅ | ✅ |
| IAM-04 | 定期清理未使用的 IAM 用户/角色 | Medium | ✅ IAM.4 | ✅ | ✅ |
| IAM-05 | 临时凭据 (STS) 设置最大有效期 | High | ✅ IAM.5 | ✅ | ✅ |
| IAM-06 | 信任策略限制外部访问 | Critical | ✅ IAM.6 | ✅ | ✅ |
| IAM-07 | 权限边界 (Permission Boundary) | Medium | ✅ | ❌ | ✅ |

**最佳实践：**
- **最小权限** — AWS IAM Access Analyzer / GCP Policy Analyzer 持续检测超额权限
- **零信任** — 每次请求都需要认证和授权 (Just-In-Time Access)
- **基础设施即代码** — IAM 策略使用 Terraform/Pulumi 管理，不可手工修改

### 3.2 存储安全 (Storage Security)

| 控制项 | 要求 | 严重度 |
|---|---|---|
| STO-01 | 禁止存储桶/Blob 公开读取写 | Critical |
| STO-02 | 存储服务启用静态加密 | High |
| STO-03 | 存储访问日志启用 | Medium |
| STO-04 | 禁止使用不安全的传输协议 (HTTP) | Critical |
| STO-05 | 存储桶跨区域复制启用 | Medium |
| STO-06 | 对象版本控制启用 (防误删) | High |
| STO-07 | 生命周期策略清理过期数据 | Medium |
| STO-08 | 敏感数据使用 S3 Object Lock / WORM | High |

**CIS 基准检查项 (AWS)：**
- S3 存储桶 ACL 检查 → 禁用 ACL，使用存储桶策略
- S3 公共访问块 → 启用 BlockPublicAcls / BlockPublicPolicy / IgnorePublicAcls / RestrictPublicBuckets
- EBS 卷加密 → 默认启用

### 3.3 网络安全 (Network Security)

| 控制项 | 要求 | 严重度 |
|---|---|---|
| NET-01 | VPC/Security Group 最小规则 | Critical |
| NET-02 | 禁止 0.0.0.0/0 入口到管理端口 (22/3389) | Critical |
| NET-03 | 使用 WAF/DDoS 防护 | High |
| NET-04 | VPC Flow Logs 启用 | Medium |
| NET-05 | 启用 TLS 1.2+ (禁用 TLS 1.0/1.1) | High |
| NET-06 | 网络分段 (Public/Private/Management 子网) | High |
| NET-07 | 禁止使用经典网络/默认 VPC | Medium |
| NET-08 | 启用 AWS Shield / GCP Armor / Azure DDoS | Medium |

**CIS 核心网络检查：**

```
Security Group 规则分析:
  1. 发现 0.0.0.0/0 → 22 (SSH) → Critical
  2. 发现 0.0.0.0/0 → 3389 (RDP) → Critical
  3. 发现全端口开放 (0-65535) → Critical
  4. 未关联到任何资源的 Security Group → Medium
  5. 未使用的网络 ACL (NACL) → Low
```

### 3.4 密钥管理 (Key Management)

**NIST SP 800-57 密钥生命周期：**

| 阶段 | 控制要求 | 严重度 |
|---|---|---|
| **创建** | 使用硬件安全模块 (HSM) / 云 KMS 生成 | High |
| **分发** | 使用安全通道传输，不硬编码 | Critical |
| **使用** | 最小访问范围，日志记录使用情况 | Medium |
| **轮转** | 自动轮转 (≤ 1 年) | High |
| **归档** | 密钥版本管理，保留历史版本 | Medium |
| **销毁** | 安全删除不再使用的密钥 | Critical |

**云 KMS 最佳实践：**

```
AWS KMS:
  ├─ 自动轮转 (每年自动轮换 CMK)
  ├─ 密钥策略限制 (Resource-based + IAM-based)
  ├─ Grant 临时访问 (避免长期权限)
  └─ CloudTrail 记录所有密钥使用

GCP Cloud KMS:
  ├─ 密钥版本化 (定期创建新版本)
  ├─ 自动轮转 (可配置轮转周期)
  ├─ IAM 条件绑定 (基于来源 IP / 时间)
  └─ Key Access Justifications (请求理由)
```

---

## 4. 多云安全基线

### 4.1 跨云通用基线

| 检查项 | AWS | GCP | Azure |
|---|---|---|---|
| 禁用根账号密钥 | IAM.1 | IAM | Security |
| 默认加密 | S3/EBS-KMS | CMEK | SSE |
| 网络日志 | VPC Flow Logs | VPC Flow Logs | NSG Flow Logs |
| 配置审计 | Config | Asset Inventory | Policy |
| 密钥轮转 | KMS Auto Rotation | KMS Rotation | Key Vault Rotation |

### 4.2 工具对标

| 工具 | 覆盖面 | 特点 |
|---|---|---|
| **AWS Security Hub** | AWS 全服务 | 集成 GuardDuty / Inspector / Macie |
| **AWS Config** | AWS 资源配置 | 自定义规则，合规评分 |
| **GCP Security Command Center** | GCP 全服务 | 威胁检测 + 漏洞管理 |
| **Azure Defender for Cloud** | Azure + 混合 | 安全评分，CSPM |
| **Checkov** | IaC 扫描 | Terraform / CloudFormation 静态分析 |
| **tfsec** | Terraform 安全 | 自定义策略，PR 集成 |

---

## 5. SecGuardian 牵引方向

### 5.1 当前缺口

SecGuardian 当前无任何云安全检测能力。这是**最大的能力空白**之一。

### 5.2 发展路线

| 阶段 | 能力 | 具体行动 |
|---|---|---|
| **Phase 1** | IaC 静态分析 | 集成 Checkov / tfsec，扫描 Terraform/CloudFormation |
| **Phase 2** | 云配置评估 | 集成云 Provider SDK，实时检查运行期配置 |
| **Phase 3** | 合规映射 | 检测结果映射 CIS / PCI DSS / SOC2 |
| **Phase 4** | 合规自动化 | 自动修复违规配置 (如自动关闭公开 Bucket) |

### 5.3 IaC 扫描优先策略

**为什么先从 IaC 开始？**
- 无需云 API 访问权限
- 可在 CI/CD Pipeline 早期发现问题
- 与代码审查流程天然集成

**支持的 IaC 格式：**

| 格式 | 优先级 | 场景 |
|---|---|---|
| Terraform (HCL) | P0 | 基础设施定义 |
| CloudFormation (YAML/JSON) | P1 | AWS 专用 |
| Pulumi (TypeScript/Python) | P1 | 可编程 IaC |
| Helm Chart | P2 | K8s 部署模板 |

**IaC 检查示例：**

```yaml
# "S3 Bucket should not be publicly accessible"
id: CIS-1.1
resource: aws_s3_bucket
checks:
  - path: "acl"
    not_equals: "public-read"
  - path: "acl" 
    not_equals: "public-read-write"
severity: Critical
```

---

> **本文档指引 SecGuardian 构建云安全基线检测能力。**  
> 结合 [07_Container_K8s](07_Container_K8s.md) 的容器安全，形成"代码→容器→云"三层安全防护体系。
