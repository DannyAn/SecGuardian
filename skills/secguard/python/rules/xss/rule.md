---
name: secguard-python-xss
description: "检测 XSS — render_template_string vs render_template / mark_safe 用户输入"
language: python
topic: [web, injection, xss]
skill_id: python.xss.template
signal_filter: python.xss.template*
signal_source: call_sites[callee="render|render_template|mark_safe|Markup|escape"]
severity: medium
cwe: CWE-79
trigger_functions: [mark_safe, render_template_string, HttpResponse, JsonResponse, format_html, format_html_join, safer, escape]
---

# XSS 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.xss.template` | `call_sites[cat="template"]` | `mark_safe`, `render_template_string`, `\|safe` 过滤器 | Medium | CWE-79 | `web-xss` |

## Scenario 1: 用户输入未编码渲染到页面

### 威胁定义
用户输入经 `mark_safe()` 或 `|safe` 过滤器或 `render_template_string()` 直接输出到 HTML，绕过 Django/Jinja2 自动转义机制。涉及框架: Django templates、Jinja2、Flask。

### 检测逻辑
```python
# BAD: mark_safe 用户输入
from django.utils.safestring import mark_safe
return mark_safe(user_input)

# BAD: 模板中 |safe 过滤器
# template: {{ user_input|safe }}

# BAD: render_template_string 动态拼接
return render_template_string(f'<div>{user_input}</div>')

# BAD: HttpResponse 直接返回未编码 HTML
from django.http import HttpResponse
return HttpResponse(user_input)

# GOOD: Django 自动转义
return render(request, 'page.html', {'data': user_input})
# template: {{ data }} (无 |safe)

# GOOD: Flask Jinja2 自动转义
return render_template('page.html', data=user_input)

# GOOD: format_html 安全
from django.utils.html import format_html
return format_html('<b>{}</b>', user_input)  # 自动转义
```

### 检测模式
- **MATCH**: `mark_safe\(.*user\|input\|request` | `\|safe` | `render_template_string(.*user\|input)` | `HttpResponse\(.*user\|request`
- **EXCLUDE**: `format_html\(`（自动转义） | `render\(`（默认自动编码） | `JsonResponse` | `\|escape` 或 `\|force_escape`

### 修复指引
1. Django: 使用 `render()` 默认自动编码，避免 `|safe` 和 `mark_safe()`
2. 需富文本时使用 `bleach` / `nh3` 清洗
3. `format_html()` 自动转义参数
4. 配置 `Content-Security-Policy` 纵深防御

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 输出到 HTML 的代码 |
| judgment_rationale | MUST — 是否经过上下文编码 |
| sanitizer_analysis | MAY — 模板自动转义配置 / CSP 头 |

## 输出格式

记录为 finding，标注 `severity: medium`，`cwe: CWE-79`。
