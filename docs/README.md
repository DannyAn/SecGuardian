# SecGuardian 文档

## SDD — Spec-Driven Development（开发流程核心）

> SecGuardian 采用 **Feature Package + Local Context** 的 SDD 方法论。
> 按需求组织文档，每个 Feature 自带 spec / adr / plan / progress / tasks / changes 全套闭环。

| 目录 | 用途 |
|------|------|
| [`sdd/README.md`](sdd/README.md) | ★ SDD 方法论说明 + 七原则 + Epics 全景 |
| [`sdd/epics/EPIC-001-core-scanning-engine/`](sdd/epics/EPIC-001-core-scanning-engine/) | 核心扫描引擎 — 输出协议演进 + 检测器质量增强 |
| [`sdd/epics/EPIC-002-platform-engineering/`](sdd/epics/EPIC-002-platform-engineering/) | 平台工程 — Manifest Tokens + MCP Server |
| [`sdd/brainstorm-log.md`](sdd/brainstorm-log.md) | 🧠 Brainstorm 设计决策全记录 |
| [`next-up.md`](next-up.md) | 下版本待办 — 按 P0/P1/P2 排列 |

## 参考资料

| 文件 | 用途 |
|------|------|
| [`reference/whitepaper.md`](reference/whitepaper.md) | 技术白皮书 (v0.6.0) |
| [`reference/interview-ppt.md`](reference/interview-ppt.md) | 面试技术展示 PPT |
| [`reference/portfolio-deepseek.md`](reference/portfolio-deepseek.md) | 产品展示（面向投资方） |
| [`reference/beijing-ai-security-companies.md`](reference/beijing-ai-security-companies.md) | 北京 AI 安全公司调研 |
| [`reference/ci-integration-guide.md`](reference/ci-integration-guide.md) | CI 集成指南 — GitHub Actions / GitLab CI / Azure DevOps |
| [`reference/gitlab-ci-template.md`](reference/gitlab-ci-template.md) | GitLab CI 模板 |

## 工程实践

| 目录 | 用途 |
|------|------|
| [`dogfood/`](dogfood/) | Dogfood 自扫描记录 |
| [`templates/`](templates/) | 文档模板（案例研究等） |

## 商业与市场

| 文件 | 用途 |
|------|------|
| [`competitive-analysis.md`](competitive-analysis.md) | 竞品分析 — Coverity/Snyk/SonarQube/CodeQL 对比 |
| [`roadmap-to-commercial.md`](roadmap-to-commercial.md) | 商业化路线图 |
| [`work-plan.md`](work-plan.md) | 历史工作计划（v0.1~v0.2，保留作参考） |
| [`SecGuardian-Technical-Whitepaper.pptx`](SecGuardian-Technical-Whitepaper.pptx) | 技术白皮书 PPT |

## 治理

| 目录 | 用途 |
|------|------|
| [`governance/`](governance/) | 企业安全治理标准 — 12 个子章节，从顶层框架到安全 KPI |

## 命名规范

- SDD Feature 文件：`spec.md` / `adr.md` / `plan.md` / `progress.md`（Feature 目录内固定命名）
- SDD Epic/Feature 目录：`EPIC-NNN-description/` / `FEATURE-NNN-description/`（编号 + kebab-case）
- SDD Task 文件：`TASK-NNN-description.md`
- SDD Change 文件：`CHANGE-NNN-description.md`
- 参考文档：`reference/kebab-case.md`
- 治理文件：`governance/NN_Title_Name.md`（数字前缀保证顺序）
