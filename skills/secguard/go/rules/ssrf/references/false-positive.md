# SSRF — 误报抑制策略 (Go)

适用于 `go.web.ssrf` skill（CWE-918）。

## 策略 1: 域名白名单确认

**检查清单:**
- [ ] 代码中有域名/主机白名单
- [ ] 白名单不允许通配符（`*.example.com` 也需验证）
- [ ] 白名单不包含内网地址（`localhost`, `127.0.0.1`, `10.x`, `192.168.x`）

## 策略 2: URL 解析验证

```go
// 有 url.Parse 验证 — 确认验证是否充分
parsed, err := url.Parse(userURL)
if err != nil { return }
// 只有 Parse 不做 scheme/host 验证是不够的
```

## 策略 3: 私有 IP 检查

```go
func isPrivateIP(ip net.IP) bool {
    privateBlocks := []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8", "169.254.0.0/16"}
    for _, block := range privateBlocks {
        _, cidr, _ := net.ParseCIDR(block)
        if cidr.Contains(ip) { return true }
    }
    return false
}
```

## 策略 4: 固定 Host

如果 host 部分是硬编码的，仅路径来自用户，风险大幅降低。

## 策略 5: 测试文件抑制
