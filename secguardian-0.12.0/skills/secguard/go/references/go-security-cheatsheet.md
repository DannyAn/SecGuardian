# Go 安全速查表

SecGuard 快速参考：Go 标准库陷阱和并发安全速查。

## Top 10 检测信号

| # | 检测信号 | 严重度 | 关联概念 |
|---|---------|--------|---------|
| 1 | `exec.Command("sh", "-c", userInput)` | Critical | command-injection |
| 2 | `db.Query(fmt.Sprintf(...))` | Critical | sql-injection |
| 3 | `template.Parse(userTpl)` | Critical | ssti |
| 4 | `text/template` 用于 HTML 输出 | High | xss |
| 5 | `math/rand` 安全用途 | High | weak-cryptography |
| 6 | `crypto/md5` 安全用途 | High | weak-cryptography |
| 7 | `http.Get(userURL)` 未验证 | High | ssrf |
| 8 | `os.Open(filepath.Join(base, userPath))` 未 Clean | High | path-traversal |
| 9 | map 并发读写无锁 | Medium | data-race |
| 10 | `defer` 在循环中 | Medium | resource-leak |

## Go 安全模式

### 模板安全
```
text/template  → 用于纯文本（不编码 HTML）
html/template  → 用于 HTML（自动上下文编码） ← 默认首选
```

### 加密安全
```
crypto/rand  → 安全随机数  ← 用这个
math/rand    → 非安全伪随机 ← 禁止安全用途
```

### cgo 注意事项
- Go 指针传给 C 后 Go GC 可能移动对象
- C.free 与 Go GC 不兼容
- C 字符串在 Go 中需手动检查长度
