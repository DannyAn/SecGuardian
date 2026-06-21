# SecGuardian 企业安全治理标准

> 本目录由 `Enterprise_Security_Governance_Standard.xlsx` 整理生成。  
> 每个文档结合了原始表格结构与业界最佳实践，指引 SecGuardian 产品未来发展。  
> 生成日期: 2026-05-31

---

## 文档列表

| # | 文档 | 描述 | 原始 Sheet |
|---|---|---|---|
| 00 | [治理模型](00_Governance_Model.md) | 六大安全域顶层框架设计 | `00_Governance_Model` |
| 01 | [安全红线](01_Security_Redlines.md) | 120 条不可妥协的安全底线要求 | `01_Security_Redlines` |
| 02 | [安全编码](02_Secure_Coding.md) | 120 条多语言安全编码规则 | `02_Secure_Coding` |
| 03 | [架构评审](03_Architecture_Review.md) | 80 条架构设计阶段安全评审要求 | `03_Architecture_Review` |
| 04 | [威胁建模](04_Threat_Modeling.md) | 80 条 STRIDE 威胁建模控制项 | `04_Threat_Modeling` |
| 05 | [SAST 规则](05_SAST_Rules.md) | 100 条静态分析检测规则 | `05_SAST_Rules` |
| 06 | [SCA 治理](06_SCA_Governance.md) | 80 条开源组件治理要求 | `06_SCA_Governance` |
| 07 | [容器与 K8s](07_Container_K8s.md) | 80+ 容器与 Kubernetes 安全要求 | `07_Container_K8s` |
| 08 | [云安全](08_Cloud_Security.md) | 100 条云安全基线配置要求 | `08_Cloud_Security` |
| 09 | [发布门禁](09_Release_Gates.md) | 80 条 CI/CD 安全门禁控制项 | `09_Release_Gates` |
| 10 | [漏洞 SLA](10_Vuln_SLA.md) | 40 条漏洞响应 SLA 要求 | `10_Vuln_SLA` |
| 11 | [隐私合规](11_Privacy_Compliance.md) | 80 条隐私合规控制项 | `11_Privacy_Compliance` |
| 12 | [安全 KPI](12_Security_KPI.md) | 40 项安全成效度量指标 | `12_Security_KPI` |

---

## 治理框架全景

```
顶层治理         00_Governance_Model
                    │
     ┌──────────────┼──────────────┐
     │              │              │
  设计阶段         开发阶段       运维阶段
  03_Architecture  02_Secure_Coding  07_Container_K8s
  04_Threat_Model  05_SAST_Rules     08_Cloud_Security
                   06_SCA_Governance  11_Privacy_Compliance
                    │
                    ▼
              门禁/度量/闭环
              01_Security_Redlines
              09_Release_Gates
              10_Vuln_SLA
              12_Security_KPI
```

---

## 与 SecGuardian Skills 的映射关系

| 治理域 | 现有 Skill | 能力匹配度 | 主要缺口 |
|---|---|---|---|
| SSDLC | `secguard` | ✅ 基础覆盖 | 架构评审、威胁建模 |
| 应用安全 | `secreview` | ⚡ 部分覆盖 | ASVS L2、人工评审辅助 |
| 开源治理 | `secaudit` | ⚡ 部分覆盖 | SBOM 生成、License 策略 |
| 云安全 | — | ❌ 完全缺失 | IaC 扫描、CIS 基线 |
| 容器/K8s | — | ❌ 完全缺失 | 镜像扫描、K8s 配置 |
| 隐私合规 | — | ❌ 完全缺失 | PII 检测、GDPR 合规 |
| 发布门禁 | — | ❌ 完全缺失 | CI/CD 集成 |
| 漏洞 SLA | — | ❌ 完全缺失 | 自动化跟踪 |
| KPI 度量 | — | ❌ 完全缺失 | 数据采集与仪表盘 |

> ✅ = 已有  ⚡ = 部分  ❌ = 缺失

---

## 后续行动建议

### 短期 (0-3 月)
1. 优先补齐 **SAST 规则** (05) 中的注入+密钥检测规则到 50 条
2. 建立 **SCA 治理** (06) 的依赖扫描 + SBOM 基础能力
3. 实现 **安全红线** (01) 的红线标记与输出规范

### 中期 (3-12 月)
1. 建设 **容器/K8s** (07) 和 **云安全** (08) 的 IaC 扫描能力
2. 建立 **威胁建模** (04) 自动化引擎
3. 集成 **发布门禁** (09) 到 CI/CD Pipeline
4. 启动 **安全 KPI** (12) 数据采集

### 长期 (12+ 月)
1. 实现 **隐私合规** (11) 的全法规覆盖 (GDPR/PIPL/CCPA)
2. 建设 **安全 KPI 仪表盘** + AI 驱动改进建议
3. 实现 **全治理域自动化评估**——一个输入，跨域合规报告输出

---

> **致谢：** 本文档体系参考了 NIST SSDF、OWASP ASVS、CIS Benchmarks、OpenSSF Scorecard、ISO 27001 等行业标准。
