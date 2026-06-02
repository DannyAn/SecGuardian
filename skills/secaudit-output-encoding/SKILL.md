---
name: secaudit-output-encoding
description: 审计输出数据的上下文感知编码处理，检测因编码缺失或不匹配导致的 XSS、注入和跨上下文攻击。当用户请求输出编码审计、XSS防护检测、模板引擎安全、上下文编码审查、响应头注入检测时使用。
category: domain
topic: [web]
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

# 输出编码安全审计

## 审计概览

输出编码是防御 XSS 的最后一道防线。即使输入验证失效，正确的输出编码仍能阻止恶意脚本执行。审计覆盖：
- **HTML 上下文编码**：HTML 体、属性、URL、CSS、JS
- **响应头编码**：防止 HTTP 响应拆分
- **模板引擎安全**：自动编码 vs 手动编码
- **错误信息编码**：错误的上下文编码导致信息泄露

## 审计流程

### Phase 1: 输出点枚举

识别应用中所有动态内容输出点：

```
HTML 输出:
□ 模板引擎渲染 (JSP/Thymeleaf/Jinja2/Go template)
□ innerHTML / outerHTML 赋值
□ document.write / document.writeln
□ insertAdjacentHTML
□ React dangerouslySetInnerHTML / Vue v-html

JS 输出:
□ 服务器端生成的 JS (动态 script 内容)
□ JSONP 回调
□ eval / new Function 参数

URL 输出:
□ href / src 属性
□ location.href 赋值
□ window.open 参数
□ 重定向 URL (Location header)

CSS 输出:
□ style 属性值
□ CSSStyleSheet.insertRule

响应头输出:
□ Set-Cookie 值
□ 自定义响应头
□ 重定向 URL (Location)
```

### Phase 2: 检查清单

#### 2.1 上下文编码正确性

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | HTML 体内容是否正确编码 | 检查是否使用了 `htmlspecialchars`/`html.escape`/`html/template` |
| [H] | HTML 属性值是否编码 | 属性需要属性值编码或引号 + HTML 编码 |
| [H] | JavaScript 上下文是否编码 | 检查是否错误使用了 HTML 编码处理 JS 数据 |
| [H] | URL 上下文是否编码 | 检查是否使用了 `encodeURIComponent` |
| [H] | CSS 上下文是否编码 | 检查动态 style 内容是否编码 |

**不同上下文的编码规则：**

| 上下文 | 危险字符 | 编码函数 |
|--------|---------|---------|
| HTML 体 | `< > & " '` | `htmlspecialchars` / `html.escape` |
| HTML 属性 (引号内) | `< > & "` | HTML 编码 + 属性值加引号 |
| HTML 属性 (无引号) | 空格和所有特殊字符 | 不要输出到无引号属性 |
| JavaScript (数据) | 取决于上下文 | `json_encode` + HTML 编码外层 |
| URL 参数 | `& = + % # ?` | `encodeURIComponent` |
| CSS | `< > & ' " ( ) ;` | CSS 编码 (`\HH `) |
| HTTP 响应头 | `\r \n` | 过滤换行符防响应拆分 |

#### 2.2 模板引擎安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 自动编码是否启用 | Go `html/template` vs `text/template` |
| [C] | 是否有绕过自动编码的标记 | `mark_safe`、`safe`、`{{{ }}}`、`noescape` 标记 |
| [H] | 模板引擎上下文是否正确 | 是否根据上下文选择编码策略 |
| [H] | 服务端渲染的 JSON 是否正确编码 | JSON 嵌入 HTML 时需要额外处理 |

```go
// BAD: text/template 不编码 HTML
import "text/template"
tpl.Execute(w, userContent)  // XSS!

// GOOD: html/template 自动上下文编码
import "html/template"
tpl.Execute(w, userContent)  // 安全
```

```django
{# BAD: mark_safe 跳过了自动编码 #}
{{ user_content|safe }}

{# GOOD: 默认自动编码 #}
{{ user_content }}
```

#### 2.3 嵌套上下文

嵌套上下文是最容易出错的地方：

```html
<!-- BAD: 多个上下文嵌套，编码不当 -->
<a href="javascript:show('{{ user_name }}')">
<!-- user_name 在: HTML属性 → URL → JS字符串 三层嵌套! -->

<!-- GOOD: 避免嵌套上下文，改用事件绑定 -->
<a id="user-link" data-name="{{ user_name | html_attr_encode }}">
<!-- JS: document.getElementById('user-link').dataset.name -->
```

```javascript
// BAD: JS 中拼接 HTML——JS 编码不是 HTML 编码!
element.innerHTML = '<div class="' + userClass + '">';
// 如果 userClass = '"><script>alert(1)</script><div class="'

// GOOD: 使用 DOM API 而非字符串拼接
var div = document.createElement('div');
div.className = userClass;  // 浏览器自动处理属性值编码
```

#### 2.4 响应头编码

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | Set-Cookie 值是否过滤了 CRLF | Cookie 值中的 `\r\n` 可导致响应拆分 |
| [H] | Location 头 URL 是否过滤了 CRLF | 重定向 URL 中的 `\r\n` 可注入额外的响应头 |
| [H] | 自定义响应头值是否过滤了 CRLF | 所有响应头值都应过滤换行 |

### Phase 3: 常见漏洞模式

```java
// BAD: 输出到 JS 上下文但使用了 HTML 编码
String username = request.getParameter("user");
String js = "var user = '" + HtmlUtils.htmlEscape(username) + "';";
// htmlEscape 不会转义 ' 和 \，在 JS 字符串中仍然危险

// GOOD: 使用 JSON 序列化输出到 JS
String js = "var user = " + new Gson().toJson(username) + ";";
```

### Phase 4: 输出格式

```markdown
## 输出编码审计报告

### 输出上下文枚举: 45 个动态输出点

| 类型 | 数量 | 风险点 |
|------|------|--------|
| HTML 模板 | 32 | 2个使用了 safe/mark_safe |
| innerHTML | 5 | 4个直接赋值用户数据 |
| JS 动态值 | 3 | 1个使用了 HTML 编码 |
| URL 拼接 | 3 | 2个未使用 URL 编码 |
| CSS 动态值 | 2 | 1个直接拼接用户输入 |
```
