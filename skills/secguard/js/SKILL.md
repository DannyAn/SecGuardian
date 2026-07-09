---
name: secguard-js
description: 对 JavaScript/TypeScript 代码进行安全加固检视，编排 13 个子 skill，覆盖 API 调用检测、原型污染语义分析、异步安全契约验证等多个维度。当用户请求 JavaScript 安全扫描、Node.js 安全审计、前端安全、原型污染检测、npm 安全时使用。
category: language-specific
language: javascript
topic: [web, crypto, system]
---

# JavaScript/TypeScript 安全加固排查 — 检视算子索引

本文件是 `skills/secguard/js/` 下 13 个检视算子 skill 的主索引 / 派发表。
每个算子对应 `rules/` 下的一个规则目录，包含自己的 `rule.md`。

> **执行流程由 `commands/claude/secguard.md` 的 Dispatcher 协议调度。**

---

## 1. 检视算子一览

| # | Rule (目录名) | Severity | CWE | `signal_source` | `id` | Guard-rule 参考 |
|---|---------------|----------|-----|-----------------|------|----------------|
| 1 | [`nosql_injection/`](./rules/nosql_injection/) | Critical | CWE-943 | `Signal Type: nosql_operation` | `js.nosql_injection` | `web-nosql-injection` |
| 2 | [`command_injection/`](./rules/command_injection/) | Critical | CWE-78 | `Signal Type: exec_operation` | `js.command_injection` | `system-command-injection` |
| 3 | [`code_injection/`](./rules/code_injection/) | Critical | CWE-94 | `Signal Type: code_execution` | `js.code_injection` | `web-code-injection` |
| 4 | [`ssti/`](./rules/ssti/) | Critical | CWE-1336 | `Signal Type: ssti (template injection)` | `js.ssti` | `web-ssti` |
| 5 | [`prototype_pollution/`](./rules/prototype_pollution/) | High | CWE-1321 | `Signal Type: object_operation` | `js.prototype_pollution` | `web-prototype-pollution` |
| 6 | [`path_traversal/`](./rules/path_traversal/) | High | CWE-22 | `Signal Type: resource_acquire (file I/O)` | `js.path_traversal` | `web-path-traversal` |
| 7 | [`ssrf/`](./rules/ssrf/) | High | CWE-918 | `Signal Type: http_request` | `js.ssrf` | `web-ssrf` |
| 8 | [`weak_crypto/`](./rules/weak_crypto/) | High | CWE-327 | `Signal Type: crypto_operation` | `js.weak_crypto` | `crypto-weak-crypto-algorithm` |
| 9 | [`hardcoded_secrets/`](./rules/hardcoded_secrets/) | High | CWE-798 | `Signal Type: crypto_operation` | `js.hardcoded_secrets` | `crypto-hardcoded-secrets` |
| 10 | [`info_leak/`](./rules/info_leak/) | Medium | CWE-200 | `Signal Type: output_operation` | `js.info_leak` | `web-information-leakage` |
| 11 | [`log_injection/`](./rules/log_injection/) | Medium | CWE-117 | `Signal Type: log_operation` | `js.log_injection` | `log-injection` |
| 12 | [`excessive_data_exposure/`](./rules/excessive_data_exposure/) | Medium | CWE-200 | `Signal Type: output_operation` | `js.excessive_data_exposure` | `web-excessive-data-exposure` |
| 13 | [`mass_assignment/`](./rules/mass_assignment/) | Medium | CWE-915 | `Signal Type: orm_operation` | `js.mass_assignment` | `mass-assignment` |

**排序执行**: Critical (4) → High (5) → Medium (4)

## 2. 信号源分类 → Skill 映射

| `call_sites` Category | 触发的 Rule 目录 | trigger_functions（示例） |
|-----------------------|-----------------|---------------------------|
| `"nosql"` | `nosql_injection` | `User.find`, `$where`, `Model.aggregate` |
| `"exec"` | `command_injection` | `exec`, `execSync`, `spawn` |
| `"code_exec"` | `code_injection` | `eval`, `new Function`, `vm.runInNewContext` |
| `"template"` | `ssti` | `ejs.render`, `pug.compile`, `Handlebars.compile` |
| `"object"` | `prototype_pollution` | `_.merge`, `qs.parse`, `for...in merge` |
| `"fs"` | `path_traversal` | `fs.readFile`, `path.join`, `createReadStream` |
| `"http"` | `ssrf` | `axios.get`, `fetch`, `http.get` |
| `"crypto"` | `weak_crypto`, `hardcoded_secrets` | `crypto.createHash`, `Math.random`, hardcoded secrets |
| `"output"` | `info_leak`, `excessive_data_exposure` | `res.send(err)`, `res.json(user)` |
| `"log"` | `log_injection` | `console.log`, `logger.info` |
| `"orm"` | `mass_assignment` | `new User(req.body)`, `Model.create`, `Object.assign` |

## 3. 参考文件

| 文件 | 内容 |
|------|------|
| `references/language-features.md` | JS 危险 API 清单（命令执行、代码注入、NoSQL、SSTI、原型污染、路径穿越、加密） |
| `rules/*/rule.md` | 各 skill 检出规则（威胁定义、检测逻辑、修复指引） |
