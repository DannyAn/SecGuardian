---
detector: review.go
type: review-rule
language: go
max_severity: Critical
cwe: CWE-000
anti_pattern_count: 14
---

# Go 安全反模式检测矩阵

代码审查中需要关注的 Go 特有安全反模式及具体检测规则。

## 错误处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `err != nil` 后继续使用返回值 | `if err != nil` 块内无 `return` 且后续使用函数返回值 | Critical |
| `panic` 在库代码中 | `func\s+\w+\w+\([^)]*\).*\{[^}]*\bpanic\(` 在非 main 包 | High |
| `recover()` 吞掉所有 panic | `recover\(\)[^}]*` 无 `log.Printf` 或错误分类 | Medium |
| `log.Fatal` 在库代码中 | `log\.Fatal[fl]?\(` 在非 main/main_test 包 | Medium |

## 并发反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| goroutine 无退出机制 | `go func\([^)]*\)\s*\{[^}]*\}` 无 `context.Context` 或 `done` channel | High |
| `map` 并发读写 | `map\[string\]\w+` 全局/共享且无 `sync.Mutex\|sync.RWMutex\|sync.Map` | Critical |
| `sync.Mutex` 值复制 | `func.*\([^)]*\w+\s+sync\.Mutex\)` — Mutex 按值传递 | Critical |
| `WaitGroup.Add()` 在 goroutine 内 | `go func.*\{[^}]*wg\.Add\(` — Add 在 goroutine 内 | Medium |

## 接口/类型反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 类型断言不检查 ok | `\.\((\w+)\)$` 而非 `, ok :=` 模式（单返回值断言） | Medium |
| `unsafe` 包使用 | `import\s+\"unsafe\"` 或 `unsafe\.(Pointer\|Sizeof\|Offsetof)` | Medium |
| `reflect` 绕过类型安全 | `reflect\.(ValueOf\|TypeOf)[^)]*\.(Interface\|Set\|Field)` | Medium |

## 网络/HTTP 反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `DefaultServeMux` 全局 | `http\.Handle\(` 或 `http\.HandleFunc\(` 非自定义 mux | Medium |
| pprof 生产暴露 | `import\s+_\s+\"net/http/pprof\"` 生产环境 | High |
| `InsecureSkipVerify: true` | `tls\.Config\{[^}]*InsecureSkipVerify\s*:\s*true` | High |
| ResponseWriter goroutine 并发写 | `go func[^)]*{[^}]*w\.(Write\|Header)` | Critical |

## 加密反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `crypto/md5` 安全用途 | `md5\.(New\|Sum)\(` 且上下文含 `pass\|auth\|sign\|token` | High |
| `math/rand` 安全用途 | `rand\.(Int\|Float\|Read\|Perm)\(` 且上下文含 `token\|key\|session\|csrf` | High |
| 硬编码密钥 | `var\s+\w*(Key\|Secret\|Token\|Password)\w*\s*=\s*["']` | High |
| AES-ECB 手动实现 | `cipher\.NewCBCEncrypter\|des\.NewCipher` 循环逐块加密 | High |

## HTTP 错误处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| panic 写入 HTTP 响应 | `recover.*fmt\.Fprintf\(w\|recover.*w\.Write\(` | High |
| error 详情返回到 HTTP | `fmt\.Fprintf\(w.*err\.Error\(\)\|http\.Error\(w,\s*err\.Error\(\)` | High |
| `text/template` 生成 HTML | `import "text/template"` 且输出到 HTTP ResponseWriter | Medium |
| Gin DebugMode 生产 | `gin\.SetMode\(gin\.DebugMode\)` 非 debug/setup 环境 | Medium |
