# 06 — SCA 开源治理 (Software Composition Analysis Governance)

> **对应 Sheet:** `06_SCA_Governance`  
> **牵引方向:** SecGuardian 开源组件治理能力——覆盖许可证合规、CVE 漏洞管理、依赖新鲜度和 SBOM 管理。

---

## 1. 概述

SCA (Software Composition Analysis) 管理组织使用的开源组件和第三方依赖的安全风险与合规风险。本 sheet 涵盖 **5 大 SCA 治理分类**，每类 16 条要求，共计 **80 条控制项**。

---

## 2. 分类体系

| 分类 | 控制目标 | 严重度分布 | 业界标准 |
|---|---|---|---|
| **License** (许可证合规) | 确保开源组件许可证与项目使用方式兼容 | 8×Medium, 6×High, 2×Critical | SPDX / OpenChain |
| **Critical CVE** (严重漏洞) | 识别并修复组件中的严重安全漏洞 | 4×Medium, 8×High, 4×Critical | NVD / GitHub Advisory |
| **Dependency Freshness** (依赖新鲜度) | 确保依赖版本不低于安全基线 | 6×Medium, 6×High, 4×Critical | OpenSSF Scorecard |
| **SBOM** (软件物料清单) | 自动化维护完整的依赖清单 | 6×Medium, 6×High, 4×Critical | CycloneDX / SPDX |
| **Approval** (引入审批) | 新建依赖必须经过安全评估 | 4×Medium, 6×High, 6×Critical | OpenChain |

---

## 3. 分类详解与最佳实践

### 3.1 许可证合规 (License Compliance)

**常见许可证类型：**

| 许可证 | 类型 | 注意事项 |
|---|---|---|
| MIT / Apache 2.0 | 宽松 (Permissive) | 可商业使用，需保留版权声明 |
| GPL v2/v3 | 强 Copyleft | 修改代码必须开源 (传染性) |
| LGPL | 弱 Copyleft | 动态链接不受限，静态链接受限 |
| AGPL | 网络 Copyleft | 网络使用也视为分发 |
| BSD / ISC | 宽松 | 类似 MIT |
| MPL 2.0 | 弱 Copyleft | 文件级 Copyleft |

**合规控制要求：**

| 控制项 | 要求 | 严重度 |
|---|---|---|
| LC-01 | 季度自动扫描所有依赖许可证 | Medium |
| LC-02 | 禁止 GPL 许可引入商业闭源项目 | Critical |
| LC-03 | 所有依赖注明许可证和归属 | Medium |
| LC-04 | 许可证变更时立即通知 | High |

### 3.2 严重 CVE 管理 (Critical CVE Management)

**漏洞优先级矩阵 (SSVC / EPSS)：**

| 因素 | 评估维度 |
|---|---|
| 利用成熟度 | Proof of Concept / 活跃利用 / 自动化利用 |
| 影响严重度 | CVSS 3.1 评分 |
| 资产暴露 | 是否公开可达 |
| 修复复杂度 | 有无补丁 / 替代组件 |

**SLA 要求：**

| 严重度 | 发现 → 修复 | 修复 → 上线 |
|---|---|---|
| Critical (CVSS ≥ 9.0) | 24 小时 | 72 小时 |
| High (CVSS 7.0-8.9) | 7 天 | 14 天 |
| Medium (CVSS 4.0-6.9) | 30 天 | 45 天 |
| Low (CVSS < 4.0) | 下一发布周期 | 下一发布周期 |

### 3.3 依赖新鲜度 (Dependency Freshness)

**原则：** 依赖不能落后最新安全版本超过特定幅度。

| 指标 | 阈值 | 严重度 |
|---|---|---|
| 主版本落后 | ≥ 2 个主版本 | High |
| 次版本落后 | ≥ 5 个次版本 | Medium |
| 补丁版本落后 | ≥ 10 个补丁 | Medium |
| 已知存在漏洞且 ≥ 30 天未升级 | 任何版本 | Critical |
| 组件已进入 EOL | 已废弃 | High |

**实践：** 使用 Dependabot / Renovate 自动升级+降噪。

### 3.4 SBOM（软件物料清单）

**SBOM 格式要求 (ISO/IEC 5962:2021)：**

| 要求 | 说明 |
|---|---|
| 格式 | CycloneDX (推荐) 或 SPDX |
| 粒度 | 包含直接依赖和传递依赖 |
| 频率 | 每次发布自动生成 |
| 字段 | 组件名称、版本、许可证、下载来源、哈希值 |

**SBOM 最佳实践：**

```
Publish 时:
  1. 生成 CycloneDX JSON
  2. 存入制品仓库 (Artifactory / Nexus)
  3. 签名信任 (cosign 签名)
  4. 汇总至中央 SBOM 管理平台
```

### 3.5 引入审批 (Approval)

**依赖引入流程：**

```
开发者申请引入新依赖
   │
   ├─ 许可证检查 (禁止 GPL / AGPL)
   ├─ 安全扫描 (已知 CVE 库)
   ├─ 维护性评估 (Star / 贡献者 / 最近更新)
   ├─ 替代方案审查 (是否有更好选择)
   │
   ▼
安全团队审批 → 加入允许列表
```

---

## 4. 业界工具对标

| 工具 | 类型 | 特点 |
|---|---|---|
| **Snyk** | SaaS | 开发者友好，CI/CD 集成好，覆盖面广 |
| **Black Duck** | 商业 | 深度许可证分析，大型企业首选 |
| **OWASP Dependency-Check** | 开源 | 免费，NVD 集成 |
| **Trivy** | 开源 | 镜像+仓库+代码库多合一 |
| **Renovate / Dependabot** | 开源/SaaS | 自动升级 PR，降低维护成本 |

**SecGuardian 定位：** 与现有工具互补，提供**策略层统一治理**——各工具结果汇聚后，按本文档的 80 条控制项判定合规性。

---

## 5. SecGuardian 牵引方向

### 5.1 快速起步

| 阶段 | 行动 | 预期产出 |
|---|---|---|
| Phase 1 | 集成 Trivy 作为扫描引擎 | CVE + 许可证扫描能力 |
| Phase 2 | SBOM 自动生成 (CycloneDX) | 每次构建输出 SBOM |
| Phase 3 | 策略引擎 — 80 条控制项 | 合规判定 + 门禁 |
| Phase 4 | 自动升级 PR | 基于 Renovate 模板 |

### 5.2 与 SecGuardian 现有能力融合

```
secaudit skill
   │
   ├─ 代码审计 (已存在)
   ├─ SCA 扫描 (新增)
   │   ├─ 依赖清单解析 (pom.xml / package.json / Cargo.toml / go.mod)
   │   ├─ CVE 匹配 (NVD / OSV 数据库)
   │   └─ 许可证合规判定 (SPDX 记录)
   │
   └─ 输出: SCA 扫描报告 (统一格式)
```

### 5.3 知识库计划

在 `knowledge/concepts/` 中增加：

```
knowledge/concepts/
├── sca-overview.md          # SCA 概念与治理原则
├── license-compliance.md    # 许可证合规指南
├── cve-management.md        # CVE 响应流程
└── sbom-standard.md         # SBOM 格式说明 (CycloneDX)
```

---

> **本文档指引 SecGuardian 构建 SCA 治理能力。**  
> 与 [05_SAST_Rules](05_SAST_Rules.md) 的静态分析互补，覆盖"自有代码分析" + "开源依赖分析"两个维度。
