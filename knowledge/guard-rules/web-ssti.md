---
detector: web-ssti
description: Detects server-side template injection vulnerabilities where user input is embedded in templates
severity: critical
cwe: CWE-1336
cvss: 9.8
language: [java, python, go, js]
tags: [web, template, injection, ssti]
precision: very-high
confidence: dynamic
target_functions: [addObject, args, body, code_context, compile, data, ejs, evaluate, execSync, form, get, getParameter, getValue, handler, hello, json, judgment_rationale, parseExpression, process, query, render, renderString, render_template, render_template_string, require, route, send, subclasses, substitute, template]
match_patterns: [render_template_string\(.*request\.(args|form|data|json), Template\(request\.(args|form|data)\['\w+'\], mako\.template\.Template\(.*request\., from\s+string\s+import\s+Template.*Template\(.*request, new\s+Template\(.*getParameter|new\s+StringReader\(.*getParameter, Velocity\.evaluate\(.*getParameter, SpelExpressionParser.*getParameter, templateEngine\.process\(.*getParameter, template\.(New|Must)\(.*\.Parse\(.*r\.URL\.Query\(\)|r\.FormValue, import\s+"text/template"  # 用于 HTML 场景 (非 html/template), ejs\.render\(`.*req\.|ejs\.render\(.*req\.(query|body), pug\.compile\(req\.|Handlebars\.compile\(req\., nunjucks\.renderString\(.*req\.]
exclude_patterns: []
---

## 威胁定义 (Threat Definition)

检测模板引擎是否将用户输入作为模板内容渲染，攻击者可注入模板语法在服务端执行任意代码（RCE）。

## 检测逻辑 (Detection Logic)

### Step 1: Python — Jinja2/Mako/Django

```python
# BAD: Flask render_template_string 用户输入
@app.route('/hello')
def hello():
    name = request.args.get('name')
    return render_template_string(f'<h1>Hello {name}!</h1>')
    # 攻击: ?name={{config}} → 读取 Flask 配置
    # 攻击: ?name={{''.__class__.__mro__[1].__subclasses__()}} → RCE

# BAD: Jinja2 Template 编译用户输入
from jinja2 import Template
template = Template(request.args.get('template'))  # 用户输入作为模板!
return template.render()

# BAD: Mako 模板注入
from mako.template import Template
return Template(user_input).render()

# BAD: Django 模板动态编译
from django.template import Template
t = Template(user_input)
return t.render(context)

# BAD: string.Template (较弱但信息泄露)
from string import Template
t = Template(user_input)
return t.substitute(name='World')
```

**Python 安全模式:**
```python
# GOOD: 用户输入作为变量（非模板）
@app.route('/hello')
def hello():
    name = request.args.get('name')
    return render_template('hello.html', name=name)  # name 是模板变量
```

### Step 2: Java — Freemarker/Velocity/SpEL

```java
// BAD: Freemarker Template 编译用户输入
String template = request.getParameter("template");
Template t = new Template("user", new StringReader(template), cfg);
t.process(data, writer);

// BAD: Velocity evaluate 用户输入
VelocityContext ctx = new VelocityContext();
StringWriter writer = new StringWriter();
Velocity.evaluate(ctx, writer, "log", request.getParameter("input"));

// BAD: SpEL 表达式注入
ExpressionParser parser = new SpelExpressionParser();
String expression = request.getParameter("expr");
parser.parseExpression(expression).getValue();  // RCE!

// BAD: Thymeleaf 模板名可控
templateEngine.process(userTemplateName, ctx, writer);
```

**Java 安全模式:**
```java
// GOOD: 静态模板文件
ModelAndView mav = new ModelAndView("user/profile");  // 静态模板名
mav.addObject("name", request.getParameter("name"));  // 仅变量
```

### Step 3: Go — html/template + text/template

```go
// BAD: template.Parse 用户输入
func handler(w http.ResponseWriter, r *http.Request) {
    userTpl := r.URL.Query().Get("template")
    t, _ := template.New("page").Parse(userTpl)  // 用户输入作模板!
    t.Execute(w, data)
}

// BAD: 模板文件路径可控
t, _ := template.ParseFiles(r.URL.Query().Get("template"))

// BAD: text/template 生成 HTML（无自动转义）
import "text/template"  // 非 html/template!
t.Execute(w, data)      // XSS + SSTI 双重风险
```

**Go 安全模式:**
```go
// GOOD: 静态模板 + html/template
import "html/template"
t, _ := template.ParseFiles("templates/page.html")
t.Execute(w, data)
```

### Step 4: JavaScript — EJS/Pug/Handlebars

```javascript
// BAD: EJS 模板注入
app.get('/hello', (req, res) => {
    const html = ejs.render(`<h1>Hello ${req.query.name}</h1>`);
    res.send(html);
    // 攻击: ?name=<%= process.mainModule.require('child_process').execSync('id') %>
});

// BAD: Pug compile 用户输入
const fn = pug.compile(req.body.template);
res.send(fn());

// BAD: Handlebars 动态模板
const template = Handlebars.compile(req.body.template);
res.send(template(data));

// BAD: Nunjucks
nunjucks.renderString(userInput, data);
```

**JavaScript 安全模式:**
```javascript
// GOOD: 静态模板文件
app.get('/hello', (req, res) => {
    res.render('hello', { name: req.query.name });  // 变量渲染
});
```

## 修复指引 (Remediation Guide)

1. **首选**：模板内容使用静态文件，用户输入仅作为模板变量传入
2. **次选**：使用沙箱化模板引擎（Jinja2 SandboxedEnvironment / Freemarker SAFER resolver）
3. **禁止**：`render_template_string(userInput)` / `Template(userInput)` / `ejs.render(userInput)` 直接渲染用户输入
4. **HTML 编码**：所有变量输出默认 HTML 编码

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `render_template("page.html", user=name)` | 静态模板 + 变量 | 确认第一个参数为静态文件名/路径，非用户输入 |
| `Template("internal_template_str")` 不含外部输入 | 硬编码内部模板 | 确认模板字符串为代码中的字符串字面量，非来自 request/用户输入 |
| Jinja2 `SandboxedEnvironment` | 沙箱限制 | 确认使用了 `SandboxedEnvironment` 且禁用了危险属性和函数 |
| 模板内容来自数据库白名单（非用户直接输入） | 间接但安全 | 确认模板内容从服务端白名单中查找，非用户直接提交 |
| 模板引擎默认自动转义（html/template）且仅用于 HTML | 仅 XSS 风险，非 SSTI | 确认使用 `html/template`（Go）且模板本身为静态文件 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Python: 用户输入作模板
render_template_string\(.*request\.(args|form|data|json)
Template\(request\.(args|form|data)\['\w+'\]
mako\.template\.Template\(.*request\.
from\s+string\s+import\s+Template.*Template\(.*request
→ MUST: code_context (模板调用及用户输入来源的完整代码)
→ MUST: judgment_rationale (用户输入是否直接作为模板内容 vs 模板变量，是否有沙箱保护)

# Java: 模板引擎编译用户输入
new\s+Template\(.*getParameter|new\s+StringReader\(.*getParameter
Velocity\.evaluate\(.*getParameter
SpelExpressionParser.*getParameter
templateEngine\.process\(.*getParameter

# Go: Parse 用户输入
template\.(New|Must)\(.*\.Parse\(.*r\.URL\.Query\(\)|r\.FormValue
import\s+"text/template"  # 用于 HTML 场景 (非 html/template)

# JS: 模板引擎渲染用户输入
ejs\.render\(`.*req\.|ejs\.render\(.*req\.(query|body)
pug\.compile\(req\.|Handlebars\.compile\(req\.
nunjucks\.renderString\(.*req\.

# === EXCLUDE (不报告) ===

→ render_template\("[^"]+\.html|render_template\('[^']+\.html        # 静态模板文件
→ render\(['"][\w/]+['"]                                              # Express/Jinja2 静态模板
→ SandboxedEnvironment|SAFER_RESOLVER|RestrictedResolver              # 沙箱化模板引擎
→ Template\("[^"]*"\)|Template\('[^']*'\)                            # 硬编码内部模板字符串
→ import "html/template"                                              # Go 自动转义模板
→ templates\.(get|load|find)\(|template_name.*=.*['"]                 # 从服务端白名单加载
```
