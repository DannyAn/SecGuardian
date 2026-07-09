# SSTI — 误报抑制策略 (Go)

适用于 `go.injection.ssti` skill（CWE-1336）。

## 策略 1: 模板来源确认

**检查清单:**
- [ ] `template.Parse` 的参数是字符串常量？
- [ ] `template.ParseFiles` 的文件路径是常量？
- [ ] 模板内容是硬编码还是来自用户/数据库？

```go
// 硬编码 — 安全
template.New("t").Parse("<h1>{{.Title}}</h1>")

// 用户输入 — 危险
template.New("t").Parse(userInput)
```

## 策略 2: 数据 vs 模板区分

```go
// 以下安全（数据渲染）
tmpl, _ := template.New("t").Parse("<h1>{{.}}</h1>")
tmpl.Execute(w, userInput)      // userInput 是数据，不是模板

// 以下危险（用户输入作为模板）
tmpl, _ := template.New("t").Parse(userInput)  // 用户输入是模板
tmpl.Execute(w, data)
```

## 策略 3: embed.FS 或 bindata 确认

使用 Go 1.16 `embed.FS` 或 `go-bindata` 打包的静态模板不受影响。

## 策略 4: 测试文件抑制
