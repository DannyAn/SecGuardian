---
name: secguard-python-ssti
description: "检测服务端模板注入 — Jinja2 render_template_string / Mako Template 用户输入"
language: python
topic: [web, template, injection, ssti]
skill_id: python.ssti.jinja2
signal_filter: python.ssti.jinja2*
signal_source: call_sites[callee="render|render_template|Template|jinja2|mark_safe"]
severity: critical
cwe: CWE-1336
trigger_functions: [render_template_string, jinja2.Template, mako.template.Template, django.template.Template, string.Template]
---

# SSTI 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.ssti.jinja2` | `call_sites[cat="template"]` | `render_template_string`, `jinja2.Template`, `mako.template.Template` | Critical | CWE-1336 | `web-ssti` |

## Scenario 1: 模板内容用户可控

### 威胁定义
攻击者通过控制模板内容（而非仅模板变量）注入 Jinja2/Mako/Django 模板语法，沙箱绕过后可能导致 RCE。`__class__.__mro__.__subclasses__()` 链式访问是经典利用路径。

### 检测逻辑
```python
# BAD: Flask render_template_string 用户输入
@app.route('/hello')
def hello():
    name = request.args.get('name')
    return render_template_string(f'<h1>Hello {name}!</h1>')  # SSTI

# BAD: Jinja2 Template 编译用户输入
from jinja2 import Template
template = Template(request.args.get('template'))

# BAD: Mako 用户输入
from mako.template import Template
return Template(user_input).render()

# GOOD: render_template 静态文件 + 变量
return render_template('hello.html', name=name)
```

### 检测模式
- **MATCH**: `render_template_string\(.*request` | `Template\(.*request` | `mako\.template\.Template\(.*request` | `string\.Template\(.*request`
- **EXCLUDE**: `render_template\(` | `SandboxedEnvironment` | `template\.render\(\)$`（静态模板）

### 修复指引
1. 使用 `render_template("file.html", **vars)` 静态模板文件
2. 用户输入仅作为模板变量传递
3. Jinja2 `SandboxedEnvironment` 作为补偿控制

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 模板调用及用户输入来源 |
| judgment_rationale | MUST — 输入作模板内容 vs 模板变量 |
| sanitizer_analysis | MAY — 沙箱环境配置 |

## 输出格式

记录为 finding，标注 `severity: critical`，`cwe: CWE-1336`。
