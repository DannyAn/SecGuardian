---
name: secguard-go
description: 对 Go 代码进行安全加固检视，覆盖 API 调用检测、并发语义分析、CGO 契约验证等多个维度。当用户请求Go安全扫描、Go代码审计、goroutine安全、Go标准库陷阱、Go加密安全时使用。
category: language-specific
language: go
topic: [web, concurrency, crypto, system]
---

# Go 安全加固排查 — 检视算子索引

本文件是 `skills/secguard/go/` 下 10 个检视算子 skill 的主索引 / 派发表。
每个算子对应 `rules/` 下的一个规则目录，包含自己的 `rule.md`。

> **执行流程由 `commands/claude/secguard.md` 的 Dispatcher 协议调度。**
> 本文件只做三件事：(1) 查表选 skill；(2) 按信号分类；(3) 引用 Dispatcher。

---

## 1. 检视算子一览

| # | Rule (目录名) | Severity | CWE | `signal_source` | `skill_id` | Status |
|---|---------------|----------|-----|-----------------|------------|--------|
| 1 | [`command_injection/`](./rules/command_injection/) | 🔴 Critical | CWE-78 | `call_sites[category="*"]` | `go.injection.command` | ✅ |
| 2 | [`sql_injection/`](./rules/sql_injection/) | 🔴 Critical | CWE-89 | `call_sites[category="*"]` | `go.injection.sql` | ✅ |
| 3 | [`ssti/`](./rules/ssti/) | 🔴 Critical | CWE-1336 | `call_sites[category="*"]` | `go.injection.ssti` | ✅ |
| 4 | [`cgo_memory/`](./rules/cgo_memory/) | 🔴 Critical | CWE-120/415/416 | `call_sites[category="*"]` | `go.memory.cgo` | ✅ |
| 5 | [`path_traversal/`](./rules/path_traversal/) | 🟠 High | CWE-22 | `call_sites[category="*"]` | `go.system.path-traversal` | ✅ |
| 6 | [`ssrf/`](./rules/ssrf/) | 🟠 High | CWE-918 | `call_sites[category="*"]` | `go.web.ssrf` | ✅ |
| 7 | [`weak_crypto/`](./rules/weak_crypto/) | 🟠 High | CWE-327 | `call_sites[category="*"]` | `go.crypto.weak` | ✅ |
| 8 | [`hardcoded_secrets/`](./rules/hardcoded_secrets/) | 🟠 High | CWE-798 | `call_sites[category="*"]` | `go.crypto.secrets` | ✅ |
| 9 | [`concurrency_safety/`](./rules/concurrency_safety/) | 🟡 Medium | CWE-366/833 | `call_sites[category="*"]` | `go.concurrency.safety` | ✅ |
| 10 | [`info_leak/`](./rules/info_leak/) | 🟡 Medium | CWE-248/209/532 | `call_sites[category="*"]` | `go.error.info-leak` | ✅ |

**按严重度排序执行：**

```
Critical (4) → High (4) → Medium (2)
```

---

## 2. 信号源分类 → Skill 映射

Go 作为 OO 语言采用**全量加载**策略（区别于 C/C++ 的符号表精确匹配）。对 index.json 中所有匹配语言的规则，加载全部 skill 后按符号表裁剪。

| 信号函数/特征 | 触发 Skill 目录 |
|--------------|-----------------|
| `exec.Command("sh", "-c")`, `os.StartProcess` | `command_injection` |
| `db.Query/Exec` + `fmt.Sprintf`, GORM `Raw()`, `sqlx.In` | `sql_injection` |
| `template.New().Parse(userInput)`, `template.ParseFiles()` 用户路径 | `ssti` |
| `C.CString`, `C.free`, `C.malloc`, `cgo.Handle` | `cgo_memory` |
| `os.Open(userPath)`, `filepath.Join` + 用户输入, `archive/zip` 未验证 | `path_traversal` |
| `http.Get(userURL)`, `httputil.NewSingleHostReverseProxy` | `ssrf` |
| `crypto/md5`, `crypto/sha1`, `crypto/des`, `math/rand` 安全用途 | `weak_crypto` |
| 敏感变量名 + 字符串字面量赋值（password, api_key, jwt_secret） | `hardcoded_secrets` |
| `go` 协程中 map 并发、`sync.Mutex` 值复制、无退出 goroutine | `concurrency_safety` |
| `recover` 直接写响应、`debug.Stack`、`net/http/pprof`、日志含敏感数据 | `info_leak` |

由于 Go 是全量加载 + 符号裁剪，不需要 C/C++ 的 category-based 信号路由表。

---

## 3. 信号 → Skill 派发逻辑

Go 使用**全量加载 → 符号表裁剪**策略：

```
1. 加载所有 10 个 skill 的 rule.md（全量加载）
2. 对每个 skill:
   - 从 index.json.symbols.functions 查询 skill 声明的 trigger_functions
   - 任一 trigger 存在于符号表中 → 激活 skill
   - 无任一 trigger 存在 → 跳过（记录 "Skipped: no matching symbol"）
3. 排序: Critical → High → Medium（按 §1 表）
4. 执行: 依序读取激活 skill 的 rule.md → 执行检视协议 → record-finding.py
```

**符号表匹配精度**：Go 索引器需要覆盖标准库 `exec`/`database/sql`/`crypto/md5`/`net/http` 等包路径，以及第三方框架 `gin`/`gorm`/`echo` 的符号。

---

## 4. 执行流程（引用 Dispatcher 协议）

> **完整执行流水线见 [`commands/claude/secguard.md`](../../../commands/claude/secguard.md)。**
> 此处仅摘要与 skill 派发相关的步骤：

| Step | 职责 | 归属层 |
|------|------|--------|
| Step 1 | 初始化 + 索引构建 | Command |
| Step 2 | 读取 index.json（symbols / files） | Command |
| Step 2.5 | 脱敏 + 扫描范围确定 | Command |
| Step 3a-3c | 语言匹配 + filter 裁剪 + 预筛 | Command |
| **Step 3c.5** | **Go 全量加载 + 符号表裁剪 → 激活候选 skill** | **Skill (本文件 §3)** |
| **Step 3d** | **加载激活 skill 的 rule.md → 执行检视协议** | **Skill (各算子目录)** |
| Step 3.5 | 三轮验证管道（P1-P3） | Command |
| Step 4 | record-finding.py 持久化 + render-report.py | Command |
| Step 5 | 输出摘要 | Command |

各算子的检视协议遵循统一的 6 步模式（信号确认 → 证据链构建 → 参数审计 → 跨函数补证 → 多信号归并 → 事实锚定反思），详见各 `rule.md` 中的检测逻辑。

---

## 5. 参考文件

| 文件 | 内容 |
|------|------|
| [`references/language-features.md`](./references/language-features.md) | Go 危险 API 清单和并发陷阱 |
| [`references/go-security-cheatsheet.md`](./references/go-security-cheatsheet.md) | 快速参考：框架特有陷阱和安全替代 |
