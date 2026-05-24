---
category: concept
threat_type: injection
severity: high
cwe: CWE-79
owasp: A03:2021 - Injection
---

# 跨站脚本 (XSS)

攻击者将恶意脚本注入到 Web 页面中，当其他用户访问时，脚本在浏览器中执行，窃取会话、重定向、篡改页面。

## 检测策略

### 核心原则
**所有输出到 HTML 页面的动态内容必须经过上下文感知的编码。**

1. **反射型 XSS**
   - 用户输入直接回显在响应中（搜索框、错误信息）
   - HTTP Referer、User-Agent 等请求头回显

2. **存储型 XSS**
   - 用户提交内容被存储后未经编码直接展示
   - 富文本输入未经过安全清洗

3. **DOM 型 XSS**
   - innerHTML、document.write 包含用户可控数据
   - 前端路由参数直接操作 DOM
   - jQuery 的 `$()` 和 `.html()` 不安全使用

### 误报排除
- 使用框架的安全模板引擎自动编码
- 显式使用编码函数（如 html/template 而非 text/template）
- 经过安全清洗的富文本（DOMPurify 等）

## 修复指引

1. **首选**：使用模板引擎的自动上下文编码
2. **次选**：手动选择正确编码函数（HTML/JS/URL/CSS 编码）
3. **富文本**：使用专用清洗库（DOMPurify、OWASP AntiSamy）
