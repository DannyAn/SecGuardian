---
detector: xss
severity: critical
cwe: CWE-79
cvss: 9.8
language: [java, python, go]
tags: [web, injection, xss]
precision: high
confidence: dynamic
target_functions: [addAttribute, default, forHtml, getUserInput, getWriter, mark_safe, render, render_template, render_template_string, variables, write]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

攻击者将恶意脚本注入到 Web 页面中，当其他用户访问时，脚本在浏览器中执行，窃取会话、重定向、篡改页面。

**核心原则：所有输出到 HTML 页面的动态内容必须经过上下文感知的编码。** 涵盖反射型 XSS（用户输入回显）、存储型 XSS（富文本未清洗）、DOM 型 XSS（innerHTML/document.write 可控）。

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. **首选**：使用模板引擎的自动上下文编码（html/template 而非 text/template）
2. **次选**：手动选择正确编码函数（HTML/JS/URL/CSS 编码）
3. **富文本**：使用专用清洗库（DOMPurify、OWASP AntiSamy）
4. **CSP**：配置 Content-Security-Policy 作为纵深防御

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：用户输入输出到HTML/JS的代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：输出是否经过上下文感知编码
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入→服务端处理→响应输出的完整路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：控制器/处理器到模板渲染的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：输出编码函数调用/模板引擎配置/CSP头设置
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：模板引擎是否启用自动转义
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|----------|--------|--------|
| Django/Jinja2 auto-escaping enabled | Template engine encodes the output | 确认模板引擎配置中自动转义已启用，且未使用 `\|safe` 过滤器或 `mark_safe()` |
| Spring Thymeleaf | Auto-escaped by default | 确认使用 th:text 而非 th:utext，且未显式禁用转义 |
| html/template (Go) | Context-aware encoding | 确认使用的是 `html/template` 包而非 `text/template`，且未使用 `template.HTML` 类型绕过转义 |
| Content-Type: application/json | JSON response, not HTML | 确认响应的 Content-Type 头为 application/json 且内容不会嵌入 HTML 上下文 |
| Explicit encoding function called | Already sanitized | 确认在输出点调用了 OWASP Encoder / html.escape / 等效的上下文感知编码函数 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# Java: Response write with user input → evidence: code_context
response\.getWriter\(\)\.write\(.*user|input|param|request

# Java: @ResponseBody returning raw user input → evidence: code_context
@ResponseBody.*\n.*return\s+.*(?:user|input|param|request)

# Python: Template unsafe rendering → evidence: code_context
render_template_string\(.*user|render\(.*\|safe\)

# Python: mark_safe with user input → evidence: code_context
mark_safe\(.*(?:user|input|param|request)

# Go: text/template for HTML → evidence: code_context
text/template.*Parse\(.*user|template\.HTML.*user
```

### 排除模式 (EXCLUDE)

```
# Django/Jinja2 auto-escape (no |safe filter) → evidence: sanitizer_analysis
render\([^)]*\)\s*$  # 仅当模板中无 |safe 且未使用 mark_safe

# Spring Thymeleaf auto-escape → evidence: sanitizer_analysis
th:text=|\$\{.*\}  # Thymeleaf 默认转义

# html/template without template.HTML cast → evidence: sanitizer_analysis
html/template.*Parse\(  # Go 标准 HTML 模板自动上下文编码

# OWASP Encoder / explicit encoding → evidence: sanitizer_analysis
Encode\.forHtml|Encode\.forJavaScript|html\.escape|escapeHtml

# JSON Content-Type response → evidence: code_context
Content-Type:\s*application/json  # 非 HTML 上下文，无 XSS 风险
```
