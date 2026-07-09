---
name: secguard-js-prototype_pollution
description: "Detects prototype pollution through recursive merge, property path assignment, and query parsing"
language: javascript
topic: [prototype, pollution, security]
skill_id: js.prototype_pollution
signal_filter: js.prototype_pollution*
signal_source: call_sites[category="object"]
severity: high
cwe: [CWE-1321]
trigger_functions: [_.merge, _.defaultsDeep, _.set, Object.assign, qs.parse, for...in merge, split('.').reduce assign]
---

# prototype_pollution 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.prototype_pollution` |
| signal_source | `call_sites[cat="object"]` |
| trigger_functions | `_.merge(config, req.body)`, `_.set(target, req.query.path)`, `qs.parse(url)`, 递归 `for...in` 合并 |
| severity | High |
| CWE | CWE-1321 |

## Scenario 1: 递归合并 / 深层路径赋值

### 威胁定义

攻击者通过 `__proto__` 或 `constructor.prototype` 键名污染 JavaScript 对象原型链，导致全局对象行为篡改（权限绕过、XSS、RCE）。常见于 Express body 解析、qs 参数解析、lodash 合并操作。

### 检测逻辑

```javascript
// BAD: 递归合并无过滤
function merge(target, source) {
    for (let key in source) {
        if (typeof source[key] === 'object') {
            merge(target[key], source[key]);  // 未过滤 __proto__!
        } else {
            target[key] = source[key];
        }
    }
}
merge(config, req.body);  // 攻击: {"__proto__": {"isAdmin": true}}

// BAD: lodash 危险调用
_.merge(config, req.body);  // lodash < 4.17.11 有原型污染

// GOOD: 过滤危险键名
const BLOCKED = ['__proto__', 'constructor', 'prototype'];
if (BLOCKED.includes(key)) continue;
```

### 检测模式

```
# MATCH
function\s+merge.*for.*in.*target\[(?!.*BLOCKED|__proto__)  # 递归合并无过滤
_\.merge\([^,]*,\s*req\.(body|query|params)
_\.defaultsDeep\(.*req\.(body|query)
_\.set\(.*req\.(query|params)\.path
qs\.parse\(.*req\.url|qs\.parse\(.*req\.query

# EXCLUDE
Object\.create\(null\)
new Map\(
Object\.freeze\(Object\.prototype\)
BLOCKED\.includes|__proto__.*filter|constructor.*filter
lodash.*4\.1[7-9]|4\.[2-9]\d
```

### 修复指引

1. 使用 `Map` 替代普通对象存储键值对
2. 合并前过滤 `__proto__`/`constructor`/`prototype`
3. `Object.create(null)` 创建无原型对象
4. 升级 lodash >= 4.17.21

## 证据收集指引

- **code_context**: 合并函数的完整代码及调用处
- **judgment_rationale**: source 是否来自用户输入，是否有键名过滤

## 输出格式

三段式: Source（req.body/req.query 含 __proto__ 键）→ Propagate（合并/赋值函数）→ Sink（原型链污染导致应用行为异常）。
