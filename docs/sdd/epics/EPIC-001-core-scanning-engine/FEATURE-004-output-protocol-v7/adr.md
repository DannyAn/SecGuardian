# ADR — Output Protocol v7.0 Architecture Decisions

> **Feature**: FEATURE-004-output-protocol-v7
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-004: Engineer Workflow = findings/<ns>/<detector>/

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

工程师的核心工作流是按检测器修完一类问题再修下一类。
`findings/<ns>/<detector>/` 目录树保持为核心工作流入口，不做 by-file 替换。

### Reason

- 工程师的实际行为：全量扫描 → "SQLi 影响 3 个文件，先修" → `findings/web/sql-injection/` → 修完 → 下一类
- 按文件分组（by-file）在 1000+ 文件项目里生成 1000+ .md，是灾难
- findings/<ns>/<detector>/ 天然支持"集中修复一类问题"的工作流

### Rejected Alternatives

- **developer/by-file/**：1000+ 文件项目不可扩展，高频用法是 detector 视角
- **report.md 作为唯一入口**：report.md 是安全工程师的深入阅读材料，不是第一页

### Consequences

- findings/<ns>/<detector>/ 保持 v5.0 设计不变
- executive-summary.md 承担入口职责，用"发现分布交叉表"告诉工程师"哪个检测器影响了哪些文件"

---

## ADR-005: executive-summary.md 作为统一入口

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

human/executive-summary.md 是扫描结果的唯一入口。一页包含：
安全评分 + 发现分布交叉表（检测器 × 文件数 × 发现数）+ 风险集中度（文件 × 发现数）+ 导航引导。

### Reason

- 当前扫描结果没有"第一页"——15+ 文件丢在 scan root，新手不知道先打开哪个
- 一个入口服务所有角色：工程师看发现分布决定先修哪类、管理层看评分、AI 看 summary
- 发现分布交叉表回答了工程师的核心问题："SQLi 影响了哪几个文件？"

### Consequences

- Renderer 新增 render_executive_summary() 函数
- 发现分布只展示 Top-5（全量扫描时避免表过长）

---

## ADR-006: 修复建议动态生成，非模板拷贝

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

修复建议由 AI Agent 根据代码上下文动态组装，不从 detector 知识库拷贝固定文本。
detector 知识库的修复指引节改为修复模式参考——告诉 AI 这类问题的通用修复策略和边界条件。

### Reason

- 固定模板导致所有 SQLi 的修复建议一模一样——工程师一看就知道是模板话术
- AI Agent 比模板更聪明：能理解框架（Flask vs Django vs Spring）、数据流路径、现有防御机制

### Consequences

- remediation-pack.json 的 fix_strategy 来自 AI Agent 对具体 finding 的分析
- 需要更新 commands/*.md 的工作流指令（从"引用知识库"改为"动态分析"）
- 不需要改协议

---

## ADR-007: Finding 关系嵌入 remediation-pack，不独立生成

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

finding 间的关联关系（related_findings）嵌入 ai/remediation-pack.json 的每条 finding 中，
不生成独立的 attack-graph.json。关联发现由 AI Agent 标记 + Renderer 自动检测（同函数、同文件、调用链）。

### Reason

- attack-graph.json 没有真实消费者：AI Agent 修复时读 remediation-pack，工程师看 executive-summary
- 关联发现的价值场景是"修这个问题时一并修关联问题"——这就在 remediation-pack 里
- 减少一个输出文件、一个渲染函数、一套 e2e 验证

### Consequences

- remediation-pack.json 每条 finding 增加 related_findings 数组
- AI Agent 可选标记 relationships 字段
- Renderer 自动补全同函数/同文件关联

---

## ADR-008: report.md 精简 + HTML 自动生成

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

report.md 从 7 节精简到 5 节，管理内容移出（归到 executive-summary.md）。
Renderer 自动生成 report.html（从相同数据源生成，不解析 report.md）。

### Reason

- 7 节 report 试图服务所有人，结果谁都不舒服
- 管理内容（评分/合规/趋势）属于 executive-summary，不应该塞进技术报告
- HTML 自动生成解决"管理层看不到报告"的问题

### Consequences

- generate_report_md() 修改：裁掉 §1 管理层摘要、§1.5 验证漏斗、§2 合规仪表盘
- render_html_report() 新增：从 findings_data 直接生成 HTML
- report.html 在 scan root，与 report.md 同级

---

## ADR-009: report.md §3 嵌套分组（按检测器）

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

report.md §3 Detailed Findings 改为按 detector 分组 + 子编号 §3.x。executive-summary 导航指向 report.md §3.x。

### Reason

- 工程师工作流是"按检测器修完一类再修下一类"——但之前 report.md §3 按严重度平铺混合了所有检测器，工程师找不到 SQLi 集中在哪几节
- findings/<ns>/<detector>/ 目录是 JSON 数据层（Renderer 和 AI Agent 消费），工程师不能直接读
- 需要一条完整的 Markdown 链：executive-summary → report.md §3.x → 集中修复

### Consequences

- generate_report_md() 修改：§3 改为嵌套结构
- executive-summary 导航更新：指向 report.md §3.x
- findings/ 目录保持 JSON 不变（canonical 数据层）


---

## ADR-010: report.md §2 按文件分组

**日期**: 2026-06-26
**状态**: ✅ Accepted

### Decision

report.md §2 Findings Inventory 改为按文件分组。§2（按文件）+ §3（按检测器）覆盖工程师双检索需求。

### Reason

单靠 §3 按检测器分组覆盖不了"这个文件有哪些问题"的场景——工程师修完一类问题后经常按文件检查遗留问题。两个维度都有真实需求。

### Consequences

- generate_report_md() §2 改为按文件分组
- 列结构改变：去掉 File 列（组标题已含），增加 Line 列
