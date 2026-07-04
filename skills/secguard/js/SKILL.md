---
name: secguard-js
description: 对 JavaScript/TypeScript 代码进行安全加固项排查，扫描危险函数调用、原型污染、NoSQL 注入等漏洞。当用户请求JavaScript安全扫描、Node.js安全审计、前端安全、原型污染检测、npm安全时使用。
category: language-specific
language: javascript
topic: [web, crypto, system]
---

# JavaScript/Node.js 安全加固排查

对 JavaScript/TypeScript 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 🎯 Detector Selection (Skill Layer)
## ⚙️ Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。

## 执行流程

> **前置条件**: Command 层面已完成 `secguardian-index` 索引器调用，`index.json` 已生成在扫描输出目录下。包含 `symbols.functions`（函数→文件:行号）、`call_graph.edges`（调用关系）、`files`（文件清单）。
>
> **禁止事项**：❌ 不要启动 clangd 或任何 LSP server（indexer 已提供所有代码结构数据）。❌ 不要用 find/ls/glob 重新遍历文件系统。❌ 不要逐文件全文读取——始终从 indexer 数据出发精准定位。

1. 读取 Command 生成的 `index.json`，获取文件清单、符号表和调用图。**从 symbols.functions 构建函数名→{文件:行号} 查找表，检测器按需查表定位目标函数后精准读取，不扫描无关文件。**
2. 加载 `knowledge/languages/javascript.md` 获取 JS 危险 API 清单
3. 加载 `knowledge/threat-catalog.md` 获取威胁全景，再按需加载 `knowledge/guard-rules/<name>.md`（每个 detector 自包含威胁定义+检测逻辑+修复指引）
4. 基于 index.json 的符号表定位检测目标，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | NoSQL 注入 | Mongoose `findOne(req.body)` / `$where` 拼接 / `aggregate` 用户可控 |
| Critical | 命令注入 | `child_process.exec(userInput)` / `execSync` / `spawn({shell:true})` |
| Critical | 代码注入 | `eval(userInput)` / `new Function(input)` / `vm.runInNewContext` |
| Critical | SSTI | `ejs.render(userInput)` / `pug.compile(req.body.template)` |
| High | 原型污染 | 递归合并无过滤 / `_.merge(config, req.body)` / 深层路径赋值 |
| High | 路径穿越 | `fs.readFile(userPath)` 无 resolve 校验 / `express.static` 目录遍历 |
| High | SSRF | `http.get(userURL)` 未验证 / `axios.get(req.query.url)` |
| High | 弱加密 | `crypto.createHash('md5')` / `Math.random()` 安全用途 / AES-ECB |
| High | 硬编码密钥 | API Key / JWT Secret / Password 硬编码 |
| Medium | 信息泄露 | `res.send(err.stack)` / `NODE_ENV != production` / debug 中间件 |
| Medium | 日志注入 | `console.log(userInput)` 无换行过滤 |
| Medium | 过度数据暴露 | `res.json(user)` 全字段（含 passwordHash）/ 无 `.select()` 投影 |
| Medium | 批量分配 | `new User(req.body)` / `Model.update(req.body)` 无白名单 |

### 框架覆盖
- Express (路由, 中间件, 错误处理)
- NestJS (装饰器, DTO, Guard)
- Next.js (API Routes, SSR, getServerSideProps)
- Mongoose (Schema, Query, Middleware)
- Sequelize / Prisma (ORM 模式)
- Node.js 标准库 (child_process, crypto, fs, http)
- 前端框架 (React dangerouslySetInnerHTML, Vue v-html, innerHTML)

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
