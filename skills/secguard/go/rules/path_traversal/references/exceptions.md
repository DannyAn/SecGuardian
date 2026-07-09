# Path Traversal — 例外规则 (Go)

适用于 `go.system.path-traversal` skill（CWE-22）。

## 例外 1: filepath.Clean + HasPrefix 校验

使用 `filepath.Clean` 规范化路径后，再用 `strings.HasPrefix` 校验基路径。

```go
// EXCEPTION: 路径校验后安全
baseDir := "/var/data/uploads/"
cleanPath := filepath.Clean(filepath.Join(baseDir, userInput))
if !strings.HasPrefix(cleanPath, baseDir) {
    return errors.New("path traversal detected")
}
f, err := os.Open(cleanPath)
```

## 例外 2: filepath.Abs 规范化

使用 `filepath.Abs` 规范化后校验，可防止 `../` 穿越。

```go
// EXCEPTION: Abs 规范化后校验
absPath, err := filepath.Abs(filepath.Join(base, userFile))
if err != nil { return err }
if !strings.HasPrefix(absPath, baseDir) {
    return errors.New("invalid path")
}
os.Open(absPath)
```

## 例外 3: 硬编码路径

路径为编译期常量，不来自用户输入。

```go
// EXCEPTION: 常量路径
os.Open("/etc/config/default.conf")
os.ReadFile("/usr/share/assets/logo.png")
os.Create("/tmp/cache-" + time.Now().Format("20060102") + ".dat")  // 时间戳拼接，非用户输入
```

## 例外 4: 仅文件名而非路径

用户输入仅为文件名（不含路径分隔符），且使用 `filepath.Base` 限制。

```go
// EXCEPTION: 仅文件名 + Base 限制
safeName := filepath.Base(userInput)  // 去掉所有路径部分
f, err := os.Open(filepath.Join(uploadDir, safeName))
```

## 例外 5: embed.FS / 打包资源

使用 Go 1.16+ `embed.FS` 嵌入的静态资源路径，不受用户控制。

```go
// EXCEPTION: embed 资源
//go:embed static/*
var staticFiles embed.FS
data, _ := staticFiles.ReadFile("static/" + filename)  // filename 不在 embed 中 → 报错而非遍历
```

## 例外 6: 测试代码

`_test.go` 完全抑制。
