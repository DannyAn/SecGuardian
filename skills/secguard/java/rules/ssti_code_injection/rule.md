---
name: secguard-java-ssti-code-injection
description: "检测 Java 服务端模板注入 / 代码注入 — Freemarker / Velocity / SpEL / Thymeleaf / ScriptEngine.eval 用户输入"
language: java
topic: [web, template, injection, ssti]
skill_id: java.ssti-code-injection.dynamic
signal_source: call_sites[callee="render|evaluate|processTemplate|Velocity|FreeMarker|Thymeleaf|GroovyShell|ScriptEngine"]
severity: critical
cwe: CWE-1336
trigger_functions: [evaluate, parseExpression, getValue, process, newStringReader, eval, ScriptEngine]
---

# ssti_code_injection 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.ssti-code-injection.dynamic` | `call_sites[cat="template"]` | `evaluate`, `parseExpression`, `getValue`, `process`, `eval`, `ScriptEngine` | Critical | CWE-1336 |

## Scenario 1: 模板引擎 / 脚本引擎编译用户输入

### 威胁定义
攻击者通过用户输入控制模板内容或表达式，在服务端执行任意代码。Java 框架中 Freemarker `Template(StringReader)`、Velocity `evaluate`、SpEL `parseExpression`、Thymeleaf `templateEngine.process` 模板名可控等均可导致 RCE。`ScriptEngine.eval(jsCode)` 注入 JavaScript 同样危险。

### 检测逻辑
```java
// BAD: Freemarker 编译用户输入
Template t = new Template("user", new StringReader(request.getParameter("template")), cfg);
t.process(data, writer);

// BAD: Velocity evaluate 用户输入
Velocity.evaluate(ctx, writer, "log", request.getParameter("input"));

// BAD: SpEL 表达式来自用户
ExpressionParser parser = new SpelExpressionParser();
parser.parseExpression(request.getParameter("expr")).getValue();

// BAD: ScriptEngine.eval
ScriptEngineManager mgr = new ScriptEngineManager();
ScriptEngine engine = mgr.getEngineByName("JavaScript");
engine.eval(userInput);

// BAD: Thymeleaf 模板名可控
templateEngine.process(userTemplateName, ctx);

// GOOD: 静态模板 + 变量传入
ModelAndView mav = new ModelAndView("user/profile");
mav.addObject("name", request.getParameter("name"));
```

### 检测模式
**MATCH**: `new Template(.*getParameter` / `new StringReader(.*getParameter`；`Velocity.evaluate(.*getParameter`；`SpelExpressionParser.*getParameter`；`templateEngine.process(.*getParameter`；`ScriptEngine.eval(.*(request|getParameter|userInput)`

**EXCLUDE**: 模板名为静态字面量（`"user/profile"`）；`addObject` 传入值为变量（非模板内容）

### 修复指引
1. 首选：使用静态模板文件，用户输入仅作为模板变量传入
2. 次选：Freemarker `SAFER_RESOLVER` / SpEL `SimpleEvaluationContext` 限制解析范围
3. 禁止：`ScriptEngine.eval(用户输入)` / `Template(用户输入)` / `Velocity.evaluate(用户输入)`

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 模板/脚本编译调用及参数来源代码 |
| judgment_rationale | MUST | 用户输入是否直接作为模板内容 vs 模板变量 |
| data_flow_path | SHOULD | 用户输入到模板引擎的完整路径 |
| sanitizer_analysis | SHOULD | 沙箱 / 受限解析器配置分析 |

## 输出格式
`[Critical][CWE-1336] {file}:{line} — SSTI/代码注入（{framework}）`
