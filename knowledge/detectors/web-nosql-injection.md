---
detector: web-nosql-injection
severity: critical
cwe: CWE-943
language: [js]
tags: [web, nosql, mongodb, injection]
---

# NoSQL 注入 (NoSQL Injection)

## 威胁定义

检测 Node.js/MongoDB 代码中是否将不可信数据直接作为查询操作符传入，导致认证绕过、数据泄露或代码执行。

## 检测逻辑

### Step 1: MongoDB 查询对象直接使用请求数据

```javascript
// BAD: body 直接作查询（操作符注入）
app.post('/login', async (req, res) => {
    const user = await User.findOne({ username: req.body.username, password: req.body.password });
    // 攻击者发送: {"username": {"$ne": ""}, "password": {"$ne": ""}}
    // → 查询变为 {username: {$ne: ""}, password: {$ne: ""}} → 返回任意用户!
});

// BAD: query 参数直接作查询
app.get('/users', async (req, res) => {
    const users = await User.find(req.query);  // 完全可控查询!
});

// BAD: Mongoose 查询条件来自 body
await User.findOne(req.body);  // body 直接作为查询条件
```

**安全模式:**
```javascript
// GOOD: 显式类型约束
app.post('/login', async (req, res) => {
    const { username, password } = req.body;
    if (typeof username !== 'string' || typeof password !== 'string') {
        return res.status(400).json({ error: 'Invalid input' });
    }
    const user = await User.findOne({ username, password });
});
```

### Step 2: `$where` 操作符拼接

```javascript
// BAD: $where 拼接用户输入（JS 代码注入!）
app.get('/search', async (req, res) => {
    const results = await Collection.find({
        $where: `this.name == '${req.query.name}'`  // JS 代码拼接!
    });
});

// BAD: $where 接受函数体字符串
const query = `function() { return this.age > ${req.query.minAge} }`;
await Collection.find({ $where: query });
```

### Step 3: `$regex` 注入

```javascript
// BAD: $regex 无限制（盲注/ReDoS）
app.get('/search', async (req, res) => {
    const users = await User.find({
        name: { $regex: req.query.name }  // 攻击: ^(admin) → 可枚举数据
    });
});

// BAD: $regex 未限制输入长度
app.get('/search', async (req, res) => {
    const users = await User.find({
        email: { $regex: req.query.email, $options: 'i' }
    });
});
```

### Step 4: 聚合管道注入

```javascript
// BAD: $lookup / $graphLookup 参数来自用户
app.get('/data', async (req, res) => {
    const result = await Collection.aggregate([
        { $lookup: {
            from: req.query.collection,  // 用户可控集合名!
            localField: 'id',
            foreignField: req.query.field,  // 用户可控字段!
            as: 'related'
        }}
    ]);
});

// BAD: 聚合管道完全可控
await Collection.aggregate(req.body.pipeline);  // 完全可控!
```

### Step 5: `$function` 操作符 (MongoDB 4.4+)

```javascript
// BAD: $function 接受用户输入（JS 执行!）
await Collection.aggregate([{
    $addFields: {
        result: {
            $function: {
                body: req.body.jsCode,  // 攻击者控制 JS 代码!
                args: [],
                lang: 'js'
            }
        }
    }
}]);
```

## 修复指引

1. **首选**：使用 Mongoose Schema 类型校验 + 移除 `$`/`.` 字符（`mongo-sanitize`）
2. **次选**：验证用户输入类型（`typeof input === 'string'`），拒绝 Object 类型输入
3. **禁止**：`$where`/`$function` 与用户输入拼接
4. 聚合管道结构固化，不允许用户控制管道阶段

## 误报排除

| 场景 | 原因 |
|------|------|
| 使用 `mongo-sanitize` / `express-mongo-sanitize` 中间件 | 已过滤操作符 |
| 显式类型校验 (`typeof input === 'string'`) | 已拒绝 Object 类型 |
| Mongoose Schema 类型强约束 (Number/String) | Schema 层保护 |
| 查询字段来自内部枚举/常量 | 非用户输入 |
| `$regex` 配合严格白名单正则 | 有输入限制 |

## 检测模式汇总

```
# 操作符注入
User\.(find|findOne|findById|findOneAndUpdate)\(req\.body
User\.(find|findOne)\(req\.query
\.find\(.*\.body\)|\.findOne\(.*\.body\)

# $where 拼接
\$where.*\+.*req\.|req\.query.*\$where
\$where\s*:\s*`.*\$\{.*req\.
\$where.*function\(\)\s*\{.*req\.

# $regex 注入
\$regex\s*:\s*req\.(query|body|params)
\$regex\s*:\s*new RegExp\(req\.
\$regex\s*:\s*\{\s*\$regex\s*:\s*.*input

# 聚合注入
aggregate\(req\.body\.pipeline
\$lookup.*req\.(query|body)
\$function.*req\.(body|query).*lang.*js
\$graphLookup.*req\.
```
