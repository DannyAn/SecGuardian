# SSRF — 例外规则 (Go)

适用于 `go.web.ssrf` skill（CWE-918）。

## 例外 1: 域名白名单

```go
// EXCEPTION: 白名单校验后
var allowedHosts = map[string]bool{
    "api.example.com": true,
    "api.internal.com": true,
}
parsed, err := url.Parse(userURL)
if err != nil || !allowedHosts[parsed.Host] {
    return errors.New("host not allowed")
}
resp, err := http.Get(userURL)
```

## 例外 2: 硬编码 URL

```go
// EXCEPTION: 常量 URL
resp, _ := http.Get("https://api.example.com/v1/status")
resp, _ := http.Post("https://api.example.com/v1/data", "application/json", body)
```

## 例外 3: 私有 IP 检查

```go
// EXCEPTION: 主动检查私有 IP
parsed, _ := url.Parse(userURL)
ipAddrs, _ := net.LookupHost(parsed.Hostname())
for _, ip := range ipAddrs {
    if isPrivateIP(net.ParseIP(ip)) {
        return errors.New("private IP not allowed")
    }
}
resp, err := http.Get(userURL)
```

## 例外 4: URL 方案限制

```go
// EXCEPTION: 仅允许 HTTPS
parsed, _ := url.Parse(userURL)
if parsed.Scheme != "https" {
    return errors.New("only HTTPS allowed")
}
resp, _ := http.Get(userURL)
```

## 例外 5: 仅路径拼接（固定 host）

```go
// EXCEPTION: 固定 host，仅路径来自用户
resp, _ := http.Get("https://api.example.com/" + url.PathEscape(userPath))
```

## 例外 6: 测试代码

`_test.go` 完全抑制。
