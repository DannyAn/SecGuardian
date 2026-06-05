---
detector: xss
severity: critical
cwe: CWE-79
language: [java, python, go]
tags: [web, injection, xss]
---

# Cross-Site Scripting (XSS)

## 威胁定义

攻击者将恶意脚本注入到 Web 页面中，当其他用户访问时，脚本在浏览器中执行，窃取会话、重定向、篡改页面。

**核心原则：所有输出到 HTML 页面的动态内容必须经过上下文感知的编码。** 涵盖反射型 XSS（用户输入回显）、存储型 XSS（富文本未清洗）、DOM 型 XSS（innerHTML/document.write 可控）。

## Detection Logic

### Step 1: Search for dangerous output patterns

**Java:**
```java
// BAD: direct concatenation into response
response.getWriter().write("<div>" + userInput + "</div>");

// BAD: unencoded template variables (if template doesn't auto-escape)
model.addAttribute("name", userInput);

// BAD: returning user input from controller
@ResponseBody
public String getUserInput(@RequestParam String data) {
    return data;  // XSS if returned as text/html
}
```

**Python:**
```python
# BAD: Django template with safe filter
render(request, 'template.html', {'data': user_input})
# In template: {{ data|safe }}

# BAD: Flask render_template_string with user input
render_template_string(user_input + "{{name}}")

# BAD: mark_safe with user input
return mark_safe(user_input)
```

**Go:**
```go
// BAD: text/template used for HTML output
text/template.Must(text/template.New("page").Parse(userInput))

// BAD: html/template with template.HTML type cast
tmpl.Execute(w, template.HTML(userInput))
```

### Step 2: Safe alternatives

```java
// GOOD: Spring auto-escapes by default in Thymeleaf/JSP
// GOOD: OWASP Java Encoder
import org.owasp.encoder.Encode;
response.getWriter().write(Encode.forHtml(userInput));
```

```python
# GOOD: Django auto-escapes by default (no |safe)
# GOOD: Flask Jinja2 auto-escapes by default
return render_template('page.html', data=user_input)
```

```go
// GOOD: html/template auto-escapes by default
html/template.Must(html/template.New("page").Parse(templateStr))
```

## 修复指引

1. **首选**：使用模板引擎的自动上下文编码（html/template 而非 text/template）
2. **次选**：手动选择正确编码函数（HTML/JS/URL/CSS 编码）
3. **富文本**：使用专用清洗库（DOMPurify、OWASP AntiSamy）
4. **CSP**：配置 Content-Security-Policy 作为纵深防御

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| Django/Jinja2 auto-escaping enabled | Template engine encodes the output |
| Spring Thymeleaf | Auto-escaped by default |
| html/template (Go) | Context-aware encoding |
| Content-Type: application/json | JSON response, not HTML |
| Explicit encoding function called | Already sanitized |

## Detection Pattern Summary

```
# Java: Response write with user input
response\.getWriter\(\)\.write\(.*user|input|param|request

# Python: Template unsafe rendering
render_template_string\(.*user|render\(.*\|safe\)

# Go: text/template for HTML
text/template.*Parse\(.*user|template\.HTML.*user
```
