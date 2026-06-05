---
name: go
description: 对 Go 代码进行通用安全规范检视，关注标准库安全和并发模式规范。当用户请求Go代码规范检视、Go反模式识别、Go并发安全规范、Go标准库最佳实践时使用。
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---

# 安全规范检视 — Go

对 Go 代码进行通用安全规范检视，关注标准库陷阱、并发安全和 Go 特有安全模式。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 执行流程

### Phase 1: 加载上下文

1. 读取 `index.json`，获取 `files`、`symbols.functions`、`call_graph.edges`
2. 加载 `knowledge/languages/go.md` 获取 Go 危险 API 清单

### Phase 2: 语义层面检视

| # | 检查项 | 检测方法 | 示例：不合规 |
|---|--------|---------|-------------|
| 1 | SQL 占位符 | 搜索 `fmt.Sprintf` + `db.Query`/`db.Exec` 组合 | `db.Query(fmt.Sprintf("SELECT * FROM users WHERE id=%s", id))` → 应使用 `db.Query("SELECT ... WHERE id=$1", id)` |
| 2 | 模板引擎选择 | 搜索 `text/template` import → 是否用于生成 HTML | `import "text/template"` + HTML 输出 → 应使用 `html/template` |
| 3 | 加密随机数 | 搜索 `math/rand` → 是否用于安全场景（token/key/session） | `rand.Intn(999999)` 验证码 → 应使用 `crypto/rand` |
| 4 | HTTP URL 安全 | 搜索 `http.Get`/`http.Post` → URL 是否包含用户输入未校验 | `http.Get(userProvidedURL)` → 应校验 URL scheme/host |

### Phase 3: 规范合规检视

| # | 检查项 | 检测方法 | 修复指引 |
|---|--------|---------|---------|
| 1 | defer in loop | 搜索 `for` + 内部 `defer` → 资源是否在循环结束才释放 | 将循环体提取为独立函数，或手动 close |
| 2 | error 信息泄露 | 搜索 `log.Print(err)`/`fmt.Println(err)` → HTTP response 是否包含内部错误 | 对客户端返回通用错误信息，内部日志记录详情 |
| 3 | goroutine 生命周期 | 搜索 `go func` → 是否有 context 取消/done channel 退出机制 | 每个 goroutine 必须 select on `ctx.Done()` 或 done channel |
| 4 | channel 关闭 | 搜索 `close(` → 发送方是否唯一关闭者 | 仅发送方关闭 channel，接收方不 close |
| 5 | Mutex 值拷贝 | 搜索 `sync.Mutex` → struct 传递是否使用指针 | `sync.Mutex` 必须通过指针传递，禁止值拷贝 |
| 6 | net/http/pprof 暴露 | 搜索 `import _ "net/http/pprof"` → 是否绑定到公开端口 | pprof 仅绑定 localhost 或通过内部端口 + 认证访问 |

### Phase 4: 反模式识别

| # | 反模式 | 检测特征 | 修复方案 |
|---|--------|---------|---------|
| 1 | interface{} 滥用 | 函数签名中频繁 `interface{}` 参数 | 定义具体 interface 类型，或使用泛型 (Go 1.18+) |
| 2 | init() 中 panic | `func init()` 内含 `panic()` 或 `log.Fatal()` | 将可能失败的初始化移至 `main()` 并显式处理 error |
| 3 | cgo 不当使用 | C 代码中指针未校验、Go/C 边界内存传递 | 遵循 cgo 指针传递规则，Go 侧做边界检查 |
| 4 | reflect/unsafe 滥用 | 非序列化框架使用 `reflect`，普通代码使用 `unsafe` | 优先类型安全方案，`unsafe` 需详细注释说明必要性 |
| 5 | iota 权限位重叠 | `iota` 定义权限常量未使用 `1 << iota` | 权限位使用 `1 << iota` 确保唯一性 |

### Phase 5: 输出

遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)：`report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json`。

## 与 secguard-go 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
| 覆盖 | CWE Top 25 + 检测器 | Go 安全指南 + OWASP 最佳实践 |

## 输出完整性要求

> **输出协议**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。
>
> Command 层 Step 4b 质量门禁强制检查每个检出的四段式完整性：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 违规代码行
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（指出违反的安全编码规范条款）
> 3. **⚠️ Impact** — 不合规可能导致的安全风险 + 适用攻击场景
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + SEI CERT/OWASP 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注关联代码位置，`fixes` 包含 before/after 替换。
