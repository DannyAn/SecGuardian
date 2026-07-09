---
name: secguard-js-nosql_injection
description: "Detects NoSQL injection vulnerabilities where user input is passed directly to MongoDB queries"
language: javascript
topic: [nosql, injection, mongodb]
skill_id: js.nosql_injection
signal_filter: js.nosql_injection*
signal_source: call_sites[category="nosql"]
severity: critical
cwe: [CWE-943]
trigger_functions: [User.find, User.findOne, User.findById, User.findOneAndUpdate, Model.aggregate, $where, $regex, $function]
---

# nosql_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.nosql_injection` |
| signal_source | `call_sites[cat="nosql"]` |
| trigger_functions | `User.find(req.body)`, `$where` 拼接, `$regex` 用户可控, `aggregate(req.body.pipeline)` |
| severity | Critical |
| CWE | CWE-943 |

## Scenario 1: 查询操作符注入

### 威胁定义

攻击者利用 MongoDB 操作符语义（`$ne`, `$gt`, `$regex`）绕过认证或越权访问数据。Express/NestJS/Next.js API 中使用 `req.body`/`req.query` 直接构造 Mongoose 查询时最常发生。

### 检测逻辑

```javascript
// BAD: body 直接作查询（操作符注入）
const user = await User.findOne({ username: req.body.username, password: req.body.password });
// 攻击: {"username": {"$ne": ""}, "password": {"$ne": ""}} → 返回任意用户

// BAD: query 直接作查询
const users = await User.find(req.query);

// GOOD: 显式类型约束
const { username } = req.body;
if (typeof username !== 'string') return res.status(400);
await User.findOne({ username });
```

### 检测模式

```
# MATCH
User\.(find|findOne|findById|findOneAndUpdate)\(req\.body
User\.(find|findOne)\(req\.query
\$where.*\+.*req\.|\$where.*\$\{.*req\.
\$regex\s*:\s*req\.(query|body|params)
aggregate\(req\.body\.pipeline

# EXCLUDE
(mongo-sanitize|express-mongo-sanitize)
typeof\s+\w+\s*===\s*['"]string['"]
Schema\.Types\.(String|Number|Boolean)
\$regex\s*:\s*\/\^\[a-zA-Z0-9
```

### 修复指引

1. 使用 Mongoose Schema 类型校验 + `mongo-sanitize` 中间件
2. 验证输入类型（`typeof input === 'string'`），拒绝 Object
3. 禁止 `$where`/`$function` 与用户输入拼接

## 证据收集指引

- **code_context**: 查询语句及输入来源的完整代码
- **judgment_rationale**: 用户输入是否作为查询操作符传递，是否经过类型约束

## 输出格式

采用三段式证据链: Source（用户输入入口）→ Propagate（查询构造）→ Sink（Mongoose 查询执行点）。
