---
name: secguard-js-code_injection
description: "Detects code injection through eval, Function constructor, and vm execution"
language: javascript
topic: [injection, code, eval]
skill_id: js.code_injection
signal_filter: js.code_injection*
signal_source: call_sites[category="code_exec"]
severity: critical
cwe: [CWE-94]
trigger_functions: [eval, new Function, vm.runInNewContext, vm.runInThisContext, setTimeout(string), setInterval(string)]
---

# code_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.code_injection` |
| signal_source | `call_sites[cat="code_exec"]` |
| trigger_functions | `eval(userInput)`, `new Function(input)`, `vm.runInNewContext(code)`, `setTimeout(string)` |
| severity | Critical |
| CWE | CWE-94 |

## Scenario 1: eval / Function / vm 注入

### 威胁定义

攻击者利用 `eval()` / `new Function()` / `vm.runInNewContext()` 注入任意 JS 代码，导致 RCE、数据泄露或拒绝服务。`vm` 模块的沙箱可被绕过（通过 `this.constructor.constructor`）。

### 检测逻辑

```javascript
// BAD: eval 用户输入
eval('var result = ' + req.query.expr);  // 攻击: expr = "process.exit(1)"

// BAD: new Function
const fn = new Function('return ' + req.body.code);

// BAD: vm.runInNewContext（沙箱可绕过）
const vm = require('vm');
vm.runInNewContext(userCode, {}, {timeout: 1000});

// GOOD: 避免动态代码执行
const operators = { '+': (a,b) => a + b, '-': (a,b) => a - b };
const result = operators[req.query.op](a, b);
```

### 检测模式

```
# MATCH
eval\(.*req\.|eval\(.*user|eval\(.*input
new\s+Function\(.*req\.|new\s+Function\(.*user
vm\.runInNewContext\(.*req\.|vm\.runInThisContext\(.*req\.
setTimeout\(.*req\.|setInterval\(.*req\.

# EXCLUDE
eval\(['"][^'"]*['"]\)                     # 硬编码
JSON\.parse\(                              # JSON 解析
vm\.runInNewContext\(['"][^'"]*['"]        # 硬编码代码
```

### 修复指引

1. 彻底禁止 `eval()` / `new Function()` / `vm.*` 处理用户输入
2. 用白名单解析器或沙箱替代动态执行
3. 对 `setTimeout`/`setInterval` 只传函数引用

## 证据收集指引

- **code_context**: 代码执行函数的完整调用，含传递的表达式/代码字符串
- **judgment_rationale**: 执行字符串是否来自用户输入，是否有沙箱保护

## 输出格式

三段式: Source（req.body.code/req.query.expr）→ Propagate（字符串拼接/模板）→ Sink（eval/Function/vm.runInNewContext）。
