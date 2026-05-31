# 00 — 安全治理模型 (Security Governance Model)

> **对应 Sheet:** `00_Governance_Model`  
> **牵引方向:** SecGuardian 安全治理框架的顶层设计，决定产品应覆盖哪些安全域以及遵循哪些行业标准。

---

## 1. 概述

安全治理模型是 SecGuardian 的安全能力顶层架构。它将企业安全需求映射为 **6 个核心域**，每个域绑定一个或多个行业基准标准，并明确对应的**强制性策略要求**。该模型为产品迭代提供了"做什么"和"做到什么程度"的权威指引。

---

## 2. 六大域治理框架

| 域 | 标准 | 强制性策略 | 说明 |
|---|---|---|---|
| **SSDLC** | NIST SP 800-218 (SSDF) | 安全活动嵌入 SDLC 各阶段 | 需求→设计→编码→测试→部署→运维全流程覆盖 |
| **应用安全** | OWASP ASVS v4.0 | 安全需求基线化 | 验证、会话管理、访问控制、错误处理等 |
| **开源治理** | OpenSSF Scorecard / SLSA | SCA + SBOM 强制执行 | 依赖扫描、许可证合规、供应链安全 |
| **云安全** | CIS Benchmarks | 基线加固强制执行 | IAM、存储、网络、日志等云资源配置基线 |
| **安全运维** | PSIRT / FIRST | 漏洞响应流程 | 安全公告、漏洞接收、分诊、修复、披露 |
| **审计合规** | ISO 27001:2022 | 证据留存与定期评审 | 控制措施有效性度量、审计证据归档 |

---

## 3. 业界最佳实践对标

### 3.1 NIST SSDF (Secure Software Development Framework)

NIST SP 800-218 定义了 **4 个实践域**：

- **PO**（准备）—— 安全培训、供应链安全、安全架构
- **PS**（保护）—— 代码完整性、凭证管理、配置加固
- **PW**（生产）—— 漏洞发现、漏洞评估、漏洞修复
- **RV**（响应）—— 漏洞接收、协调披露、根因分析

**SecGuardian 对齐点:**
- `secguard` skill → PO（安全基线检测）
- `secreview` skill → PS + PW（代码审查 + 漏洞发现）
- `secaudit` skill → RV（审计追踪 + 合规报告）

### 3.2 OWASP ASVS (Application Security Verification Standard)

ASVS v4.0 分为 **3 个验证等级 (L1/L2/L3)**：

| 等级 | 适用场景 | 检查项数 |
|---|---|---|
| L1 | 所有应用（自动化扫描可达） | ~40 项 |
| L2 | 处理敏感数据（需人工审查） | ~120 项 |
| L3 | 高安全环境（深度防御） | ~180 项 |

**SecGuardian 对齐点:** 当前 detectors 体系应覆盖 L1 全部 + L2 核心项。

### 3.3 OpenSSF 框架

- **Scorecard** — 开源项目安全态势评分（8 分以上为健康）
- **SLSA** — 供应链等级（L1-L4），要求构建完整性
- **SBOM** — SPDX 或 CycloneDX 格式，每次发布自动生成

### 3.4 CIS Benchmarks

覆盖 25+ 云服务商/平台，核心基线包括：
- 最小权限原则
- 默认 Deny 规则
- 启用审计日志
- 加密传输和静态

### 3.5 ISO 27001:2022

- **控制项 A.8** — 资产管理
- **控制项 A.14** — 系统获取、开发与维护
- **控制项 A.16** — 事件管理
- **控制项 A.18** — 合规性

---

## 4. 对 SecGuardian 的牵引方向

### 短期（未来 3 个月）

1. **SSDLC 嵌入** — 向 `skills/` 注入 NIST SSDF PO/PS 实践检测点
2. **OWASP ASVS L1 全覆盖** — 当前 detectors 覆盖 6 个分类，需扩展至 40+ 检测点
3. **SBOM 自动生成** — 在 `secaudit` 技能中集成 CycloneDX 输出

### 中期（3-12 个月）

1. **多标准对齐引擎** — 一个检测结果可映射到 NIST / OWASP / CIS 多个标准
2. **ASVS L2 支持** — 人工审查辅助模板 + 半自动化检查
3. **SLSA L2 构建验证** — 集成到 CI/CD pipeline
4. **ISO 27001 控制项映射** — 检测结果直接对应 Annex A 控制项

### 长期（12+ 个月）

1. **治理仪表盘** — 实时展示六大域的安全态势和标准覆盖率
2. **自适应等级推荐** — 根据业务场景自动推荐 ASVS/CIS/SLSA 目标等级
3. **合规自动化** — 一键生成 ISO 27001 / SOC2 合规报告

---

## 5. 标准对照速查

| 标准 | 版本 | 关键链接 |
|---|---|---|
| NIST SSDF | SP 800-218 | https://csrc.nist.gov/publications/detail/sp/800-218/final |
| OWASP ASVS | v4.0 | https://owasp.org/www-project-application-security-verification-standard/ |
| OpenSSF Scorecard | v4 | https://securityscorecards.dev/ |
| CIS Benchmarks | v8 | https://www.cisecurity.org/cis-benchmarks/ |
| ISO 27001 | 2022 | https://www.iso.org/standard/27001 |
| SLSA | v1.0 | https://slsa.dev/ |

---

## 6. 与 SecGuardian Skills 映射关系

| 治理域 | 关联 Skill | 现有 detectors | 缺口 |
|---|---|---|---|
| SSDLC | `secguard` | 输入验证、内存安全、错误处理 | 缺少架构评审、威胁建模 |
| 应用安全 | `secreview` | 注入、XSS、路径遍历 | 缺少反序列化、SSRF |
| 开源治理 | `secaudit` | 许可证扫描、CVE 检测 | 缺少 SBOM 生成、依赖新鲜度 |
| 云安全 | — | — | 完全缺失（CIS 基线检测） |
| 安全运维 | — | — | 完全缺失（PSIRT 流程） |
| 审计合规 | `secaudit` | 审计日志 | 缺少控制项映射 |

---

> **本文档为 SecGuardian 治理框架的顶层设计指引。**  
> 后续每个 sheet 的详细文档将在此框架下展开具体控制要求。
