# 09 — 发布门禁 (Release Gates)

> **对应 Sheet:** `09_Release_Gates`
> **牵引方向:** SecGuardian 发布流水线安全门禁体系——确保安全扫描结果在软件发布前自动卡点。

---

## 1. 概述

发布门禁是在 CI/CD Pipeline 中设置的安全检查关卡。本 sheet 涵盖 **4 大发布门禁分类**，每类 20 条要求，共计 **80 条门禁控制项**。

---

## 2. 分类体系

| 分类 | 控制目标 | 严重度分布 | 检查时机 |
|---|---|---|---|
| **Build** (构建) | 构建制品完整性、依赖完整性 | 8×Medium, 6×High, 6×Critical | 代码合并 → 构建完成 |
| **Test** (测试) | 安全测试满足质量门禁 | 8×Medium, 6×High, 6×Critical | 构建完成后 |
| **Security** (安全扫描) | SAST/SCA/容器扫描均通过 | 4×Medium, 8×High, 8×Critical | 测试通过后 |
| **Compliance** (合规审批) | 合规检查、人工审批 | 4×Medium, 6×High, 10×Critical | 发布前最后关卡 |

---

## 3. 分类详解与最佳实践

### 3.1 构建门禁 (Build Gates)

| 控制项 | 要求 | 严重度 | 技术实现 |
|---|---|---|---|
| BLD-01 | 代码签名与提交验证 (GPG) | Critical | Git commit signing |
| BLD-02 | 构建环境不可变更 | Medium | 不可变 CI Agent |
| BLD-03 | 使用 Lockfile (lock.json/go.sum) | Medium | Dependabot / Renovate |
| BLD-04 | 禁止调试代码构建到生产 | High | 构建参数校验 |
| BLD-05 | 构建日志存档 ≥ 90 天 | Medium | 日志归档策略 |
| BLD-06 | 构建时内嵌版本号+构建时间 | Medium | Git tag / SemVer |

### 3.2 测试门禁 (Test Gates)

| 控制项 | 要求 | 严重度 |
|---|---|---|
| TST-01 | 单元测试覆盖率 ≥ 80% | Medium |
| TST-02 | 安全测试用例全部通过 | High |
| TST-03 | 回归测试零失败 | High |
| TST-04 | 集成测试通过 | Medium |
| TST-05 | 性能测试无退化 (P99 < 基线 10%) | Medium |
| TST-06 | 模糊测试 (Fuzz Testing) 零崩溃 | Critical |

### 3.3 安全门禁 (Security Gates)

**门禁策略矩阵：**

| 扫描类型 | 检查项 | 阻断条件 | 严重度 |
|---|---|---|---|
| **SAST** | 代码静态扫描 | Critical 级别 > 0 | Critical |
| **SAST** | 代码静态扫描 | High 级别 ≥ 5 | Medium |
| **SCA** | 依赖漏洞扫描 | Critical CVE > 0 | Critical |
| **SCA** | 许可证违规 | 存在 GPL/AGPL | Critical |
| **容器扫描** | 镜像漏洞 | Critical > 0 | Critical |
| **IaC 扫描** | 配置错误 | 公开存储桶等 | Critical |
| **密钥检测** | 硬编码密钥 | 任何泄露 | Critical |
| **SBOM 生成** | 物料清单 | 缺失 SBOM | High |

**门禁策略配置示例 (YAML)：**

```yaml
# secguardian-gate-config.yaml
release_gates:
  build:
    required: [code_sign, lockfile_check, build_log]
  security:
    blocking:
      - scan: sast
        severity: critical
        threshold: 0
      - scan: sast
        severity: high
        threshold: 5
      - scan: sca
        severity: critical
        threshold: 0
      - scan: secrets
        severity: high
        threshold: 0
  compliance:
    blocking:
      - type: license
        blocked_licenses: [GPL-3.0, AGPL-3.0]
      - type: approval
        required_approvers: 2
```

### 3.4 合规门禁 (Compliance Gates)

| 控制项 | 要求 | 严重度 |
|---|---|---|
| CPL-01 | 安全管理员审批发布 | Critical |
| CPL-02 | 法规合规检查清单全部勾选 | Critical |
| CPL-03 | 安全扫描豁免清单审批通过的才能忽略 | High |
| CPL-04 | 变更关联的工单状态 Closed | Medium |
| CPL-05 | 发布备注中包含安全变更说明 | Medium |
| CPL-06 | 有回滚计划并审批 | High |

---

## 4. 业界最佳实践

### 4.1 安全门禁实现对比

| 平台 | 门禁机制 | 集成度 |
|---|---|---|
| **GitLab** | Security Approvals | 原生集成 SAST/SCA |
| **GitHub** | Branch Protection + CodeQL | 结合 GitHub Actions |
| **Jenkins** | Pipeline Stage Gate | 插件生态 |
| **Spinnaker** | Deployment Strategy Gates | 人工审批 + 自动判断 |
| **ArgoCD** | Sync Policy + PreSync | K8s 原生 |

### 4.2 门禁分类与企业规模

| 企业规模 | 建议门禁等级 | 说明 |
|---|---|---|
| 初创 (1-10 开发) | L1 — 仅构建/基础安全 | SAST 基本规则 + SCA |
| 成长 (10-50 开发) | L2 — 全安全扫描阻塞 | SAST + SCA + 密钥检测 |
| 中型 (50-200 开发) | L3 — 合规审批 | L2 + 人工审批 + 合规清单 |
| 大型 (>200 开发) | L4 — 全自动合规 | L3 + 自动合规证明 + 审计追溯 |

**SecGuardian 目标：支持 L1-L4 所有等级。**

---

## 5. SecGuardian 牵引方向

### 5.1 门禁集成设计

```
Git Push → PR Created
   │
   ├── SAST 扫描    ── Block if Critical > 0
   ├── SCA 扫描     ── Block if Critical CVE > 0
   ├── Secrets 扫描 ── Block if any found
   ├── IaC 扫描     ── Block if Critical misconfig
   │
   ▼
PR Merged → CI Build
   │
   ├── 容器扫描     ── Block if Critical > 0
   ├── SBOM 生成     ── Warn if missing
   ├── 单元测试      ── Block if coverage < 80%
   │
   ▼
Release → Compliance Gate
   │
   ├── 合规清单检查  ── Block if unchecked
   ├── 安全审批      ── Block if not approved
   │
   ▼
Deploy
```

### 5.2 快速起步

| 阶段 | 目标 | 集成 |
|---|---|---|
| Phase 1 | 基础 SAST 门禁 | GitHub Branch Protection + Webhook |
| Phase 2 | 全 SAST/SCA/Secrets 门禁 | 自定义 CI Step |
| Phase 3 | 合规门禁 | 审批流程集成 |
| Phase 4 | 多环境门禁 (dev/staging/prod) | Spinnaker / ArgoCD |

---

> **本文档指引 SecGuardian 构建完整的 CI/CD 安全门禁体系。**
> 与 [10_Vuln_SLA](10_Vuln_SLA.md) 的漏洞 SLA 管理形成"发现→修复→发布"闭环。
