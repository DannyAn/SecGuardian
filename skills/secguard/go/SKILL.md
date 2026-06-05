---
name: go
description: 对 Go 代码进行安全加固项排查，检测标准库陷阱和并发安全问题。当用户请求Go安全扫描、Go代码审计、goroutine安全、Go标准库陷阱、Go加密安全时使用。
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---


# Go 安全加固排查

对 Go 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 执行流程

> **前置条件**: Command 层面已完成 `secguardian-index` 索引器调用，`index.json` 已生成在扫描输出目录下。包含 `symbols.functions`（函数→文件:行号）、`call_graph.edges`（调用关系）、`files`（文件清单）。
>
> **禁止事项**：❌ 不要启动 clangd 或任何 LSP server（indexer 已提供所有代码结构数据）。❌ 不要用 find/ls/glob 重新遍历文件系统。❌ 不要逐文件全文读取——始终从 indexer 数据出发精准定位。

1. 读取 Command 生成的 `index.json`，获取文件清单、符号表和调用图。**从 symbols.functions 构建函数名→{文件:行号} 查找表，检测器按需查表定位目标函数后精准读取，不扫描无关文件。**
2. 加载 `knowledge/languages/go.md` 获取 Go 危险 API 清单和并发陷阱
3. 加载 `knowledge/threat-catalog.md` 获取威胁全景，再按需加载 `knowledge/detectors/<name>.md`（每个 detector 自包含威胁定义+检测逻辑+修复指引）
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
- net/http (标准库)
- Gin, Echo, Fiber
- GORM, sqlx
- html/template, text/template
- cgo (C 互操作安全)

## 输出完整性要求

> **每个检出必须满足四段式完整性**（Command 层 Step 4b 质量门禁强制检查）：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 代码行内容
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（引用 detector 的检测逻辑）+ 数据流路径
> 3. **⚠️ Impact** — 攻击场景描述 + CVSS 3.1 评分 + 利用条件
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + CWE 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注 Source → Sink 路径，`fixes` 包含 before/after 替换。
