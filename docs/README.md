# SecGuardian 文档

## 目录

### 设计与规划

| 文件 | 用途 |
|------|------|
| [`design-journal.md`](design-journal.md) | ★ 设计决策日志 — 每次架构讨论的头脑风暴、方案权衡、最终决策 |
| [`roadmap-to-commercial.md`](roadmap-to-commercial.md) | 商业化路线图 — 从技术产品到商业产品的演进路径 |
| [`next-up.md`](next-up.md) | 下版本待办 — 按 P0/P1/P2 排列的优先级任务 |
| [`work-plan.md`](work-plan.md) | 历史工作计划（v0.1~v0.2 阶段，保留作参考） |

### 竞争与市场

| 文件 | 用途 |
|------|------|
| [`competitive-analysis.md`](competitive-analysis.md) | 竞品分析 — Coverity/Snyk/SonarQube/CodeQL 对比 |
| [`portfolio-for-deepseek.md`](portfolio-for-deepseek.md) | 产品展示 — 面向 DeepSeek 等投资方的介绍材料 |

### 工程实践

| 文件 | 用途 |
|------|------|
| [`ci-integration-guide.md`](ci-integration-guide.md) | CI 集成指南 — GitHub Actions / GitLab CI / Azure DevOps |
| [`gitlab-ci-template.md`](gitlab-ci-template.md) | GitLab CI 模板 |
| [`case-study-template.md`](case-study-template.md) | 案例研究模板 — 客户安全审计报告范例 |

### 治理

| 目录 | 用途 |
|------|------|
| [`governance/`](governance/) | 治理框架 — 12 个安全治理子章节 |

### 历史档案

| 文件 | 说明 |
|------|------|
| [`archive/codeplan/codeplan-v2-overview.md`](archive/codeplan/codeplan-v2-overview.md) | CodePlan V2 总体设计 |
| [`archive/codeplan/codeplan-v2-packaging.md`](archive/codeplan/codeplan-v2-packaging.md) | 打包安装方案 |
| [`archive/codeplan/codeplan-v2-command-skill.md`](archive/codeplan/codeplan-v2-command-skill.md) | 命令与 Skill 对齐 |
| [`archive/codeplan/codeplan-v2-execution.md`](archive/codeplan/codeplan-v2-execution.md) | 执行计划 |
| [`archive/codeplan/codeplan-v2-study.md`](archive/codeplan/codeplan-v2-study.md) | 调研笔记 |
| [`archive/codeplan/codeplan-v2-study-addendum.md`](archive/codeplan/codeplan-v2-study-addendum.md) | 调研补遗 |

## 命名规范

- 活跃文档：`kebab-case.md`（小写连字符，如 `design-journal.md`）
- 历史档案：`archive/<topic>/<topic>-<descriptor>.md`（统一前缀 + kebab-case）
- 治理文件：`governance/NN_Title_Name.md`（数字前缀保证顺序）
- 新增文档：先判断属于哪个分类，按对应规范命名
