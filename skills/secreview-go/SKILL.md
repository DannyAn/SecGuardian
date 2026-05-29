---
name: secreview-go
description: 对 Go 代码进行通用安全规范检视，关注标准库安全和并发模式规范
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---


# secreview-go

对 Go 代码进行通用安全规范检视，关注标准库陷阱、并发安全和 Go 特有安全模式。


> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。检视时优先利用符号表定位目标，而非逐个文件遍历。
## 检视范围

### 语义层面
- SQL 查询是否使用了占位符（而非 fmt.Sprintf）
- 模板引擎选择是否正确（html/template vs text/template）
- 加密随机数是否使用了 crypto/rand
- HTTP 请求的 URL 是否来自可信源

### 规范合规
- `defer` 在循环中的使用是否合理
- error 处理是否返回了敏感信息
- goroutine 是否有明确的退出机制
- channel 关闭是否符合规范
- `sync.Mutex` 是否通过指针传递

### 反模式识别
- `interface{}` 滥用导致的类型安全丧失
- `init()` 中 panic 导致的不可控启动
- `net/http/pprof` 在生产环境暴露
- `cgo` 使用不合理导致的安全边界失效
- `reflect` 和 `unsafe` 包的非必要使用
- `iota` 在权限位中使用导致的重叠

## 与 secguard-go 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
