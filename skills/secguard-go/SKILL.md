---
name: secguard-go
description: 对 Go 代码进行安全加固项排查，检测标准库陷阱和并发安全问题
category: language-specific
language: go
---


# secguard-go

对 Go 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 执行流程

1. 加载 `knowledge/languages/go.md` 获取 Go 危险 API 清单和并发陷阱
2. 加载各 `knowledge/concepts/*.md` 获取安全概念和检测逻辑
3. 扫描目标代码，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | 命令注入 | exec.Command("sh", "-c", userInput) |
| Critical | SQL 注入 | db.Query/Exec + fmt.Sprintf / GORM Raw() |
| Critical | SSTI | template.Parse(userTpl) / text/template 生成 HTML |
| Critical | cgo 内存 | C 被调用方的缓冲区溢出 / Double Free |
| High | 路径穿越 | os.Open + filepath.Join 未 Clean / Zip Slip |
| High | SSRF | http.Get(userURL) / ReverseProxy 未限制 |
| High | 弱加密 | crypto/md5 安全用途 / math/rand 安全用途 |
| High | 硬编码密钥 | API Key / Password / JWT Secret 硬编码 |
| Medium | 并发安全 | map 并发读写 / goroutine 泄露 / Mutex 复制 |
| Medium | 信息泄露 | panic 信息返回客户端 / debug/pprof 暴露 |

### 框架覆盖
- net/http (标准库)
- Gin, Echo, Fiber
- GORM, sqlx
- html/template, text/template
- cgo (C 互操作安全)
