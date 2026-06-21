# MCP Server — SecGuardian 能力消费层

> **Feature**: FEATURE-002-mcp-server
> **Epic**: EPIC-002-platform-engineering
> **状态**: 🔄 设计中（v0.3，经两轮架构评审）
> **日期**: 2026-06-15
> **作者**: JonyAn + Claude Code
> **评审**: ChatGPT (两轮架构评审)



## Architecture Vision

**SecGuardian 的核心资产不是 MCP Server。不是 CLI。不是 Report Renderer。**

核心资产只有两层：

```
Security Knowledge          →  67 个 detector、threat-catalog、5 个语言画像、4 个标准映射
    +
Code Intelligence           →  tree-sitter 解析器、符号索引、调用图、alloc/free 配对、锁分析
```

所有入口（CLI slash commands、MCP Server、IDE 插件、CI pipeline）都是这两层能力的**消费层**，不是产品本身。

这个锚点决定未来三年的架构决策：**任何消费层可以被替换，但 Knowledge + Intelligence 是唯一不可替代的资产。**

---

## 修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.1 | 2026-06-15 | 初稿 |
| v0.2 | 2026-06-15 | 第一轮评审修订：新增 `query_code_graph`/`validate_findings` Tool、`search_detectors` 支持 `code_features`、Resource 支持 `?section=`、Prompts 去除执行步骤、版本兼容体系 |
| v0.3 | 2026-06-15 | 第二轮评审修订：新增 Architecture Vision、移除 `knowledge_id`/`index_path` 双轨、`validate_findings` → `validate_report_schema` 且 `render_report` 内置自校验、版本体系精简为两项、Prompt 不引用 Tool 名、v2 优先级调整（Executable Detector → Session） |

---

## 目录

1. [问题陈述](#1-问题陈述)
2. [架构总览](#2-架构总览)
3. [Resources — 知识资源](#3-resources--知识资源)
4. [Tools — 可执行工具](#4-tools--可执行工具)
5. [Prompts — 预置提示模板](#5-prompts--预置提示模板)
6. [与现有系统关系](#6-与现有系统关系)
7. [目录结构变化](#7-目录结构变化)
8. [技术选型](#8-技术选型)
9. [用户配置方式](#9-用户配置方式)
10. [安全考量](#10-安全考量)
11. [版本兼容策略](#11-版本兼容策略)
12. [明确边界](#12-明确边界)
13. [实现规模估算](#13-实现规模估算)
14. [未来方向](#14-未来方向)
15. [待决问题](#15-待决问题)

---

## 1. 问题陈述

### 当前架构的核心矛盾

SecGuardian 的知识和能力被锁在每个 AI CLI 的插件格式里：

| 当前问题 | 影响 |
|---------|------|
| 3 个 extension 格式各维护一套（Claude Code / OpenCode / Gemini CLI） | 新增能力要改 3 处，部署脚本 800+ 行 |
| AI 必须把 67 个 detector 定义读进上下文才能分析 | 消耗大量 token，限制了扫描规模 |
| slash commands 绑定具体 CLI | VS Code / Zed / Cursor / Continue 等新兴 AI 编辑器无法使用 |
| indexer 只能在 slash command 工作流中调用 | 无法被其他工具链（CI、IDE 插件）独立消费 |

### MCP 解决什么

**MCP Server = 知识 + 智能的消费层。** 把 Security Knowledge 和 Code Intelligence 封装成标准协议接口，slash commands 变成各平台的"体验皮肤"。

| 收益 | 说明 |
|------|------|
| **一次开发，到处可用** | 任何支持 MCP 的客户端（Claude Desktop、VS Code、Zed、Cursor、Continue、GitHub Copilot）都能接入 |
| **按需加载知识** | AI 通过 Resources 只拉取相关的 2-3 个检测器，而非一次性吞入 67 个 |
| **标准化调用** | Code Intelligence 通过 Tool 调用，输入/输出结构化 JSON |
| **独立于 marketplace** | MCP 自带发现机制（`mcpServers` 配置），不依赖各 CLI 的插件注册系统 |

---

## 2. 架构总览

```
┌──────────────────────────────────────────────────────────┐
│                     AI 客户端                              │
│  Claude Desktop / VS Code / Zed / Cursor / Continue / ... │
└──────────────────┬───────────────────────────────────────┘
                   │ MCP Protocol (STDIO, JSON-RPC)
                   ▼
┌──────────────────────────────────────────────────────────┐
│                   secguardian-mcp                          │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Resources   │  │    Tools     │  │   Prompts     │  │
│  │  (6 个)      │  │   (5 个)     │  │   (3 个)      │  │
│  │              │  │              │  │               │  │
│  │ detectors/*  │  │ index_code   │  │ /scan         │  │
│  │  + ?section= │  │ query_code_  │  │ /audit        │  │
│  │ threat-      │  │   graph      │  │ /review       │  │
│  │   catalog    │  │ search_      │  │               │  │
│  │ languages/*  │  │   detectors  │  │ (仅目标+标准， │  │
│  │ standards/*  │  │ render_report│  │  不引用Tool名) │  │
│  │ protocols/*  │  │ health_check │  │               │  │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘  │
│         │                 │                   │          │
│  ┌──────┴─────────────────┴───────────────────┴───────┐  │
│  │              internal/ (复用，不改动)                │  │
│  │  parser (tree-sitter, 5语言) → indexer → context   │  │
│  └──────────────────────┬─────────────────────────────┘  │
│                         │                                 │
│  ┌──────────────────────┴─────────────────────────────┐  │
│  │         knowledge/ (Go embed 嵌入二进制)             │  │
│  │  67 detectors + threat-catalog + 5 language profiles │  │
│  │  + 4 SEI CERT/OWASP standards + 2 protocols          │  │
│  │  + detectors_index.json (构建时生成)                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          scripts/render-report.py (子进程调用)        │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### 核心设计原则

1. **纯 Go 二进制，零外部文件依赖** — knowledge/ 通过 Go 1.22+ `embed` 编译进二进制（当前 ~150KB，超过 10MB 时启用外部目录 fallback）
2. **复用不改动** — `internal/` 包零修改，MCP Server 和现有 `secguardian-index` CLI 共享同一套引擎
3. **STDIO transport only** — 第一版只支持本地 STDIO，不做 HTTP/SSE（覆盖 95% 使用场景）
4. **无状态，磁盘复用** — 每次 Tool 调用独立，通过 `index_path` 跨调用复用索引结果。Session 延至 v2
5. **Tool 自我保护** — 每个 Tool 内部完成输入校验，不依赖 AI 按特定顺序调用
6. **显式版本兼容** — 所有响应携带 `server_version` 和 `knowledge_version`

---

## 3. Resources — 知识资源（6 个）

Resources 是 AI **按需拉取**的知识，不消耗上下文窗口直到实际需要（URI 匹配时 MCP 客户端才发起请求）。

### 3.1 Resource 清单

| # | URI Pattern | MIME Type | 描述 |
|---|------------|-----------|------|
| R1 | `secguardian://detectors/list` | `application/json` | 所有检测器的结构化索引 |
| R2 | `secguardian://detectors/{name}[?section=what\|how\|fix\|verify]` | `text/markdown` | 单个检测器完整定义或指定章节 |
| R3 | `secguardian://threat-catalog` | `text/markdown` | 威胁目录总览 |
| R4 | `secguardian://languages/{lang}` | `text/markdown` | 语言安全画像 |
| R5 | `secguardian://standards/{name}` | `text/markdown` | 行业标准映射 |
| R6 | `secguardian://protocols/{name}` | `text/markdown` | 输出协议定义 |

### 3.2 Resource 详细设计

#### R1: `secguardian://detectors/list`

**为什么用 JSON 而非 Markdown：** AI 需要结构化数据来决策"该调用哪些检测器"。JSON schema 让 AI 可以按 namespace/severity/language/CWE 过滤。

**返回结构:**

```json
{
  "server_version": "0.7.0",
  "knowledge_version": "1.2",
  "total": 67,
  "detectors": [
    {
      "name": "buffer-overflow",
      "namespace": "memory",
      "severity": "critical",
      "precision": "high",
      "confidence": "high",
      "languages": ["c", "cpp"],
      "cwe": ["CWE-120"],
      "triggers": {
        "keywords": ["malloc", "strcpy", "memcpy", "gets", "sprintf"],
        "apis": ["alloc", "free"],
        "patterns": ["fixed-size buffer write"]
      },
      "summary": "检测固定大小缓冲区的越界写入",
      "estimated_tokens": 850
    }
  ]
}
```

**`triggers` 字段设计（v0.3 新增 — 第二轮评审 Issue 3）：**

每个 detector 的 frontmatter 中定义 `triggers` 块，作为检测器匹配契约（Detector Matching Contract）。当 AI 通过 `search_detectors` 传入 `code_features` 时，Server 将特征符号与 `triggers.keywords`/`triggers.apis` 做匹配，而非依赖通用关键词搜索。

```yaml
# detector frontmatter 示例
triggers:
  keywords: [malloc, strcpy, memcpy, gets, sprintf]
  apis: [alloc, free]
  patterns: ["fixed-size buffer write"]
  frameworks: []       # 未来扩展：["spring-security", "django-auth"]
  protocols: []        # 未来扩展：["OAuth2", "JWT"]
```

这个契约结构确保 `triggers` 字段不会无限膨胀——每次新增维度都需要在契约 schema 中显式定义。

**实现方式：** 在构建时 (`go generate` 或 `build.sh`) 扫描 `knowledge/guard-rules/*.md`，解析每个文件 frontmatter 中的元数据和 triggers，生成 `detectors_index.json`，`embed` 进二进制。

#### R2: `secguardian://detectors/{name}[?section=how]`

返回检测器的 Markdown 内容。支持可选的 `?section=` 查询参数实现细粒度加载：

| 调用方式 | 返回内容 | 典型 token |
|---------|---------|-----------|
| `detectors/buffer-overflow` | 完整四段式 | ~800-1200 |
| `detectors/buffer-overflow?section=how` | 仅 HOW 章节 | ~200-400 |
| `detectors/buffer-overflow?section=what` | 仅 WHAT 章节 | ~100-200 |
| `detectors/buffer-overflow?section=fix` | 仅 FIX 章节 | ~150-300 |
| `detectors/buffer-overflow?section=verify` | 仅 VERIFY 章节 | ~100-200 |

每个 Resource 响应携带 `knowledge_version` 元数据。

#### R3-R6: 知识资源

直接从对应的 `knowledge/` 目录 embed，不做格式转换。保持 Markdown 原文。

---

## 4. Tools — 可执行工具（5 个）

### 设计理念

v0.1 的 Tool 设计偏向"CLI 功能包装器"。v0.2 调整为两个层次（底层能力 + 查询能力）。v0.3 进一步精简——合并功能重叠的 Tool，每个 Tool 自我保护而非依赖 AI 按序调用。

### 4.1 `index_code` — 代码索引

**定位：** `secguardian-index` CLI 的 MCP 封装。

```
Input Schema:
  path      string (required)  — 源代码目录
  language  string (optional)  — auto/c/cpp/python/java/go/javascript
  output    string (optional)  — 索引输出文件路径（默认 .codeagent/index.json）

Output Schema:
  {
    index_path:   string,     // 索引文件路径，供后续 query_code_graph 引用
    files_count:  int,
    symbols:      { functions: int, variables: int, types: int },
    call_graph:   { edges: int },
    alloc_free:   { pairs: int },
    lock_graph:   { mutexes: int }
  }
```

**v0.3 修订（第二轮评审 Issue 1）：** 移除了 `knowledge_id`。v0.2 同时存在 `knowledge_id` 和 `index_path` 双轨，实际只有 `index_path` 被 `query_code_graph` 消费。v0.3 只保留 `index_path`。`knowledge_id` 概念延至 v2 的 Session 体系。

### 4.2 `query_code_graph` — 代码知识查询

**定位：** AI 不关心"请帮我建索引"，关心的是"给我代码知识"。

```
Input Schema:
  index_path  string  (required)  — index_code 输出的索引文件路径
  query_type  string  (required)  — callers | callees | alloc_free | symbols | dataflow
  symbol      string  (optional)  — 查询目标符号（函数名/变量名）
  file        string  (optional)  — 限定文件范围
  limit       int     (optional)  — 结果数量上限（默认 50）

Output Schema:
  {
    query_type:  string,
    symbol:      string,
    matches: [
      {
        symbol:       string,
        file:         string,
        line:         int,
        relationship: string   // "calls" | "called_by" | "allocates" | "frees" | "references"
      }
    ],
    total:       int
  }
```

**典型使用场景：**

| AI 想知道 | 调用方式 |
|----------|---------|
| 谁调用了 `strcpy`？ | `query_code_graph(query_type="callers", symbol="strcpy")` |
| `malloc` 对应的 `free` 在哪里？ | `query_code_graph(query_type="alloc_free", symbol="malloc")` |
| 用户输入最终到达哪些数据库操作？ | `query_code_graph(query_type="dataflow", symbol="user_input")` |
| `auth.c` 里有哪些函数？ | `query_code_graph(query_type="symbols", file="auth.c")` |

**v0.3 备注（第二轮评审 Issue 2）：** 当前 `query_type` 枚举（callers/callees/alloc_free/symbols/dataflow）是索引结构驱动的。评审建议增加分析任务驱动层（如 `security_code_insight(insight="user_input_flow")`），这将作为 v2.3 的增强方向。

### 4.3 `search_detectors` — 检测器推荐

**定位：** AI 用这个回答"这段代码应该跑哪些检测器"。

```
Input Schema:
  query         string   (optional)  — 关键词搜索（如 "buffer overflow"）
  language      string   (optional)  — 过滤语言
  cwe           string   (optional)  — 过滤 CWE 编号（如 "CWE-120"）
  namespace     string   (optional)  — 过滤命名空间
  code_features string[] (optional)  — 代码符号特征（如 ["malloc","strcpy","socket"]）
  index_path    string   (optional)  — 索引文件路径，Server 端自动提取特征并匹配

Output Schema:
  {
    matches: [
      {
        name:       string,
        namespace:  string,
        severity:   string,
        languages:  string[],
        cwe:        string[],
        summary:    string,
        score:      float
      }
    ]
  }
```

**匹配逻辑：** 对 `detectors_index.json` 做内存搜索。`code_features` 与每个 detector 的 `triggers.keywords` 和 `triggers.apis` 做交集匹配来计算相关性评分。匹配契约见 §3.2 R1 中的 `triggers` 字段定义。

### 4.4 `render_report` — 报告渲染（v0.3 重构）

**定位：** 内置 schema 校验 + 报告渲染。Tool 自我保护——不依赖 AI 先调用校验。

```
Input Schema:
  findings_dir   string  (required)  — findings.json 所在目录
  output_dir     string  (required)  — 输出目录
  ci_mode        bool    (optional)  — 启用 CI 门禁模式
  validate_only  bool    (optional)  — 仅校验 schema，不生成报告文件

Output Schema:
  {
    valid:             bool,
    schema_errors: [
      {
        finding_index:  int,
        field:          string,
        issue:          string
      }
    ],
    schema_warnings: [
      {
        finding_index:  int,
        issue:          string
      }
    ],
    files_generated:   [string],            // validate_only 时为空
    summary:           { total, critical, high, medium, low },
    exit_code:         int
  }
```

**内部执行流程（不暴露给 AI）：**

```
1. 读取 findings.json
2. 执行 schema 校验：
   - Error: 缺少必填字段（what/how/fix）、severity 非法值、CWE 格式错误
   - Warning: fix 章节过短（<50 字符）、未提供 verify 测试用例
3. 如果 !valid 且非 ci_mode → 返回错误，不渲染
4. 如果 ci_mode → 渲染所有 finding（含不合规的），标记 exit_code
5. 调用 render-report.py 生成 report.md + results.sarif + summary.json
```

**v0.3 设计变更（第二轮评审 Issue 4+5）：**
- v0.2 有独立的 `validate_findings` Tool，要求 AI 先调校验再调渲染。这有两个问题：(1) AI 可能忘记调用导致渲染出错；(2) `validate_findings` 名称暗示"验证漏洞真实性"，实际只能验证 schema。
- v0.3 将 schema 校验内聚到 `render_report` 内部，Tool 自我保护。新增 `validate_only` 参数支持仅校验不渲染的场景。校验结果重命名为 `schema_errors` / `schema_warnings`，明确这是结构校验而非安全验证。

### 4.5 `health_check` — 健康检查

```
Input Schema:
  （无参数）

Output Schema:
  {
    status:              "ok" | "degraded",
    server_version:      string,
    knowledge_version:   string,
    detectors_count:     int,
    languages:           string[],
    parser_available:    bool,
    renderer_available:  bool
  }
```

**v0.3 修订（第二轮评审 Issue 6）：** 版本信息从四项精简为两项。`detector_version` 本质是 knowledge schema 的一部分，`protocol_version` 可通过 findings schema 自身表达。当前系统规模较小，四套版本升级矩阵维护成本高于收益。

---

## 5. Prompts — 预置提示模板（3 个）

### 设计原则（v0.3 修订）

Prompt **只定义目标和质量标准，不引用具体 Tool 名称，不定义执行步骤。** 让模型通过 MCP 协议的 `tools/list` 自主发现可用能力并规划执行路径。这是 MCP 最佳实践——不同模型有不同的 Tool Planning 策略，Prompt 不应干预。

| # | Prompt 名 | 参数 | 用途 |
|---|----------|------|------|
| P1 | `/scan` | `path`, `language` | 安全漏洞扫描 |
| P2 | `/audit` | `skill_name`, `path` | 深度安全审计 |
| P3 | `/review` | `path`, `language` | 安全编码规范审查 |

### Prompt 模板示例（P1 `/scan`，v0.3 修订）

```markdown
## System Message

You are performing a security code scan using SecGuardian. Discover available
capabilities through the MCP tools and resources provided to you.

## Objectives
- Discover security vulnerabilities in {path}
- Target language: {language}
- Classify each finding with severity (critical/high/medium/low)

## Output Requirements
- Every finding MUST use the 4-section format:
  - WHAT: threat description and impact
  - HOW: exploitation vector with specific file:line code evidence
  - FIX: concrete, compilable/runnable remediation code
  - VERIFY: test case to confirm the fix works
- After generating findings, validate and render them into the standard
  report format (report.md + SARIF + summary)

## Quality Standards
- Each HOW section must cite specific file:line evidence — never use placeholder paths
- Each FIX section must include complete, correct code — never write pseudocode
- False positive rate target: <10%
- If unsure whether a pattern is exploitable, mark as "low" severity with explanation
```

### 设计考量

- Prompt **不列出 Tool 名称**：模型通过 MCP 协议自动发现可用能力，自主规划路径
- Prompt **不定义步骤顺序**：不同模型（Claude/GPT/Gemini）的 Tool Planning 策略不同，硬编码步骤限制自主性
- Prompt 内容复用现有 `commands/*.md` 的目标和质量标准部分
- 如果客户端不支持 MCP Prompts，用户可手动描述需求，AI 仍能通过 Resources + Tools 完成工作

---

## 6. 与现有系统关系

### 分层关系

```
        ┌──────────────────────────────────┐
        │       slash commands              │  ← 用户体验层
        │  /secguard /secaudit /secreview   │     CLI 插件格式
        │  (commands/*.md)                  │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │        MCP Server                 │  ← 统一消费层
        │  Resources + Tools + Prompts      │     MCP 标准协议
        │  (secguardian-mcp)                │
        └──────────────┬───────────────────┘
                       │
        ┌──────────────┴───────────────────┐
        │  Security Knowledge               │  ← 核心资产（不可替代）
        │  67 detectors + threat-catalog    │
        │  + 5 language profiles            │
        │  + 4 standards + 2 protocols      │
        ├───────────────────────────────────┤
        │  Code Intelligence                 │
        │  parser / indexer / context       │
        │  tree-sitter, 5 语言               │
        └──────────────────────────────────┘
```

### 互补而非替代

| 场景 | 推荐方式 | 原因 |
|------|---------|------|
| Claude Code 用户日常使用 | `/secguard` slash command | 方便，一键触发 |
| VS Code / Zed 用户 | 配置 MCP，使用 `/scan` prompt | 这些编辑器不支持 CLI 插件 |
| CI/CD Pipeline | `secguardian-index` + `render-report.py` 直接调用 | 不需要 AI，不需要 MCP |
| 自定义 AI Agent 开发 | MCP Tools | 标准化协议，多语言 SDK 可用 |
| 跨平台统一体验 | MCP Server + slash commands 共存 | 各取所需 |

### 现有代码不改动

- `commands/*.md` — 零修改
- `skills/` — 零修改
- `knowledge/` — 零修改（仅新增 `detectors_index.json` 生成步骤。detector frontmatter 新增 `triggers` 字段）
- `internal/` — 仅一处重构：`runIndex()` 提取为公共函数
- `scripts/deploy.sh` — 新增可选的 MCP 二进制部署

---

## 7. 目录结构变化

```
secguardian/
├── cmd/                                   # 新增：多二进制入口
│   ├── secguardian-index/                 # 从 internal/main.go 移出
│   │   └── main.go                        #    (~50 行改动，提取公共函数)
│   └── secguardian-mcp/                   # 新增：MCP Server
│       ├── main.go                        #   入口 (~50 行)
│       ├── server.go                      #   MCP 协议 STDIO server (~100 行)
│       ├── resources.go                   #   6 个 Resource handlers (~250 行)
│       ├── tools.go                       #   5 个 Tool handlers (~400 行)
│       ├── prompts.go                     #   3 个 Prompt templates (~60 行)
│       └── embed.go                       #   go:embed 声明 (~10 行)
├── internal/                              # 不变（含一处重构）
│   ├── parser/                            #   零改动
│   ├── indexer/                           #   新增 runner.go + query.go
│   │   ├── indexer.go                     #   零改动
│   │   ├── diff_parser.go                 #   零改动
│   │   ├── runner.go                      #   新增：RunIndex() 公共函数 (~80 行)
│   │   └── query.go                       #   新增：QueryIndex() 结构化查询 (~150 行)
│   └── context/                           #   零改动
├── knowledge/                             # 不变（构建时新增 index 生成）
│   └── detectors_index.json               # 新增：构建时生成，embed 进 MCP
├── scripts/
│   ├── package.sh                         # 新增：编译 secguardian-mcp + 生成 detectors_index.json
│   ├── deploy.sh                          # 新增：可选 MCP 二进制部署
│   └── ...
├── docs/
│   └── designs/
│       └── 2026-06-15-mcp-server-design.md # 本文件
└── ...
```

---

## 8. 技术选型

### MCP Go SDK

| 候选 | 判定 |
|------|------|
| `github.com/mark3labs/mcp-go` | ✅ **选用** — Star 10k+，Apache 2.0，Resources + Tools + Prompts + STDIO transport 开箱即用 |
| `github.com/metoro-io/mcp-golang` | ❌ 社区规模较小 |
| 手写 JSON-RPC | ❌ 没必要重复造轮子 |

### 现有依赖不变

```
现有 go.mod:
  github.com/tree-sitter/go-tree-sitter      # parser 引擎
  github.com/tree-sitter/tree-sitter-c/cpp/  # 5 语言 tree-sitter 语法
      /go/java/python

新增依赖:
  github.com/mark3labs/mcp-go                # MCP 协议
```

`internal/` 不引入 MCP 依赖，确保 `secguardian-index` 编译不受影响。

---

## 9. 用户配置方式

### 9.1 Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json`（macOS）：

```json
{
  "mcpServers": {
    "secguardian": {
      "command": "secguardian-mcp",
      "args": []
    }
  }
}
```

### 9.2 VS Code

通过 MCP 扩展的 `mcp_servers` 配置：

```json
{
  "servers": {
    "secguardian": {
      "type": "stdio",
      "command": "secguardian-mcp"
    }
  }
}
```

### 9.3 安装方式

| 方式 | 命令 |
|------|------|
| Go install | `go install github.com/secguardian/secguardian/cmd/secguardian-mcp@v0.7.0` |
| 预编译二进制 | 下载 GitHub Release 中的 `secguardian-mcp-{os}-{arch}`，放 `PATH` |
| Homebrew (未来) | `brew install secguardian/tap/secguardian-mcp` |

---

## 10. 安全考量

| 风险 | 缓解措施 |
|------|---------|
| MCP Server 可执行任意路径的 indexer | `path` 参数限制在用户工作目录内，不跟随符号链接到外部 |
| `render_report` 通过 `os/exec` 调用 Python | Python 脚本路径来自 embed 或系统 `PATH`，不接受用户输入 |
| `detectors_index.json` 被篡改 | 编译时嵌入，运行时不可修改 |
| STDIO transport 无认证 | 本地 IPC 仅接受本机连接，不暴露网络端口 |

---

## 11. 版本兼容策略

### 版本体系（v0.3 精简）

| 版本标识 | 含义 | 示例 | 变更频率 |
|---------|------|------|---------|
| `server_version` | MCP Server 自身版本，跟随 SecGuardian 主版本 | `"0.7.0"` | 每次 release |
| `knowledge_version` | knowledge/ 数据 + detector schema 版本 | `"1.2"` | detector 新增/删除/重命名或 frontmatter schema 变更 |

**v0.3 精简理由（第二轮评审 Issue 6）：** v0.2 有四套版本（server / knowledge / detector / protocol），但 detector schema 本质是 knowledge 的子集，protocol 版本可通过 findings schema 自身表达。当前系统规模下，维护四套版本的升级矩阵成本高于收益。

### 兼容性契约

```
MCP Server 版本号 = SecGuardian 主版本号。
例如：SecGuardian v0.7.0 → MCP Server v0.7.0。

向前兼容：MCP Server v0.7.0 可加载 v0.6.x 的 knowledge/ 数据。
向后兼容：v0.7.0 的 knowledge 数据不应被 v0.6.x 的 Server 加载。

不兼容升级时（如 knowledge schema 大版本变更）：
  - Server 启动时检测 knowledge_version 不匹配 → 输出警告到 stderr
  - health_check 返回 status: "degraded" + incompatibility_detail
  - Tools 仍可调用，但涉及 detector 的 Tool 返回 warnings[]
```

### 版本信息暴露位置

- `health_check` Tool：返回 `server_version` 和 `knowledge_version`
- 每个 Resource 响应：携带 `knowledge_version`
- Server 启动 `initialize` 握手：在 `serverInfo` 中声明版本

---

## 12. 明确边界

| 不做 | 原因 |
|------|------|
| **SSE / HTTP transport** | 第一版只做 STDIO。远程调用需求出现时再加 |
| **Session / 状态管理** | v2.2。v1 通过磁盘 index_path 实现跨调用复用 |
| **机器可执行 detector** | v2.1（最高优先级）。v1 的 detector 是 AI 可读的自然语言规则 |
| **修改现有 slash commands** | MCP 是新能力，现有工作流一条不改 |
| **CI/CD 用 MCP Tool** | CI pipeline 继续直接用 CLI |
| **多语言 SDK 封装** | 客户端使用 MCP 标准协议接入 |
| **Web UI / Dashboard** | 超出 MCP Server 范围 |
| **Python MCP 实现** | Go 已有成熟的 MCP SDK 且与 internal/ 同语言 |
| **knowledge >10MB 仍全部 embed** | 当前 ~150KB。超阈值时启用外部目录 fallback |

---

## 13. 实现规模估算

| 组件 | 代码量（估） | 复杂度 | 说明 |
|------|------------|--------|------|
| `cmd/secguardian-mcp/main.go` | ~50 行 | 低 | 入口 + flag 解析 |
| `server.go` | ~100 行 | 低 | mcp-go 已封装 STDIO server |
| `resources.go` | ~250 行 | 低 | embed 文件读取 + URI 路由 + `?section=` 解析 |
| `tools.go` | ~400 行 | 中 | 5 个 Tool handlers（render_report 含内联 schema 校验） |
| `prompts.go` | ~60 行 | 低 | 目标导向模板（不引用 Tool 名） |
| `internal/indexer/runner.go` | ~80 行 | 低 | 提取 RunIndex 为公共函数 |
| `internal/indexer/query.go` | ~150 行 | 中 | 结构化查询（callers/callees/alloc_free/symbols） |
| `cmd/secguardian-index/main.go` 重构 | ~50 行 | 低 | 调用 runner 替代内联逻辑 |
| `detectors_index.json` 生成脚本 | ~120 行 | 低 | 解析 frontmatter + triggers 字段 |
| `scripts/package.sh` 改动 | ~30 行 | 低 | 新增 MCP 编译 + index 生成步骤 |
| **总计** | **~1,290 行** | | **预估 2-3 人天** |

### 实施顺序

1. **Phase 1 (半天):** 重构 `internal/main.go` → `cmd/secguardian-index/` + `runner.go`。验证：`self-check.sh` 全绿
2. **Phase 2 (半天):** 实现 `internal/indexer/query.go` 结构化查询能力
3. **Phase 3 (1 天):** 实现 MCP Server（server.go → resources.go → tools.go → prompts.go → main.go）
4. **Phase 4 (半天):** 生成脚本 + detectors_index.json（含 triggers）+ 构建集成 + 端到端测试

---

## 14. 未来方向

### 14.1 机器可执行 Detector（v2.1，最高优先级）

**为什么优先级最高：** 这是决定 SecGuardian 是不是一个产品的战略问题。当前所有检测逻辑由 AI 阅读 Markdown 后执行——Claude 扫描结果 A，GPT 扫描结果 B，Gemini 扫描结果 C。用户会认为"SecGuardian 没有检测能力，只是个知识库"。

**方向：** 将 detector 的形式化规则提取为可执行模式（正则/Semgrep 规则/tree-sitter query），MCP Server 可脱离 AI 独立检测。

```
Tool: analyze_with_detector(detector="buffer-overflow", target="src/auth.c")
→ 返回: { findings: [...] }
```

**触发条件：** "不同模型扫描结果不一致"成为核心痛点时启动。

### 14.2 Session / Knowledge Handle（v2.2）

**方向：** 引入 Session，Server 维护内存中的索引缓存，避免重复读取磁盘。触发条件：用户反馈"每次都重新 index"。

### 14.3 分析任务驱动查询（v2.3）

**方向：** 在 `query_code_graph` 之上新增分析任务驱动层（第二轮评审 Issue 2）。

```
Tool: security_code_insight(insight="user_input_flow", index_path="...")
→ 返回: { sources: [...], sinks: [...] }
```

### 14.4 Remote MCP（v2.4）

**方向：** 支持 SSE/HTTP transport，允许远程 CI 或团队共享 MCP Server。

### 14.5 Knowledge Embed 阈值（v2.5）

**方向：** 当 knowledge/ 超过 10MB 时，启用外部目录 fallback。

---

## 15. 待决问题

| # | 问题 | 影响 | 建议 |
|---|------|------|------|
| Q1 | **MCP Server 是否作为独立 GitHub Release asset 还是打进统一大包？** | 发布流程设计 | 倾向统一大包 |
| Q2 | **`detectors_index.json` frontmatter 解析的容错性？** | 构建可靠性 | 构建时解析失败应 fail fast |
| Q3 | **Prompt 模板语言？** | 国际化 | v1 中英双语，跟随现有 commands 语言 |
| Q4 | **`render_report` 依赖 Python 3 的降级策略？** | 用户体验 | `health_check` 暴露 `renderer_available`，为 false 时 AI 自行输出 Markdown |
| Q5 | **`triggers` 字段的维护策略？** | 检测器匹配准确性 | 与 detector 定义共同维护，纳入 detector review checklist |

---

## 附录 A: MCP 协议交互时序（v0.3 修订）

```
User: "Scan ./src for security issues in Python"

AI → MCP:   Call Tool: index_code(path="./src", language="python")
MCP → AI:   { index_path: ".codeagent/index.json", files_count: 42, ... }

AI → MCP:   Call Tool: query_code_graph(query_type="symbols", index_path=".codeagent/index.json")
MCP → AI:   { matches: [{ symbol: "execute_query", file: "db.py", ... }, ...] }

AI → MCP:   Call Tool: search_detectors(language="python",
                code_features=["execute_query", "render_template", "os.system"])
MCP → AI:   { matches: [{ name: "sql-injection", score: 0.95 }, ...] }

AI → MCP:   Read Resource: secguardian://detectors/sql-injection?section=how
MCP → AI:   ## HOW\n\n1. 定位所有构造 SQL 字符串的位置...

AI:         [分析代码，比对检测器逻辑，生成 findings.json]

AI → MCP:   Call Tool: render_report(findings_dir="...", output_dir="./scan-output/")
            → Server 内部先执行 schema 校验，通过后渲染报告
MCP → AI:   { valid: true, schema_errors: [], files_generated: ["report.md", ...], summary: {...} }

AI → User:  扫描完成。发现 3 个漏洞：2 high, 1 medium。报告已生成到 ./scan-output/
```

---

## 附录 B: 业界参考

| 项目 | 参考点 |
|------|-------|
| `modelcontextprotocol/servers` 官方示例 | STDIO server 模式、Resource/Tool 组织方式 |
| `zed-industries/zed` MCP 集成 | 编辑器侧 MCP 消费方式 |
| `continuedev/continue` MCP 支持 | IDE 插件侧 MCP 接入模式 |
| `semgrep/semgrep` | 可执行规则的表达方式（v2.1 detector 形式化参考） |
