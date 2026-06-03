---
name: js
description: 对 JavaScript/Node.js 代码进行通用安全规范检视，关注原型安全、异步错误处理和框架反模式。当用户请求JavaScript代码规范检视、Node.js反模式识别、前端安全规范、JS最佳实践审计时使用。
category: language-specific
language: javascript
topic: [web, crypto, system]
---

# 安全规范检视 — JavaScript/Node.js

对 JavaScript/TypeScript 代码进行通用安全规范检视，关注原型安全、异步错误处理和前端安全最佳实践。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 执行流程

### Phase 1: 加载上下文

1. 读取 `index.json`，获取 `files`、`symbols.functions`、`call_graph.edges`
2. 加载 `knowledge/languages/javascript.md` 获取 JS/Node.js 危险 API 清单

### Phase 2: 语义层面检视

| # | 检查项 | 检测方法 | 示例：不合规 |
|---|--------|---------|-------------|
| 1 | 原型污染防护 | 搜索 `Object.assign`/`_.merge`/扩展运算符 → 递归合并是否过滤 `__proto__` | `_.merge(config, req.body)` → 应使用 `_.merge({}, config, sanitize(req.body))` |
| 2 | NoSQL 注入防护 | 搜索 `findOne(`/`find(` → 查询条件是否校验类型 | `User.findOne({username: req.body.username})` — username 若是 `{$ne: null}` 可绕过 |
| 3 | SSTI 防护 | 搜索 `ejs.render`/`pug.compile`/`handlebars.compile` → 模板源是否来自用户 | `res.render(userTemplatePath)` → 仅使用静态模板路径 |
| 4 | 加密 API 安全 | 搜索 `crypto.createCipher`/`crypto.createHash('md5')` → 算法和模式选择 | `createCipher('aes-128-ecb', key)` → 应使用 `createCipheriv('aes-256-gcm', key, iv)` |
| 5 | Promise 错误传播 | 搜索 `await` 语句 → 是否有 try-catch 包裹或 `.catch()` 链 | `await fetchData()` 无 catch → 应加 `.catch(handleError)` |

### Phase 3: 规范合规检视

| # | 检查项 | 检测方法 | 修复指引 |
|---|--------|---------|---------|
| 1 | HTTP 安全头 | 检查是否使用 helmet 中间件 | `app.use(helmet())` 默认启用所有安全头 |
| 2 | Cookie 安全属性 | 搜索 `res.cookie(` → 选项是否含 secure/httpOnly/sameSite | `cookie('token', val, {httpOnly: true, secure: true, sameSite: 'strict'})` |
| 3 | CORS 配置 | 搜索 `cors(` → origin 是否为 `*` 或允许任意来源 | 白名单指定允许的 origin，禁止 `Access-Control-Allow-Origin: *` |
| 4 | npm 依赖安全 | 检查 package.json → 是否定期 audit | 在 CI 中运行 `npm audit --audit-level=high` |
| 5 | SSR 数据泄露 | 检查 Next.js/Nuxt → `getServerSideProps` 返回数据是否包含内部字段 | 序列化返回前剥离敏感字段（密码、token、内部 ID） |

### Phase 4: 反模式识别

| # | 反模式 | 检测特征 | 修复方案 |
|---|--------|---------|---------|
| 1 | eval / dynamic code | `eval()` / `new Function()` / `vm.runInNewContext()` | 使用 JSON.parse 替代 eval，避免动态代码执行 |
| 2 | Promise 未处理 rejection | await 无 try-catch，Promise 无 `.catch()` | 所有 await 包裹 try-catch，或统一 `process.on('unhandledRejection')` |
| 3 | Express 错误中间件泄露 | `err.stack` 返回给客户端 | 生产环境仅返回通用错误消息，堆栈写入日志系统 |
| 4 | innerHTML / dangerouslySetInnerHTML | 直接设置 HTML 且内容含用户输入 | 使用 `textContent` 或 DOMPurify 净化后设置 |
| 5 | localStorage 存储敏感数据 | JWT/Token 存储在 `localStorage.setItem()` | JWT 应存储在 httpOnly cookie，敏感数据仅内存持有 |
| 6 | Math.random() 用于安全 | 验证码/Token/密钥生成使用 `Math.random()` | 使用 `crypto.randomBytes()` 或 `crypto.randomUUID()` |
| 7 | Mongoose 敏感字段泄露 | Schema 中 password/token 未设 `select: false` | 敏感字段设置 `select: false`，查询时显式 `.select('+field')` |
| 8 | TypeScript any 绕过 | `(data as any).dangerousMethod()` | 定义完整类型接口，禁止 any 用于安全敏感路径 |
| 9 | Service Worker 缓存认证 | SW 缓存中包含 Authorization header 的响应 | 过滤认证相关请求，不缓存含 Authorization/Cookie 的响应 |

### Phase 5: 输出

遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)：`report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json`。

## 与 secguard-js 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
| 覆盖 | CWE Top 25 + 检测器 | OWASP + Node.js 安全最佳实践 |
