---
detector: web-prototype-pollution
severity: high
cwe: CWE-1321
language: [js]
tags: [web, javascript, prototype, pollution]
---

# 原型污染 (Prototype Pollution)

## 威胁定义

检测 JavaScript 代码中不可信数据是否可能污染 `Object.prototype`/`__proto__`，导致应用全局对象行为被篡改（权限绕过、XSS、RCE）。

## 检测逻辑

### Step 1: 危险合并/克隆操作

```javascript
// BAD: 递归合并无过滤
function merge(target, source) {
    for (let key in source) {
        if (typeof source[key] === 'object') {
            merge(target[key], source[key]);  // 危险键名未过滤!
        } else {
            target[key] = source[key];  // __proto__ 可被赋值!
        }
    }
}
merge(config, req.body);
// 攻击: {"__proto__": {"isAdmin": true}} → 所有对象继承 isAdmin!

// BAD: lodash _.merge 旧版本
const _ = require('lodash');
_.merge(config, req.body);  // lodash < 4.17.11 存在原型污染

// BAD: _.defaultsDeep
_.defaultsDeep({}, req.body);  // 同样危险

// BAD: Object.assign 嵌套对象
Object.assign(target, JSON.parse(userInput));
```

**安全模式:**
```javascript
// GOOD: 过滤危险键名
function safeMerge(target, source) {
    const BLOCKED = ['__proto__', 'constructor', 'prototype'];
    for (let key in source) {
        if (BLOCKED.includes(key)) continue;
        if (typeof source[key] === 'object' && source[key] !== null) {
            target[key] = safeMerge(target[key] || {}, source[key]);
        } else {
            target[key] = source[key];
        }
    }
    return target;
}

// GOOD: 使用 Map 替代普通对象
const config = new Map();
config.set(req.body.key, req.body.value);  // Map 无原型链污染
```

### Step 2: 属性路径设置

```javascript
// BAD: 深层属性赋值（路径来自用户）
function setValue(obj, path, value) {
    const keys = path.split('.');
    let current = obj;
    for (let i = 0; i < keys.length - 1; i++) {
        current = current[keys[i]] = current[keys[i]] || {};
    }
    current[keys[keys.length - 1]] = value;
}
setValue(appConfig, req.body.path, req.body.value);
// 攻击: path = "__proto__.isAdmin", value = true

// BAD: lodash _.set
_.set(target, req.query.path, req.body.value);  // path 可控!
```

### Step 3: URL 解析污染

```javascript
// BAD: URL query 解析为对象
const url = require('url');
const qs = require('qs');
const parsed = qs.parse(req.url.split('?')[1]);
// ?__proto__[isAdmin]=true → parsed.__proto__.isAdmin
Object.assign(config, parsed);

// BAD: Express query parser
app.set('query parser', 'simple');  // simple parser 仍有风险
```

### Step 4: 框架特定模式

```javascript
// BAD: Vue.js SSR 序列化
const state = JSON.parse(require('fs').readFileSync('state.json'));
// state.json 包含 __proto__ 污染链

// BAD: AngularJS $parse
$parse(userExpression)(scope);  // 表达式可污染原型

// BAD: MongoDB 操作符合并
const update = { $set: req.body.fields };  // fields 可能含 __proto__
await User.updateOne({ _id: id }, update);
```

## 修复指引

1. **首选**：使用 `Map` 替代普通对象存储键值对
2. **次选**：合并前过滤 `__proto__`/`constructor`/`prototype` 键名
3. **最小修复**：`Object.create(null)` 创建无原型对象 / `Object.freeze(Object.prototype)`
4. **升级**：lodash ≥ 4.17.21 已修复原型污染

## 误报排除

| 场景 | 原因 |
|------|------|
| `Object.create(null)` 创建的对象 | 无原型链 |
| `Map` 数据结构 | 无原型 |
| `Object.freeze(Object.prototype)` | 原型已冻结 |
| lodash >= 4.17.21（原型污染已修复） | 版本安全 |
| 合并前过滤了 `__proto__`/`constructor`/`prototype` | 已防护 |
| 仅合并内部数据（非用户输入） | 无可信边界 |
| `JSON.parse(JSON.stringify(obj))` — Lossy 但安全 | 非对象类型丢失但原型不会传播 |

## 检测模式汇总

```
# 递归合并无过滤
function\s+merge\s*\([^)]*\)\s*\{[^}]*for[^}]*in[^}]*(?!.*__proto__|constructor|prototype)
for\s*\(.*in\s+source[^}]*\{.*target\[  → 无 BLOCKED 检查

# lodash 危险调用
_\.merge\([^,]*,\s*req\.(body|query|params)
_\.defaultsDeep\(.*req\.(body|query)
_\.set\(.*req\.(query|params)\.path

# query 解析 + 合并
qs\.parse\(.*req\.url|qs\.parse\(.*req\.query
→ Object\.assign|_.merge 使用了解析结果

# 深层属性路径赋值
\.split\(['"]\.['"]\).*req\.  → 用户可控路径
keys\.split\(['"]\.['"]\)      → 无 __proto__ 过滤
```
