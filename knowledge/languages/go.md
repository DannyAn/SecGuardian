---
category: language
languages: [go, golang]
frameworks: [net/http, gin, echo, gorm, sqlx, cgo]
---

# Go 语言安全画像

Go 的安全特性、标准库陷阱和常见反模式。

## 危险 API 清单

### 命令执行
| 模式 | 风险 | 替代 |
|------|------|------|
| `exec.Command("sh", "-c", userCmd)` | Shell 注入 | 直接 `exec.Command(cmd, args...)` 不经过 shell |
| `exec.Command(cmd, userInput)` args 可控 | 命令注入 | 注意 args 来自不受信源 |
| `os.Exec` 路径来自用户 | 路径劫持 | 绝对路径 + 验证 |

### SQL
| 模式 | 风险 | 替代 |
|------|------|------|
| `db.Query(fmt.Sprintf(...))` | SQL 注入 | `db.Query(query, args...)` 用 `$1, $2` |
| `db.Exec` + 字符串拼接 | SQL 注入 | 占位符参数化 |
| `sqlx.In` 动态列名 | SQL 注入 | 白名单校验 |
| GORM `Raw()` + 拼接 | SQL 注入 | GORM 链式调用 / 命名参数 |
| GORM `Order(userInput)` | SQL 注入 | 白名单校验 ORDER BY 字段 |

### 模板注入 (SSTI)
| 模式 | 风险 |
|------|------|
| `template.Must(template.New("").Parse(userTpl))` | SSTI — 用户可注入模板指令 |
| `html/template` 自动编码 HTML | 安全（默认） |
| `text/template` 用于 HTML 输出 | XSS 风险 — 不编码 |
| `template.HTML(userInput)` | XSS — 绕过编码 |

### 反序列化
| 模式 | 风险 | 替代 |
|------|------|------|
| `gob.NewDecoder(untrusted)` | 类型注入（有限） | JSON + Schema 验证 |
| `json.Unmarshal` → `interface{}` | 类型混淆 | 使用具体类型 |
| `xml.NewDecoder` 未配置 | XXE | Go XML 默认不支持外部实体（相对安全） |

### 路径穿越
| 模式 | 风险 | 替代 |
|------|------|------|
| `os.Open(filepath.Join(base, userPath))` | 路径穿越（如果 userPath 含 `..`） | `filepath.Clean` + 前缀验证 |
| `archive/zip` Reader 解压未验证 | Zip Slip | 验证每个 entry Name 的 Clean 路径 |
| `os.Chmod`/`os.Chown` 路径可控 | 权限修改错误文件 | 验证路径 |
| `ioutil.ReadFile(userPath)` | 任意文件读取 | 路径白名单 |

### 加密
| 禁止 | 推荐 |
|------|------|
| `crypto/md5` 安全用途 | `crypto/sha256` |
| `crypto/des` | `crypto/aes` (gcm 模式) |
| `math/rand` 安全用途 | `crypto/rand` |
| 自定义密码哈希 | `golang.org/x/crypto/bcrypt` / argon2 |

### 并发安全
| 模式 | 风险 |
|------|------|
| `map` 并发读写无锁 | 数据竞争 → panic |
| `defer` 在循环中 | 资源延迟释放（累计） |
| goroutine 泄露 | 无退出机制 / channel 未关闭 |
| `sync.Mutex` 复制 | 锁失效 |
| channel 未关闭导致死锁 | goroutine 泄漏 |

### 网络
| 模式 | 风险 | 替代 |
|------|------|------|
| `http.Get(userURL)` | SSRF | URL 验证 + 内网 IP 黑名单 |
| `http.ListenAndServe(":8080", nil)` | 默认 mux 全局 | 使用自定义 ServeMux |
| `httputil.ReverseProxy` 未验证 | Host 头注入/SSRF | 验证 `r.Host` + 限制目标 |
| CORS 全放通 `Access-Control-Allow-Origin: *` | 跨域攻击 | 限定特定 Origin |

### cgo 特有问题
| 模式 | 风险 |
|------|------|
| C 字符串未检查边界 | 缓冲区溢出（继承 C 问题） |
| C.free 与 Go GC 冲突 | Double Free / Use-After-Free |
| Go 指针传给 C 后 Go 对象被移动 | 悬空指针 |

## 框架特性

### Gin
- `c.HTML(code, tpl, data)` — Gin 默认不编码 HTML
- `ShouldBindJSON` 验证检查覆盖度
- 中间件顺序错误导致认证跳过

### GORM
- 链式调用安全，`Raw()` 危险
- `Find(&users, conditions)` 参数化（安全）
- `Pluck`/`Order`/`Group` 动态字段需白名单

### net/http
- `http.StripPrefix` + `http.FileServer` 可能暴露文件系统
- `r.URL.Path` Clean 不充分时存在路径穿越

## 检测优先级

1. `exec.Command("sh", "-c", userInput)` → Critical
2. `db.Query`/`db.Exec` + fmt.Sprintf → Critical
3. `text/template` 用于 HTML 输出 → High
4. `math/rand` 安全用途 → High
5. goroutine 泄露（defer 在循环中）→ Medium
6. cgo 内存问题 → Critical
