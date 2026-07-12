---
name: secguard-go-ssti
description: "Detect server-side template injection via template.Parse with user input — template content from untrusted sources enables RCE"
language: go
topic: [web, template]
skill_id: go.injection.ssti
signal_filter: go.injection.ssti*
signal_source: call_sites[callee="Execute|ExecuteTemplate|Parse|ParseFiles|ParseGlob|New|Must"]
severity: critical
cwe: [CWE-1336]
trigger_functions: [template.New, template.Must, template.Parse, template.ParseFiles, template.ParseGlob]
---

# ssti 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.injection.ssti` |
| signal_filter | `go.injection.ssti*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `template.New().Parse()`, `template.Must()`, `template.ParseFiles()`, `template.ParseGlob()` |
| 默认严重度 | Critical |
| CWE | CWE-1336 (Server-Side Template Injection) |
| Guard-rule | `web-ssti` |

## Scenario 1: template.Parse 用户输入

### 威胁定义

Go 的 `text/template` 和 `html/template` 都支持动态模板编译。如果模板内容（而非变量）来自用户输入，攻击者可注入模板指令 `{{.}}` 读取数据结构、调用方法等。`text/template` 用于 HTML 输出时还存在 XSS 风险，因为不执行自动转义。

**核心原则：模板内容必须是静态文件或编译期常量，用户输入仅作为模板变量传入。**

### 检测逻辑

```go
// 脆弱 — 用户输入作为模板内容
userTpl := r.URL.Query().Get("tpl")
t, _ := template.New("page").Parse(userTpl)
t.Execute(w, data)

// 脆弱 — 模板文件路径可控
t, _ := template.ParseFiles(r.URL.Query().Get("file"))

// 脆弱 — text/template 用于 HTML 输出
import "text/template"
t, _ := template.ParseFiles("page.html")  // 无自动转义

// 安全 — 静态模板文件
import "html/template"
t, _ := template.ParseFiles("templates/page.html")
t.Execute(w, data)

// 安全 — 用户输入仅作为变量
t.Execute(w, map[string]interface{}{"name": userInput})
```

### 检测模式

```
# MATCH（触发检测）
→ template.New("").Parse(userInput) — 模板内容来自用户
→ template.ParseFiles(userPath) — 模板文件路径来自用户
→ template.ParseGlob(userPattern) — 模板模式来自用户
→ import "text/template" 用于 HTML 输出场景

# EXCLUDE（不报告）
→ template.Execute(w, data) 中 data 为变量（非模板内容）
→ html/template 的默认自动转义 HTML 输出（仅 XSS 风险）
→ 静态模板文件路径（编译期常量）
```

### 修复指引

1. 模板内容始终使用静态文件，不编译用户输入的模板字符串
2. HTML 输出始终使用 `html/template`（自动转义），避免 `text/template`
3. 用户输入仅作为 `Execute()` 的变量传入，不拼入模板字符串

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | template.Parse 调用点及模板来源标注 |
| judgment_rationale | MUST | 模板内容是否来自用户输入 vs 静态文件 |
| data_flow_path | SHOULD | 用户输入 → 模板编译 → 执行的完整路径 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
