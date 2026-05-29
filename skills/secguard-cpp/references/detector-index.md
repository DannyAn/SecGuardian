# SecGuardian 检测器索引

SecGuard 45 个检测器完整清单，按 **5 个统一 topic** 组织。每个检测器对应 `knowledge/detectors/<name>.md`。

> 5 个 topic 同时作为 `/secguard` namespace、`/secaudit` 审计领域、`/secreview` 语言 profile 的共享分类。
> 语言过滤由 frontmatter 中的 `language` 字段标记，不在 namespace 中体现。

## 命名空间

检测器使用 `<namespace>.<detector>` 命名空间模型，支持 glob 模式匹配：

```
/secguard ./src memory.*              # 内存安全全部 (13 个)
/secguard ./src memory.oob-read       # 单个检测器
/secguard ./src concurrency           # 并发安全全部 (4 个)
/secguard ./src system                # 系统安全全部 (7 个)
/secguard ./src crypto                # 加密安全全部 (4 个)
/secguard ./src web                   # Web + 应用安全全部 (17 个)
/secguard ./src critical              # 所有 Critical 严重度检测器
/secguard ./src *                     # 全部 45 个检测器
/secguard ./src                       # 默认 = * (全部)
```

## 检测器分类

### memory — 内存安全 (13 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 1 | `memory.null-dereference` | CWE-476 | High | c, cpp | active |
| 2 | `memory.double-free` | CWE-415 | Critical | c, cpp | active |
| 3 | `memory.use-after-free` | CWE-416 | Critical | c, cpp | active |
| 4 | `memory.buffer-overflow` | CWE-120 | Critical | c, cpp | active |
| 5 | `memory.heap-buffer-overflow` | CWE-122 | Critical | c, cpp | active |
| 6 | `memory.format-string` | CWE-134 | Critical | c, cpp | active |
| 7 | `memory.integer-overflow` | CWE-190 | High | c, cpp | active |
| 8 | `memory.uninitialized-memory` | CWE-457 | Medium | c, cpp | active |
| 9 | `memory.memory-leak` | CWE-401 | Medium | c, cpp | active |
| 10 | `memory.mismatched-free` | CWE-762 | High | c, cpp | active |
| 11 | `memory.off-by-one` | CWE-193 | High | c, cpp | active |
| 12 | `memory.bad-cast` | CWE-704 | Medium | c, cpp | active |
| 13 | `memory.oob-read` | CWE-125 | High | c, cpp | active |

### concurrency — 并发安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 14 | `concurrency.race-condition` | CWE-362 | High | c, cpp | active |
| 15 | `concurrency.deadlock` | CWE-833 | Medium | c, cpp | active |
| 16 | `concurrency.data-race` | CWE-366 | High | c, cpp | active |
| 17 | `concurrency.thread-unsafe-signal` | CWE-479 | Medium | c, cpp | active |

### system — 系统安全 (7 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 18 | `system.command-injection` | CWE-77 | Critical | c, cpp | active |
| 19 | `system.path-traversal` | CWE-22 | High | c, cpp | active |
| 20 | `system.toctou` | CWE-367 | High | c, cpp | active |
| 21 | `system.insecure-temp-file` | CWE-377 | Medium | c, cpp | active |
| 22 | `system.symlink-attack` | CWE-61 | Medium | c, cpp | active |
| 23 | `system.privilege-escalation` | CWE-269 | High | c, cpp | active |
| 24 | `system.insecure-permissions` | CWE-276 | Medium | c, cpp, java, python, go | active |

### crypto — 加密安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 25 | `crypto.hardcoded-secrets` | CWE-798 | High | c, cpp | active |
| 26 | `crypto.weak-random` | CWE-338 | High | c, cpp | active |
| 27 | `crypto.weak-crypto-algorithm` | CWE-327 | High | c, cpp | active |
| 28 | `crypto.insufficient-key-length` | CWE-326 | Medium | c, cpp | active |

### web — Web + 应用安全 (17 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 29 | `web.xss` | CWE-79 | Critical | java, python, go | active |
| 30 | `web.ssrf` | CWE-918 | High | java, python, go | active |
| 31 | `web.csrf` | CWE-352 | High | java, python, go | active |
| 32 | `web.auth-bypass` | CWE-287 | Critical | java, python, go | active |
| 33 | `web.idor` | CWE-639 | High | java, python, go | active |
| 34 | `web.xxe` | CWE-611 | Critical | java, python, go | active |
| 35 | `web.jwt-misuse` | CWE-347 | High | java, python, go | active |
| 36 | `web.open-redirect` | CWE-601 | Medium | java, python, go | active |
| 37 | `web.missing-authentication` | CWE-306 | Critical | java, python, go | active |
| 38 | `web.missing-authorization` | CWE-862 | High | java, python, go | active |
| 39 | `web.unrestricted-upload` | CWE-434 | Critical | java, python, go | active |
| 40 | `web.sql-injection` | CWE-89 | Critical | java, go | active |
| 41 | `web.deserialization` | CWE-502 | Critical | java | active |
| 42 | `web.code-injection` | CWE-94 | Critical | python | active |
| 43 | `web.input-validation` | CWE-20 | High | c, cpp, java, python, go | active |
| 44 | `web.resource-exhaustion` | CWE-400 | Medium | c, cpp, java, python, go | active |<｜end▁of▁thinking｜>

<｜｜DSML｜｜tool_calls>
<｜｜DSML｜｜invoke name="write_file">
<｜｜DSML｜｜parameter name="content" string="true"># SecGuardian 检测器索引

SecGuard 45 个检测器完整清单，按 **5 个统一 topic** 组织。每个检测器对应 `knowledge/detectors/<name>.md`。

> 5 个 topic 同时作为 `/secguard` namespace、`/secaudit` 审计领域、`/secreview` 语言 profile 的共享分类。
> 语言过滤由 frontmatter 中的 `language` 字段标记，不在 namespace 中体现。

## 命名空间

检测器使用 `<namespace>.<detector>` 命名空间模型，支持 glob 模式匹配：

```
/secguard ./src memory.*              # 内存安全全部 (13 个)
/secguard ./src memory.oob-read       # 单个检测器
/secguard ./src concurrency           # 并发安全全部 (4 个)
/secguard ./src system                # 系统安全全部 (7 个)
/secguard ./src crypto                # 加密安全全部 (4 个)
/secguard ./src web                   # Web + 应用安全全部 (17 个)
/secguard ./src critical              # 所有 Critical 严重度检测器
/secguard ./src *                     # 全部 45 个检测器
/secguard ./src                       # 默认 = * (全部)
```

## 检测器分类

### memory — 内存安全 (13 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 1 | `memory.null-dereference` | CWE-476 | High | c, cpp | active |
| 2 | `memory.double-free` | CWE-415 | Critical | c, cpp | active |
| 3 | `memory.use-after-free` | CWE-416 | Critical | c, cpp | active |
| 4 | `memory.buffer-overflow` | CWE-120 | Critical | c, cpp | active |
| 5 | `memory.heap-buffer-overflow` | CWE-122 | Critical | c, cpp | active |
| 6 | `memory.format-string` | CWE-134 | Critical | c, cpp | active |
| 7 | `memory.integer-overflow` | CWE-190 | High | c, cpp | active |
| 8 | `memory.uninitialized-memory` | CWE-457 | Medium | c, cpp | active |
| 9 | `memory.memory-leak` | CWE-401 | Medium | c, cpp | active |
| 10 | `memory.mismatched-free` | CWE-762 | High | c, cpp | active |
| 11 | `memory.off-by-one` | CWE-193 | High | c, cpp | active |
| 12 | `memory.bad-cast` | CWE-704 | Medium | c, cpp | active |
| 13 | `memory.oob-read` | CWE-125 | High | c, cpp | active |

### concurrency — 并发安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 14 | `concurrency.race-condition` | CWE-362 | High | c, cpp | active |
| 15 | `concurrency.deadlock` | CWE-833 | Medium | c, cpp | active |
| 16 | `concurrency.data-race` | CWE-366 | High | c, cpp | active |
| 17 | `concurrency.thread-unsafe-signal` | CWE-479 | Medium | c, cpp | active |

### system — 系统安全 (7 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 18 | `system.command-injection` | CWE-77 | Critical | c, cpp | active |
| 19 | `system.path-traversal` | CWE-22 | High | c, cpp | active |
| 20 | `system.toctou` | CWE-367 | High | c, cpp | active |
| 21 | `system.insecure-temp-file` | CWE-377 | Medium | c, cpp | active |
| 22 | `system.symlink-attack` | CWE-61 | Medium | c, cpp | active |
| 23 | `system.privilege-escalation` | CWE-269 | High | c, cpp | active |
| 24 | `system.insecure-permissions` | CWE-276 | Medium | c, cpp, java, python, go | active |

### crypto — 加密安全 (4 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 25 | `crypto.hardcoded-secrets` | CWE-798 | High | c, cpp | active |
| 26 | `crypto.weak-random` | CWE-338 | High | c, cpp | active |
| 27 | `crypto.weak-crypto-algorithm` | CWE-327 | High | c, cpp | active |
| 28 | `crypto.insufficient-key-length` | CWE-326 | Medium | c, cpp | active |

### web — Web + 应用安全 (17 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 29 | `web.xss` | CWE-79 | Critical | java, python, go | active |
| 30 | `web.ssrf` | CWE-918 | High | java, python, go | active |
| 31 | `web.csrf` | CWE-352 | High | java, python, go | active |
| 32 | `web.auth-bypass` | CWE-287 | Critical | java, python, go | active |
| 33 | `web.idor` | CWE-639 | High | java, python, go | active |
| 34 | `web.xxe` | CWE-611 | Critical | java, python, go | active |
| 35 | `web.jwt-misuse` | CWE-347 | High | java, python, go | active |
| 36 | `web.open-redirect` | CWE-601 | Medium | java, python, go | active |
| 37 | `web.missing-authentication` | CWE-306 | Critical | java, python, go | active |
| 38 | `web.missing-authorization` | CWE-862 | High | java, python, go | active |
| 39 | `web.unrestricted-upload` | CWE-434 | Critical | java, python, go | active |
| 40 | `web.sql-injection` | CWE-89 | Critical | java, go | active |
| 41 | `web.deserialization` | CWE-502 | Critical | java | active |
| 42 | `web.code-injection` | CWE-94 | Critical | python | active |
| 43 | `web.input-validation` | CWE-20 | High | c, cpp, java, python, go | active |
| 44 | `web.resource-exhaustion` | CWE-400 | Medium | c, cpp, java, python, go | active |

## 过滤逻辑

```
输入 pattern       →  匹配规则
────────────────────────────────────────
memory              → namespace = memory (13 detectors)
memory.*            → namespace = memory (13 detectors)
memory.oob*         → 匹配 memory 下以 oob 开头的 detector
concurrency         → namespace = concurrency (4)
system              → namespace = system (7)
crypto              → namespace = crypto (4)
web                 → namespace = web (17)
web.sql*            → 匹配 web 下以 sql 开头的 detector
critical            → severity = Critical (跨 namespace)
* 或 空             → 全部 45 个
xss|sqli|ssrf       → 模糊搜索所有 namespace 下的 detector 名
```

## 各产品共享的 5-topic 体系

| Topic | /secguard (detectors) | /secaudit (skills) | /secreview (languages) |
|-------|-----------------------|-------------------|----------------------|
| `memory` | 13 | data-flow-analysis, taint-analysis, state-machine-analysis | cpp |
| `concurrency` | 4 | state-machine-analysis | cpp, go |
| `system` | 7 | secrets-management, infra-hardening, secure-transport, data-protection, dependency-security, logging-and-monitoring, trust-boundary-analysis | cpp, python |
| `crypto` | 4 | cryptography, secrets-management, secure-transport | 全部 4 |
| `web` | 17 | auth-and-session, authorization, input-validation, output-encoding, http-security-headers, attack-surface-analysis, trust-boundary-analysis | java, python, go |

## 添加新检测器

1. 在 `knowledge/detectors/<name>.md` 创建检测器知识文件（4 步检测逻辑 + FP 排除表 + 模式汇总）
2. 更新本索引文件，分配 5 个 namespace 之一
3. 在 `manifest.json` 中更新 detector 计数
4. 运行 `bash scripts/build.sh cc` 验证

## 覆盖统计

| 框架 | 覆盖数 | 总计 | 覆盖率 |
|------|--------|------|--------|
| CWE Top 25 (2024) | 22 | 25 | 88% |
| OWASP Top 10 (2021) | 9 | 10 | 90% |
| memory | 13 | 13 | 100% |
| concurrency | 4 | 4 | 100% |
| system | 7 | 7 | 100% |
| crypto | 4 | 4 | 100% |
| web | 17 | 17 | 100% |
