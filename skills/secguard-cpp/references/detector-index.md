# C++ 安全检测器索引

SecGuard C++ 26 个检测器完整清单。每个检测器对应 `knowledge/detectors/<name>.md`。

## 命名空间

检测器使用 `<namespace>.<detector>` 命名空间模型，支持 glob 模式匹配：

```
/secguard ./src memory.*              # 内存安全 + 内存管理 全部 (12 个)
/secguard ./src memory.null_dereference  # 单个检测器
/secguard ./src system               # 系统安全全部 (6 个)
/secguard ./src concurrency          # 并发安全全部 (4 个)
/secguard ./src crypto               # 加密安全全部 (4 个)
/secguard ./src critical             # 所有 Critical 严重度检测器
/secguard ./src *                    # 全部 26 个检测器
/secguard ./src                      # 默认 = * (全部)
```

## 检测器分类

### memory — 内存安全 + 内存管理 (12 个)

#### memory 子命名空间 (内存安全)

| # | 命名空间路径 | CWE | 严重度 | 分析组 | 状态 |
|---|------------|-----|--------|--------|------|
| 1 | `memory.null-dereference` | CWE-476 | High | memory | active |
| 2 | `memory.double-free` | CWE-415 | Critical | memory | active |
| 3 | `memory.use-after-free` | CWE-416 | Critical | memory | active |
| 4 | `memory.buffer-overflow` | CWE-120 | Critical | bounds | active |
| 5 | `memory.heap-buffer-overflow` | CWE-122 | Critical | bounds | planned |
| 6 | `memory.format-string` | CWE-134 | Critical | memory | active |
| 7 | `memory.integer-overflow` | CWE-190 | High | bounds | active |
| 8 | `memory.uninitialized-memory` | CWE-457 | Medium | memory | planned |
| 9 | `memory.memory-leak` | CWE-401 | Medium | memory | planned |
| 10 | `memory.mismatched-free` | CWE-762 | High | memory | planned |
| 11 | `memory.off-by-one` | CWE-193 | High | bounds | planned |
| 12 | `memory.bad-cast` | CWE-704 | Medium | memory | planned |

### concurrency — 并发安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 13 | `concurrency.race-condition` | CWE-362 | High | planned |
| 14 | `concurrency.deadlock` | CWE-833 | Medium | planned |
| 15 | `concurrency.data-race` | CWE-366 | High | planned |
| 16 | `concurrency.thread-unsafe-signal` | CWE-479 | Medium | planned |

### system — 系统安全 (6 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 17 | `system.command-injection` | CWE-77 | Critical | planned |
| 18 | `system.path-traversal` | CWE-22 | High | planned |
| 19 | `system.toctou` | CWE-367 | High | planned |
| 20 | `system.insecure-temp-file` | CWE-377 | Medium | planned |
| 21 | `system.symlink-attack` | CWE-61 | Medium | planned |
| 22 | `system.privilege-escalation` | CWE-269 | High | planned |

### crypto — 加密安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 23 | `crypto.hardcoded-secrets` | CWE-798 | High | planned |
| 24 | `crypto.weak-random` | CWE-338 | High | planned |
| 25 | `crypto.weak-crypto-algorithm` | CWE-327 | High | planned |
| 26 | `crypto.insufficient-key-length` | CWE-326 | Medium | planned |

## 过滤逻辑

```
输入 pattern       →  匹配规则
────────────────────────────────────────
memory              → namespace = memory (12 detectors)
memory.*            → namespace = memory (12 detectors)
memory.null*        → 匹配 memory 下以 null 开头的 detector
concurrency         → namespace = concurrency (4 detectors)
system              → namespace = system (6 detectors)
crypto              → namespace = crypto (4 detectors)
critical            → severity = Critical (跨 namespace)
* 或 空             → 全部 26 个
null-dereference    → 模糊搜索所有 namespace 下的 detector 名
```

---

## 语言专属检测器 (Java / Python / Go)

SecGuardian 为 Java、Python、Go 提供语言专属的 Web 安全检测器，聚焦各语言特有的危险 API 和框架陷阱。

### java — Java Web 安全 (2 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 27 | `java.sql-injection` | CWE-89 | Critical | active |
| 28 | `java.deserialization` | CWE-502 | Critical | active |

### python — Python Web 安全 (1 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 29 | `python.code-injection` | CWE-94 | Critical | active |

### go — Go Web 安全 (1 个)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 30 | `go.sql-injection` | CWE-89 | Critical | active |

### web — Web 安全 (2 个, 跨语言)

| # | 命名空间路径 | CWE | 严重度 | 状态 |
|---|------------|-----|--------|------|
| 31 | `web.xss` | CWE-79 | Critical | active |
| 32 | `web.ssrf` | CWE-918 | High | active |
| 33 | `web.csrf` | CWE-352 | High | active |
| 34 | `web.auth-bypass` | CWE-287 | Critical | active |
| 35 | `web.idor` | CWE-639 | High | active |
| 36 | `web.xxe` | CWE-611 | Critical | active |
| 37 | `web.jwt-misuse` | CWE-347 | High | active |
| 38 | `web.open-redirect` | CWE-601 | Medium | active |

## 添加新检测器

1. 在 `knowledge/detectors/<name>.md` 创建检测器文件
2. 更新本索引文件，分配命名空间路径
3. 在对应 extension 的 `extension.json` 中添加 detector 条目
