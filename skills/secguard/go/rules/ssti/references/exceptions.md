# SSTI — 例外规则 (Go)

适用于 `go.injection.ssti` skill（CWE-1336）。

## 例外 1: 硬编码模板字符串

```go
// EXCEPTION: 硬编码模板
tmpl, _ := template.New("greeting").Parse("Hello, {{.Name}}!")
tmpl.Execute(w, data)
```

## 例外 2: 从常量文件加载的模板

```go
// EXCEPTION: 常量模板文件
tmpl, _ := template.ParseFiles("templates/index.html")
tmpl, _ := template.ParseGlob("templates/*.html")
```

## 例外 3: embed.FS 嵌入模板

```go
// EXCEPTION: embed 嵌入
//go:embed templates/*
var tmplFS embed.FS
tmpl, _ := template.ParseFS(tmplFS, "templates/*.html")
```

## 例外 4: 用户输入为模板数据（非模板代码）

```go
// EXCEPTION: 用户输入是数据，不是模板
tmpl.Execute(w, userInput)              // userInput 作为 . 的值渲染，不解析为模板指令
```

## 例外 5: text/template（相比 html/template）

`text/template` 不会自动转义 HTML，但模板注入风险相同 — 均允许执行模板函数。

```go
// text/template 和 html/template 都受影响
tmpl, _ := template.New("t").Parse(userInput)  // 无论哪种都危险
```

## 例外 6: 测试代码

`_test.go` 完全抑制。
