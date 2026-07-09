---
name: secguard-js-mass_assignment
description: "Detects mass assignment where user input is used directly to create or update database records"
language: javascript
topic: [mass, assignment, orm]
skill_id: js.mass_assignment
signal_filter: js.mass_assignment*
signal_source: call_sites[category="orm"]
severity: medium
cwe: [CWE-915]
trigger_functions: [new User(req.body), Model.create(req.body), Model.update(req.body), Model.findOneAndUpdate(req.body), Object.assign(user, req.body)]
---

# mass_assignment 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.mass_assignment` |
| signal_source | `call_sites[cat="orm"]` |
| trigger_functions | `new User(req.body)`, `Model.create(req.body)`, `Model.update(req.body)`, `Object.assign(user, req.body)` |
| severity | Medium |
| CWE | CWE-915 |

## Scenario 1: 批量赋值

### 威胁定义

攻击者通过在请求体中包含额外字段（如 `isAdmin`、`role`），在创建或更新操作中提升权限或修改敏感属性。

### 检测逻辑

```javascript
// BAD: body 直接创建记录
const user = new User(req.body);
await user.save();
// 攻击: POST {"username": "admin", "password": "hacked", "isAdmin": true, "role": "superuser"}

// BAD: update 全字段覆盖
await User.findByIdAndUpdate(id, req.body);  // 可覆盖任意字段

// BAD: Object.assign
Object.assign(user, req.body);  // 可覆盖 isAdmin 等保护字段

// GOOD: 白名单字段
const { username, password } = req.body;
const user = new User({ username, password });

// GOOD: 使用 Schema immutable
isAdmin: { type: Boolean, immutable: true }  // 禁止修改
```

### 检测模式

```
# MATCH
new\s+\w+\(req\.body\)|Model\.create\(req\.body
Model\.(update|findByIdAndUpdate|findOneAndUpdate|updateOne|updateMany)\([^,]+,\s*req\.body
Object\.assign\(([^,]+,\s*)*req\.body
\.\.\.req\.body                                 # spread 操作符批量赋值

# EXCLUDE
\{[^}]*\}\s*=\s*req\.body（解构赋值）         # 显式解构白名单
Schema.*immutable.*true                         # 不可变字段保护
whitelist|allowedFields|permittedFields         # 白名单字段列表
class-validator|class-transformer|@Exclude      # DTO 校验
```

### 修复指引

1. 显式解构赋值白名单（`const { username, password } = req.body`）
2. Mongoose Schema `immutable: true` 标记敏感字段
3. NestJS: class-validator DTO + `@Exclude()` / `@Expose()` 控制字段
4. 避免 `Object.assign(model, req.body)` 全字段覆盖

## 证据收集指引

- **code_context**: ORM 创建/更新操作及 body 参数的完整代码
- **judgment_rationale**: 用户输入字段是否全量映射到 Model 属性，是否有白名单保护

## 输出格式

三段式: Source（req.body 全字段）→ Propagate（new Model / update / Object.assign）→ Sink（敏感字段被覆盖导致权限提升）。
