---
name: secreview-js
description: 对 JavaScript/Node.js 代码进行通用安全规范检视，关注原型安全、异步错误处理和框架反模式
category: language-specific
language: javascript
topic: [web, crypto, system]
---

# secreview-js

对 JavaScript/TypeScript 代码进行通用安全规范检视，关注原型安全、异步错误处理和前端安全最佳实践。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 检视范围

### 语义层面
- 对象合并不含 `__proto__` 过滤（原型污染）
- MongoDB 查询是否使用类型校验（NoSQL 注入）
- 模板引擎是否将用户输入作为模板内容（SSTI）
- 加密 API 是否使用安全模式和参数
- 异常处理是否在 Promise reject / async 中正确传播

### 规范合规
- HTTP 安全头是否正确配置（helmet/CSP/HSTS）
- Cookie 是否设置 `secure`/`httpOnly`/`sameSite`
- CORS 配置是否过于宽松（`Access-Control-Allow-Origin: *`）
- 依赖是否包含已知漏洞（npm audit）
- SSR 是否泄露内部数据到客户端

### 反模式识别
- `eval` / `new Function` / `vm.runInNewContext` 滥用
- Promise 未 catch 或 async 无 try-catch（错误吞掉）
- Express 错误中间件返回完整堆栈
- `innerHTML` / `dangerouslySetInnerHTML` 使用用户输入
- `Math.random()` 用于安全敏感场景
- `localStorage` 存储 JWT/session token
- Mongoose Schema 未标记 `select: false` 的敏感字段
- TypeScript `any` 类型绕过类型校验
- 深层嵌套回调中的错误处理遗漏
- Service Worker 缓存包含认证信息

## 与 secguard-js 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
