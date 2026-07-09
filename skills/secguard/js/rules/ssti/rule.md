---
name: secguard-js-ssti
description: "Detects server-side template injection in EJS, Pug, Handlebars, and Nunjucks"
language: javascript
topic: [ssti, template, injection]
skill_id: js.ssti
signal_filter: js.ssti*
signal_source: call_sites[category="template"]
severity: critical
cwe: [CWE-1336]
trigger_functions: [ejs.render, ejs.compile, pug.compile, Handlebars.compile, nunjucks.renderString]
---

# ssti 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.ssti` |
| signal_source | `call_sites[cat="template"]` |
| trigger_functions | `ejs.render(userInput)`, `pug.compile(req.body.template)`, `Handlebars.compile()`, `nunjucks.renderString()` |
| severity | Critical |
| CWE | CWE-1336 |

## Scenario 1: 模板注入

### 威胁定义

攻击者通过将模板语法嵌入用户输入，在服务端模板引擎中执行任意代码。EJS 最危险（`<%= process.mainModule... %>` 可达 RCE），Pug/Handlebars 也有类似的表达式注入风险。

### 检测逻辑

```javascript
// BAD: EJS 模板注入
const html = ejs.render(`<h1>Hello ${req.query.name}</h1>`);
// 攻击: ?name=<%= process.mainModule.require('child_process').execSync('id') %>

// BAD: Pug compile 用户输入
const fn = pug.compile(req.body.template);

// BAD: Handlebars 动态模板
const template = Handlebars.compile(req.body.template);

// GOOD: 静态模板文件，用户输入仅作变量
res.render('hello', { name: req.query.name });
```

### 检测模式

```
# MATCH
ejs\.render\(`.*req\.|ejs\.render\(.*req\.(query|body)
pug\.compile\(req\.|Handlebars\.compile\(req\.
nunjucks\.renderString\(.*req\.

# EXCLUDE
render\(['"][\w/]+['"]                     # 静态模板文件
ejs\.renderFile\(                           # 文件渲染
Handlebars\.precompile\(                    # 预编译
```

### 修复指引

1. 使用静态模板文件，用户输入仅作模板变量
2. 禁止 `ejs.render(templateString)` 直接渲染用户输入
3. Handlebars 配置 `noEscape: false`

## 证据收集指引

- **code_context**: 模板渲染调用的完整代码，标注模板内容来源
- **judgment_rationale**: 用户输入是否直接作为模板内容 vs 模板变量

## 输出格式

三段式: Source（req.query.template/req.body.name）→ Propagate（模板字符串拼接）→ Sink（ejs.render/pug.compile/Handlebars.compile）。
