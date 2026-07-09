# Go 语言特性参考

## 命令执行
| 模式 | 风险 | 替代 |
|------|------|------|
| `exec.Command("sh", "-c", userCmd)` | Shell 注入 | 直接 `exec.Command(cmd, args...)` 不经过 shell |
| `exec.Command(cmd, userInput)` args 可控 | 命令注入 | 注意 args 来自不受信源 |
| `os.Exec` 路径来自用户 | 路径劫持 | 绝对路径 + 验证 |

## SQL 注入
| 模式 | 风险 | 替代 |
|------|------|------|
| `db.Query(fmt.Sprintf(...))` | SQL 注入 | `db.Query(query, args...)` 用 `$1, $2` |
| `db.Exec` + 字符串拼接 | SQL 注入 | 占位符参数化 |
| `sqlx.In` 动态列名 | SQL 注入 | 白名单校验 |
| GORM `Raw()` + 拼接 | SQL 注入 | GORM 链式调用 / 命名参数 |
| GORM `Order(userInput)` | SQL 注入 | 白名单校验 ORDER BY 字段 |

## SSTI (模板注入)
| 模式 | 风险 |
|------|------|
| `template.Must(template.New("").Parse(userTpl))` | SSTI — 用户可注入模板指令 |
| `html/template` 自动编码 HTML | 安全（默认） |
| `text/template` 用于 HTML 输出 | XSS 风险 — 不编码 |
| `template.HTML(userInput)` | XSS — 绕过编码 |

## 反序列化
| 模式 | 风险 | 替代 |
|------|------|------|
| `gob.NewDecoder(untrusted)` | 类型注入（有限） | JSON + Schema 验证 |
| `json.Unmarshal` → `interface{}` | 类型混淆 | 使用具体类型 |

## 路径穿越
| 模式 | 风险 | 替代 |
|------|------|------|
| `os.Open(filepath.Join(base, userPath))` | 路径穿越（如果 userPath 含 `..`） | `filepath.Clean` + 前缀验证 |
| `archive/zip` Reader 解压未验证 | Zip Slip | 验证每个 entry Name 的 Clean 路径 |

## 加密安全
| 禁止 | 推荐 |
|------|------|
| `crypto/md5` 安全用途 | `crypto/sha256` |
| `crypto/des` | `crypto/aes` (gcm 模式) |
| `math/rand` 安全用途 | `crypto/rand` |
| 自定义密码哈希 | `golang.org/x/crypto/bcrypt` / argon2 |

## 并发安全
| 模式 | 风险 |
|------|------|
| `map` 并发读写无锁 | 数据竞争 → panic |
| goroutine 泄露 | 无退出机制 / channel 未关闭 |
| `sync.Mutex` 复制 | 锁失效 |

## cgo 特有问题
| 模式 | 风险 |
|------|------|
| C 字符串未检查边界 | 缓冲区溢出（继承 C 问题） |
| C.free 与 Go GC 冲突 | Double Free / Use-After-Free |

## 框架注意
- Gin: `c.HTML(code, tpl, data)` 默认不编码 HTML；`ShouldBindJSON` 验证检查覆盖度
- GORM: 链式调用安全，`Raw()` 危险；`Find(&users, conditions)` 参数化（安全）
- net/http: `http.StripPrefix` + `http.FileServer` 可能暴露文件系统
