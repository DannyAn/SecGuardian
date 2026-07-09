# SSTI — 跨函数追踪 (Go)

适用于 `go.injection.ssti` skill（CWE-1336）。max depth 1。

## 场景一: 用户输入作为模板

```go
func renderHandler(w http.ResponseWriter, r *http.Request) {
    tmplStr := r.URL.Query().Get("template")    // Source: 用户模板
    renderTemplate(tmplStr, data)
}

func renderTemplate(t string, data interface{}) {
    tmpl, _ := template.New("page").Parse(t)    // Sink: 模板注入
    tmpl.Execute(w, data)
}
```

## 场景二: 数据库存储的模板

```go
func showPage(w http.ResponseWriter, r *http.Request) {
    pageID := r.URL.Query().Get("id")
    tmplStr := getTemplateFromDB(pageID)         // Source: 数据库中的模板
    tmpl, _ := template.New("page").Parse(tmplStr) // Sink
    tmpl.Execute(w, nil)
}
```

## 深度限制

- max depth 1: 追踪模板内容的来源
- `template.New().Parse()` 和 `template.Must(template.New().Parse())` 均为 Sink
- 从数据库/文件/用户输入 → `template.Parse` 的路径都需追踪
