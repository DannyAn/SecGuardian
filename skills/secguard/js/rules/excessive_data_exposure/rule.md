---
name: secguard-js-excessive_data_exposure
description: "Detects exposing full database objects to clients without field projection or serialization control"
language: javascript
topic: [exposure, api, privacy]
skill_id: js.excessive_data_exposure
signal_filter: js.excessive_data_exposure*
signal_source: call_sites[category="output"]
severity: medium
cwe: [CWE-200]
trigger_functions: [res.json(user), res.send(user), res.json(user.toObject()), res.json({data: user}), Model.find().then(res.json)]
---

# excessive_data_exposure 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.excessive_data_exposure` |
| signal_source | `call_sites[cat="output"]` |
| trigger_functions | `res.json(user)` 全字段, 无 `.select()` 投影, 无 ClassSerializerInterceptor |
| severity | Medium |
| CWE | CWE-200 |

## Scenario 1: 全字段 API 响应

### 威胁定义

API 端点返回完整数据库对象（含 passwordHash、internalToken、SSN 等敏感字段），攻击者可获取非必要的用户敏感数据。

### 检测逻辑

```javascript
// BAD: 返回完整 Mongoose 文档
app.get('/user/:id', async (req, res) => {
    const user = await User.findById(req.params.id);
    res.json(user);  // 含 passwordHash, internalNotes, creditCardLast4
});

// BAD: 查询无 select 投影
const users = await User.find();  // 返回所有字段
res.json(users);

// GOOD: 显式投影 + DTO
const user = await User.findById(id).select('name email avatar');
res.json({ id: user.id, name: user.name, email: user.email });

// GOOD: NestJS ClassSerializerInterceptor
@UseInterceptors(ClassSerializerInterceptor)
@Exclude() passwordHash;
```

### 检测模式

```
# MATCH
res\.json\(user|res\.json\(.*\.toObject\(\)|res\.json\(.*\.toJSON\(\)
res\.send\(user|res\.send\(.*\.toObject\(\)
res\.json\(\{[^}]*user|res\.json\(\{[^}]*data
User\.find\(\)\.then\(res\.json

# EXCLUDE
\.select\(['"][^'"]+['"]\s*\)              # 有投影
\@Exclude\(\)|\.omit\(|pick\(               # 有排除
toJSON\(\) 且 toJSON 含 exclude 逻辑
ClassSerializerInterceptor|SerializeOptions
```

### 修复指引

1. 使用 Mongoose `.select()` 显式投影
2. DTO/ViewModel 模式（类型化响应模型）
3. NestJS: `@Exclude()` + `ClassSerializerInterceptor`
4. JS: `_.pick(user, ['name', 'email'])` 白名单字段

## 证据收集指引

- **code_context**: API 响应构建的完整代码
- **judgment_rationale**: 是否包含不应暴露给客户端的敏感字段

## 输出格式

三段式: Source（Mongoose documents/DB 查询结果）→ Propagate（无投影/DTO 转换）→ Sink（res.json/res.send 发送全部字段）。
