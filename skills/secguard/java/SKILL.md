---
name: secguard-java
description: 对 Java 代码进行安全加固项排查，扫描危险 API 调用和常见漏洞模式。当用户请求Java安全扫描、Java代码审计、反序列化漏洞、Spring安全、Java加密安全时使用。
category: language-specific
language: java
topic: [web, crypto, system]
---

# Java 安全加固排查

对 Java 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 🎯 Detector Selection (Skill Layer)
## ⚙️ Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。

## 执行流程

> **前置条件**: Command 层面已完成 `secguardian-index` 索引器调用，`index.json` 已生成在扫描输出目录下。包含 `symbols.functions`（函数→文件:行号）、`call_graph.edges`（调用关系）、`files`（文件清单）。
>
> **禁止事项**：❌ 不要启动 clangd 或任何 LSP server（indexer 已提供所有代码结构数据）。❌ 不要用 find/ls/glob 重新遍历文件系统。❌ 不要逐文件全文读取——始终从 indexer 数据出发精准定位。

1. 读取 Command 生成的 `index.json`，获取文件清单、符号表和调用图。**从 symbols.functions 构建函数名→{文件:行号} 查找表，检测器按需查表定位目标函数后精准读取，不扫描无关文件。**
2. 加载 `knowledge/languages/java.md` 获取 Java 危险 API 清单
3. 加载 `knowledge/threat-catalog.md` 获取威胁全景，再按需加载 `knowledge/guard-rules/<name>.md`（每个 detector 自包含威胁定义+检测逻辑+修复指引）
4. 基于 index.json 的符号表定位检测目标，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | 反序列化漏洞 | ObjectInputStream / FastJson @type / Jackson enableDefaultTyping |
| Critical | SQL 注入 | Statement.execute / MyBatis ${} / JPA nativeQuery 拼接 |
| Critical | 命令注入 | Runtime.exec 单字符串 / ProcessBuilder + shell |
| Critical | SSTI/代码注入 | ScriptEngine.eval / 模板引擎未过滤输入 |
| High | XXE | XML Parser 未禁用外部实体 |
| High | 路径穿越 | 文件路径未 canonicalize |
| High | SSRF | HTTP 请求 URL 来自用户输入 |
| High | 弱加密 | MD5/SHA-1/DES/ECB/Random 非安全用途 |
| High | 硬编码密钥 | API Key / Password / Token 硬编码 |
| Medium | TOCTOU | 文件检查与使用非原子 |
| Medium | 日志注入 | 用户输入直接写日志 |

### 框架覆盖

## 执行指令（I/O 优化版）

> 以下执行方式遵循 `engine_contract.md` 和 `output_contract.md` 的性能要求。

### 源文件读取（index 驱动，非逐文件全读）

读取 `index.json` 后：
1. 从 `symbols.functions` 获取函数→文件映射表
2. 对每个检测器，按符号表定位目标函数所在的文件+行号
3. **只读取定位到的代码段**（前后 10 行作为上下文），不读无关文件全文

### 检测器加载（批量 + 按需）

1. 加载 `knowledge/language-index.md`（57 行，包含所有检测器清单）
2. 先做符号匹配快速过滤，仅加载匹配到的 detector 详情

### Finding 输出（批量）

1. 将所有 findings 收集到临时结构
2. 用 `python3 render-report.py --findings <dir>/findings.json --output <dir>` 批量输出

## 输出完整性要求
- Spring (Spring Boot, Spring Security, Spring MVC)
- MyBatis
- Hibernate / JPA
- FastJson / Jackson / Gson
- Apache Shiro
- Log4j / Logback

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
