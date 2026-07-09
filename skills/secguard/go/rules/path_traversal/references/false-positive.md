# Path Traversal — 误报抑制策略 (Go)

适用于 `go.system.path-traversal` skill（CWE-22）。

## 策略 1: filepath.Clean 确认

检查文件操作前是否调用了 `filepath.Clean` 去除 `../` 序列。

```go
// 有 Clean — 需要同时检查 HasPrefix 校验
cleanPath := filepath.Clean(userInput)  // "/../etc/passwd" → "/etc/passwd"
// 仅 Clean 不够! 还需要校验基路径
```

**检查清单:**
- [ ] 调用 `filepath.Clean` 或 `filepath.Abs`
- [ ] 调用 `strings.HasPrefix` 校验基路径
- [ ] 不是使用 `filepath.Join` 却未校验结果
- [ ] 文件名中 `..` 被正确处理

## 策略 2: filepath.Base 限制

如果用户输入经过 `filepath.Base` 处理（去除所有路径部分），可抑制。

```go
safeName := filepath.Base(userInput)
// userInput = "../../etc/passwd" → safeName = "passwd" (安全)
```

## 策略 3: 仅读不写

只读文件操作（`os.Open`, `os.ReadFile`）的严重度低于写操作（`os.Create`, `os.WriteFile`）。

## 策略 4: 路径白名单

如果文件路径在白名单中验证，可抑制。

```go
var allowedFiles = map[string]bool{
    "/var/www/report.pdf": true,
    "/var/www/manual.html": true,
}
```

## 策略 5: 嵌入式资源

使用 `embed.FS` 或 `go-bindata` 等嵌入式资源工具的函数，不受路径遍历影响。
