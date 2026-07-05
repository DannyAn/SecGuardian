---
name: secguard-go
description: 对 Go 代码进行安全加固项排查，检测标准库陷阱和并发安全问题。当用户请求Go安全扫描、Go代码审计、goroutine安全、Go标准库陷阱、Go加密安全时使用。
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---

# Go 安全加固排查

对 Go 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 🎯 Detector Selection (Skill Layer)

> **📊 信号预筛 (engine_contract.md Rule C):** 基于 index.json 信号触发检测器：`symbols.functions` 含 `exec`/`system`→command-injection；含 `db.Query`/`fmt.Sprintf`→sql-injection；含 `md5`/`des`→weak-crypto；含 `http.Get`→ssrf；无加密库符号→跳过 crypto 检测器。无信号匹配时 MUST 标记 `confidence: low`。

## ⚙️ Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。
>
> **🔗 锚定+证据约束 (Rule A + Rule B):** 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表。每个 finding MUST 包含 `--snippet`、`--code-context`、`--rationale`、`--attack-scenario`。调用 `record-finding.py` 时必须传 `--index-json` 进行锚定校验。无 index 锚点时 MUST 标记 `confidence: low`。
>
> **🔒 读取范围 = index.json.symbols.functions (NON-NEGOTIABLE):** `symbols.functions` 已是完整的函数→文件:行号 映射。LLM 只读取符号表中列出的位置（`start_line`±10行）。不在符号表中的文件 → 不读。不在符号表中的函数 → 不分析。符号表中无关联函数名的检测器 → 跳过，报告 "Skipped: no matching symbol"。

## 执行流程

> **前置条件**: Command 层面已完成 `secguardian-index` 索引器调用，`index.json` 已生成在扫描输出目录下。包含 `symbols.functions`（函数→文件:行号）、`call_graph.edges`（调用关系）、`files`（文件清单）。
>
> **禁止事项**：❌ 不要启动 clangd 或任何 LSP server（indexer 已提供所有代码结构数据）。❌ 不要用 find/ls/glob 重新遍历文件系统。❌ 不要逐文件全文读取——始终从 indexer 数据出发精准定位。

1. 读取 Command 生成的 `index.json`，获取文件清单、符号表和调用图。**从 symbols.functions 构建函数名→{文件:行号} 查找表，检测器按需查表定位目标函数后精准读取，不扫描无关文件。**
2. 加载 `knowledge/languages/go.md` 获取 Go 危险 API 清单和并发陷阱
3. 加载 `knowledge/language-index.md`（57行）获取该语言检测器清单。仅对 index.json 符号表中匹配到的检测器，按需加载 `knowledge/guard-rules/<name>.md` 详情
4. 基于 index.json 的符号表定位检测目标，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | 命令注入 | exec.Command("sh", "-c", userInput) |
| Critical | SQL 注入 | db.Query/Exec + fmt.Sprintf / GORM Raw() |
| Critical | SSTI | template.Parse(userTpl) / text/template 生成 HTML |
| Critical | cgo 内存 | C 被调用方的缓冲区溢出 / Double Free |
| High | 路径穿越 | os.Open + filepath.Join 未 Clean / Zip Slip |
| High | SSRF | http.Get(userURL) / ReverseProxy 未限制 |
| High | 弱加密 | crypto/md5 安全用途 / math/rand 安全用途 |
| High | 硬编码密钥 | API Key / Password / JWT Secret 硬编码 |
| Medium | 并发安全 | map 并发读写 / goroutine 泄露 / Mutex 复制 |
| Medium | 信息泄露 | panic 信息返回客户端 / debug/pprof 暴露 |

### 框架覆盖

## 执行指令（I/O 优化版）

> 以下执行方式遵循 `engine_contract.md` 和 `output_contract.md` 的性能要求。

### 源文件读取（index.json.symbols.functions 驱动）

> **🔒 读取范围 = index.json.symbols.functions:** `symbols.functions` 已是函数→文件:行号 映射。LLM 只读取符号表中的位置（±10行）。不在符号表中的文件 → 不读。不在符号表中的函数 → 不分析。

### 检测器加载（批量 + 按需）

1. 加载 `knowledge/language-index.md`（57 行，包含所有检测器清单）
2. 先做符号匹配快速过滤，仅加载匹配到的 detector 详情

### Finding 输出（批量）

1. 将所有 findings 收集到临时结构
2. 用 `python3 render-report.py --findings <dir>/findings.json --output <dir>` 批量输出

## 输出完整性要求
- net/http (标准库)
- Gin, Echo, Fiber
- GORM, sqlx
- html/template, text/template
- cgo (C 互操作安全)

## 📄 Output Protocol

> 以下输出格式遵循 `internal/output/output_contract.md`。

## 输出完整性要求

> **每个检出必须满足四段式完整性**（Command 层 Step 4b 质量门禁强制检查）：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 代码行内容
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（引用 detector 的检测逻辑）+ 数据流路径
> 3. **⚠️ Impact** — 攻击场景描述 + CVSS 3.1 评分 + 利用条件
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + CWE 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注 Source → Sink 路径，`fixes` 包含 before/after 替换。
