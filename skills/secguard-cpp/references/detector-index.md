# C++ 安全检测器索引

SecGuard 45 个检测器完整清单。每个检测器对应 `knowledge/detectors/<name>.md`。

## 命名空间

检测器使用 `<namespace>.<detector>` 命名空间模型，支持 glob 模式匹配：

```
/secguard ./src memory.*              # 内存安全全部 (13 个)
/secguard ./src memory.null_dereference  # 单个检测器
/secguard ./src concurrency          # 并发安全全部 (4 个)
/secguard ./src system               # 系统安全全部 (6 个)
/secguard ./src crypto               # 加密安全全部 (4 个)
/secguard ./src web                  # Web 安全全部 (11 个)
/secguard ./src general              # 通用安全全部 (3 个)
/secguard ./src java                 # Java 安全全部 (2 个)
/secguard ./src python               # Python 安全 (1 个)
/secguard ./src go                   # Go 安全 (1 个)
/secguard ./src critical             # 所有 Critical 严重度检测器
/secguard ./src *                    # 全部 45 个检测器
/secguard ./src                      # 默认 = * (全部)
```

## 检测器分类

### memory — 内存安全 + 内存管理 (12 个)

| # | 命名空间路径 | CWE | 严重度 | 分析组 | 状态 |
|---|------------|-----|--------|--------|------|
| 1 | `memory.null-dereference` | CWE-476 | High | memory | active |
| 2 | `memory.double-free` | CWE-415 | Critical | memory | active |
| 3 | `memory.use-after-free` | CWE-416 | Critical | memory | active |
| 4 | `memory.buffer-overflow` | CWE-120 | Critical | bounds | active |
| 5 | `memory.heap-buffer-overflow` | CWE-122 | Critical | bounds | active |
| 6 | `memory.format-string` | CWE-134 | Critical | memory | active |
| 7 | `memory.integer-overflow` | CWE-190 | High | bounds | active |
| 8 | `memory.uninitialized-memory` | CWE-457 | Medium | memory | active |
| 9 | `memory.memory-leak` | CWE-401 | Medium | memory | active |
| 10 | `memory.mismatched-free` | CWE-762 | High | memory | active |
| 11 | `memory.off-by-one` | CWE-193 | High | bounds | active |
| 12 | `memory.bad-cast` | CWE-704 | Medium | memory | active |
| 13 | `memory.oob-read` | CWE-125 | High | memory | active |

### concurrency — 并发安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 分析组 | 状态 |
|---|------------|-----|--------|--------|------|
| 13 | `concurrency.race-condition` | CWE-362 | High | concurrency | active |
| 14 | `concurrency.deadlock` | CWE-833 | Medium | concurrency | active |
| 15 | `concurrency.data-race` | CWE-366 | High | concurrency | active |
| 16 | `concurrency.thread-unsafe-signal` | CWE-479 | Medium | concurrency | active |

### system — 系统安全 (6 个)

| # | 命名空间路径 | CWE | 严重度 | 分析组 | 状态 |
|---|------------|-----|--------|--------|------|
| 17 | `system.command-injection` | CWE-77 | Critical | system | active |
| 18 | `system.path-traversal` | CWE-22 | High | system | active |
| 19 | `system.toctou` | CWE-367 | High | system | active |
| 20 | `system.insecure-temp-file` | CWE-377 | Medium | system | active |
| 21 | `system.symlink-attack` | CWE-61 | Medium | system | active |
| 22 | `system.privilege-escalation` | CWE-269 | High | system | active |

### crypto — 加密安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 分析组 | 状态 |
|---|------------|-----|--------|--------|------|
| 23 | `crypto.hardcoded-secrets` | CWE-798 | High | crypto | active |
| 24 | `crypto.weak-random` | CWE-338 | High | crypto | active |
| 25 | `crypto.weak-crypto-algorithm` | CWE-327 | High | crypto | active |
| 26 | `crypto.insufficient-key-length` | CWE-326 | Medium | crypto | active |

### web — Web 安全 (11 个, 跨语言)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 27 | `web.xss` | CWE-79 | Critical | java, python, go | active |
| 28 | `web.ssrf` | CWE-918 | High | java, python, go | active |
| 29 | `web.csrf` | CWE-352 | High | java, python, go | active |
| 30 | `web.auth-bypass` | CWE-287 | Critical | java, python, go | active |
| 31 | `web.idor` | CWE-639 | High | java, python, go | active |
| 32 | `web.xxe` | CWE-611 | Critical | java, python, go | active |
| 33 | `web.jwt-misuse` | CWE-347 | High | java, python, go | active |
| 34 | `web.open-redirect` | CWE-601 | Medium | java, python, go | active |
| 35 | `web.missing-authentication` | CWE-306 | Critical | java, python, go | active |
| 36 | `web.missing-authorization` | CWE-862 | High | java, python, go | active |
| 37 | `web.unrestricted-upload` | CWE-434 | Critical | java, python, go | active |

### general — 通用安全 (3 个, 跨语言)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 38 | `general.input-validation` | CWE-20 | High | c, cpp, java, python, go | active |
| 39 | `general.insecure-permissions` | CWE-276 | Medium | c, cpp, java, python, go | active |
| 40 | `general.resource-exhaustion` | CWE-400 | Medium | c, cpp, java, python, go | active |

### java — Java Web 安全 (2 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 41 | `java.sql-injection` | CWE-89 | Critical | java | active |
| 42 | `java.deserialization` | CWE-502 | Critical | java | active |

### python — Python Web 安全 (1 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 43 | `python.code-injection` | CWE-94 | Critical | python | active |

### go — Go Web 安全 (1 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 44 | `go.sql-injection` | CWE-89 | Critical | go | active |

## 过滤逻辑

```
输入 pattern       →  匹配规则
────────────────────────────────────────
memory              → namespace = memory (13 detectors)
memory.*            → namespace = memory (13 detectors)
memory.null*        → 匹配 memory 下以 null 开头的 detector
concurrency         → namespace = concurrency (4 detectors)
system              → namespace = system (6 detectors)
crypto              → namespace = crypto (4 detectors)
web                 → namespace = web (11 detectors)
general             → namespace = general (3 detectors)
java                → namespace = java (2 detectors)
python              → namespace = python (1 detector)
go                  → namespace = go (1 detector)
critical            → severity = Critical (跨 namespace)
* 或 空             → 全部 45 个
null-dereference    → 模糊搜索所有 namespace 下的 detector 名
```

## 添加新检测器

1. 在 `knowledge/detectors/<name>.md` 创建检测器知识文件（4 步检测逻辑 + FP 排除表 + 模式汇总）
2. 更新本索引文件，分配命名空间路径
3. 在 `manifest.json` 中更新 detector 计数
4. 运行 `bash tools/check.sh` 验证完整性

## 覆盖统计

| 框架 | 覆盖数 | 总计 | 覆盖率 |
|------|--------|------|--------|
| CWE Top 25 (2024) | 22 | 25 | 88% |
| OWASP Top 10 (2021) | 9 | 10 | 90% |
| C/C++ 内存安全 | 13 | 13 | 100% |
| C/C++ 并发安全 | 4 | 4 | 100% |
| C/C++ 系统安全 | 6 | 6 | 100% |
| C/C++ 加密安全 | 4 | 4 | 100% |
| Web 安全 (跨语言) | 11 | 11 | 100% |
| 通用安全 (跨语言) | 3 | 3 | 100% |
