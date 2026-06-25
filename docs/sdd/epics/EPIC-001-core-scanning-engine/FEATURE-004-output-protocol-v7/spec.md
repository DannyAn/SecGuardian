# Output Protocol v7.0 — Consumer-Centric Design (Final)

> **Feature**: FEATURE-004-output-protocol-v7
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: 📋 规划中
> **作者**: JonyAn + Codex

## 1. 问题陈述

### 1.1 当前痛点

1. **工程师工作流未被正确理解**：v5.0 的 `findings/<ns>/<detector>/` 目录树被误判为"scanner 内部视角"，实则是工程师的核心工作流——按检测器集中修完一类问题再修下一类。但缺乏一个有导航能力的统一入口。

2. **管理层/开发者在同一份报告里争空间**：`report.md` 试图用 7 节服务所有人（管理层看 §1、工程师看 §4、审计看 §6），结果谁都不好读。

3. **AI Agent 修复能力未充分利用**：fix 段是 human-readable 的 before/after，AI Agent 需要结构化修复数据。

4. **Finding 间的关系未建模**：一个 SQLi 和一个 PII 泄漏之间可能有攻击链路，但当前 finding 是孤立的。

### 1.2 设计目标

1. **工程师工作流不被打断**：保持 `findings/<ns>/<detector>/` 为核心工作流
2. **一个入口**：`executive-summary.md` 统一所有角色的第一步
3. **AI 可消费**：`remediation-pack.json` 结构化修复数据（含 finding 关联）
4. **报告精简**：report.md 精简到 5 节，管理内容归到 executive-summary
5. **HTML 自动生成**：管理层/审计可直接打开
6. **修复建议动态生成**：AI 根据代码上下文生成，不拷贝检测器模板

## 2. 需求规格

### REQ-001: 统一入口（executive-summary.md）

Renderer 生成 `human/executive-summary.md`，作为扫描结果的唯一入口，一页包含：

- 安全评分 + 等级
- 严重度分布（Critical/High/Medium/Low）
- 发现分布交叉表：检测器 × 涉及文件数 × 发现数（Top-5）
- 风险集中度：文件 × 发现数 × 占比（Top-5）
- Top 3 Critical 风险
- 导航引导：按角色指向下一步

数据来源：summary.json + findings 列表，Renderer 聚合不重建。

### REQ-002: AI 修复包（remediation-pack.json）

Renderer 从 findings/ 目录树聚合生成 `ai/remediation-pack.json`：

- 每条 finding 包含：root_cause, fix_strategy, before_code, after_code, effort_hours, verification, framework_specific（可选）
- 每条 finding 包含 `related_findings[]`：指向同一检测器/同文件/同函数的关联 finding ID
- related_findings 来源：AI Agent 标记的 relationships 字段 + Renderer 自动检测（同函数、同文件）

### REQ-003: report.md 精简

report.md 从 7 节精简到 5 节，只服务安全工程师：

```
§1 扫描元数据
§2 检出清单（表格）
§3 详细发现（四段式）
§4 修复路线图
§5 附录（检测器覆盖）
```

去掉 §1 管理层摘要、§1.5 验证漏斗、§2 合规仪表盘。

### REQ-005: HTML 报告自动生成

Renderer 自动生成 `report.html`，内容与 report.md 一致但带 CSS 排版：

- 使用 Python stdlib，不引入外部依赖
- 从 findings_data 直接生成（不解析 report.md）
- 嵌入 CSS（字体、颜色、表格样式、严重度色标）

### REQ-006: 协议文档升级 + 用户旅程

- `knowledge/protocols/scan-output.md` → v7.0
- `knowledge/protocols/findings-schema.json` → v1.1
- scan-output.md 新增"用户旅程"节（按角色编排阅读路径）

### REQ-007: AI Agent 输出不变

- 仍只输出 findings/ 目录树（v5.0 流程不变）
- AI 唯一增量工作：在 Finding 中可选添加 relationships 字段

### REQ-008: 修复建议动态生成

fix 段基于当前代码上下文动态组装，不从 detector 知识库拷贝固定模板。
detector 知识库的修复指引节改为修复模式参考（策略 + 边界条件）。
需更新 commands/*.md 的工作流指令。

## 3. 最终目录结构

```
scan-root/
├── human/                         ★ 统一入口
│   └── executive-summary.md        一页仪表盘 + 发现分布 + 导航
├── findings/                      ★ 工程师核心工作流（v5.0 不变）
│   └── <ns>/<detector>/<finding-id>.json
├── ai/
│   └── remediation-pack.json      ★ AI 修复包（含 related_findings）
├── report.md                      ★ 安全工程师报告（精简5节）
├── report.html                    ★ 管理层/审计 HTML
├── findings.json                  轻量索引
├── summary.json                   仪表盘（机读）
├── results.sarif                  CI/CD
├── status.json                    CI 门禁
├── delta.json                     增量对比
├── manifest.json                  扫描元数据
├── dismissed.json                 验证管道
├── verification-audit.json        验证管道
└── index.json                     索引器
```

## 4. 用户旅程

### 工程师首次使用（无 CI/CD）

```
Step 1: human/executive-summary.md
  → "SQLi 影响 3 个文件，先修它"
Step 2: findings/web/sql-injection/
  → 集中修完 parser.c (2个) + webapp.py (3个) 的 SQLi
Step 3: findings/web/xss/
  → 再修下一类
Step 4: 重扫 → human/executive-summary.md
  → 看评分涨了没
```

### 工程师 PR 场景（第 2+ 次）

```
Step 1: delta.json  → "这次新增了哪些 finding"
Step 2: findings/<type>/<detector>/  → 只修新增的
```

### AI 自动修复

```
Step 1: ai/remediation-pack.json
  → 丢给 Claude/Codex → 自动修复
```

### 管理层/采购评估

```
Step 1: human/executive-summary.md  → 一页看安全态势
Step 2: report.html                 → 浏览器打开精美报告
```

## 5. 不做什么

- ❌ developer/by-file/ — 1000+ 文件项目不可行，高频用法是 findings/<ns>/<detector>/
- ❌ ai/attack-graph.json — 无真实消费者，relationships 嵌入 remediation-pack
- ❌ compliance/ 目录 — "多出来的概念都是负担"
- ❌ 修复建议固定模板 — AI Agent 根据代码上下文动态生成
