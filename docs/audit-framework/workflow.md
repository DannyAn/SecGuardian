# Workflow — 审计工作流

> SecAudit 从用户输入到发布决策的完整执行流程。

## 工作流总览

```
User
  │
  ▼
/secaudit 命令入口
  │
  ▼ 1. Pre-flight
环境检查（索引器、路径、健康状态）
  │
  ▼ 2. Index
构建语义索引（index.json）
  │
  ▼ 3. Load Knowledge
加载 knowledge/audit-rules/*.md（13 个审计域）
  │
  ▼ 4. Collect Context
分析项目技术栈、架构、数据流
  │
  ▼ 5. Collect Evidence
按审计域逐项检查代码
  │
  ▼ 6. AI Reasoning
安全分析 → 判断发现
  │
  ▼ 7. Generate Findings
输出结构化结果
  │
  ▼ 8. Generate Report
report.md + results.sarif + summary.json
  │
  ▼ 9. Release Decision
CI 门禁：PASSED / FAILED
```

## 各阶段详述

### 阶段 1: Pre-flight（前置检查）

在开始审计前确认：

- Indexer wrapper 可定位（项目级 `.opencode/` → 用户级 `~/.config/opencode/` → 回退 `scripts/`）
- `--health` 输出 `HEALTH:OK` 或 `HEALTH:WARN`
- 目标路径存在且包含源码文件

### 阶段 2: Index（构建索引）

执行 `secguardian-index` 产出 `index.json`：

- 符号表（函数/变量/类型）
- 调用图（caller/callee 文本近似）
- Alloc/Free 配对记录
- 锁使用记录

索引是后续所有证据收集的基础。

### 阶段 3: Load Knowledge（加载知识）

从 `knowledge/audit-rules/` 加载检测规则：

- 每个审计域对应一个 `.md` 文件（共 13 个域，如 `cryptography.md`、`auth-and-session.md`）
- 知识文件定义：what to check、how to judge、risk level

知识来源仅限 `knowledge/`，不涉及 `docs/audit-framework/`。

### 阶段 4: Collect Context（收集上下文）

分析项目特征：

- 语言与技术栈识别
- 框架与库依赖
- 数据存储与通信方式
- 部署架构

### 阶段 5: Collect Evidence（收集证据）

按审计域逐项检查：

| 活动 | 输入 | 输出 |
|------|------|------|
| 语义分析 | index.json + 源码 | 符号/调用/数据流证据 |
| 模式匹配 | knowledge rules | 风险模式识别 |
| 数据流追踪 | index.json call graph | Source → Sink 路径 |

### 阶段 6: AI Reasoning（推理判断）

对收集的证据进行安全分析：

1. 证据是否充分 → 是否构成合规发现
2. 严重度评估（CVSS 打分）
3. False Positive 判断
4. 修复建议生成

### 阶段 7: Generate Findings（输出发现）

每个 finding 包含完整四段式：

- Location: 文件/行号/函数
- Evidence: 代码上下文/判断依据/数据流路径
- Impact: 攻击场景/风险评分
- Fix: 修复方案/before/after 代码

### 阶段 8: Generate Report（生成报告）

调用渲染器生成多格式输出：

- `report.md` — 人读审计报告（Markdown）
- `results.sarif` — SARIF 2.1.0（CI/CD）
- `summary.json` — 轻量统计
- `manifest.json` — 元数据索引
- `status.json` — CI 门禁状态
- `delta.json` — 增量对比

### 阶段 9: Release Decision（发布决策）

门禁规则：

| 条件 | 结论 |
|------|------|
| 存在 Critical 发现 | FAILED（exit 1） |
| 无发现 | PASSED（exit 0） |
| 仅 High/Medium | 不阻塞，但报告标注建议 |

## 工作流与知识的分离

```
工作流（Workflow）回答：如何检查？
  规则（Rule）回答：检查什么？
  AI 推理回答：为什么存在问题？
  报告（Report）回答：最终结论是什么？
```

工作流不保存规则。规则不定义流程。
