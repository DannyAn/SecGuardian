# SecGuardian 检测器索引

SecGuard 60 个检测器（+1 个 secrets-detection 跨命名空间），按 **6 个统一 topic** 组织。每个检测器对应 `knowledge/detectors/<name>.md`。

> 6 个 topic 同时作为 `/secguard` namespace、`/secaudit` 审计领域、`/secreview` 语言 profile 的共享分类。
> 语言过滤由 frontmatter 中的 `language` 字段标记，不在 namespace 中体现。

## 命名空间

检测器使用 `<namespace>.<detector>` 命名空间模型，支持 glob 模式匹配：

```
/secguard ./src memory.*              # 内存安全全部 (13 个)
/secguard ./src concurrency           # 并发安全全部 (4 个)
/secguard ./src system                # 系统安全全部 (8 个)
/secguard ./src resource              # 资源生命周期全部 (6 个)
/secguard ./src crypto                # 加密安全全部 (9 个)
/secguard ./src web                   # Web + 应用安全全部 (21 个)
/secguard ./src error                 # 错误处理全部 (6 个)
/secguard ./src critical              # 所有 Critical 严重度检测器
/secguard ./src *                     # 全部 67 个检测器
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

### system — 系统安全 (8 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 18 | `system.command-injection` | CWE-77 | Critical | c, cpp, java, python, go, js | active |
| 19 | `system.path-traversal` | CWE-22 | High | c, cpp, java, python, go, js | active |
| 20 | `system.toctou` | CWE-367 | High | c, cpp | active |
| 21 | `system.insecure-temp-file` | CWE-377 | Medium | c, cpp | active |
| 22 | `system.symlink-attack` | CWE-61 | Medium | c, cpp | active |
| 23 | `system.privilege-escalation` | CWE-269 | High | c, cpp | active |
| 24 | `system.insecure-permissions` | CWE-276 | Medium | c, cpp, java, python, go | active |
| 25 | `system.secrets-detection` | CWE-798 | High | c, cpp, java, python, go, js | active |

### resource — 资源生命周期安全 (6 个) ⭐

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 26 | `resource.file-leak` | CWE-775 | High | c, cpp | active |
| 27 | `resource.file-use-after-close` | CWE-672 | High | c, cpp | active |
| 28 | `resource.file-double-close` | CWE-675 | High | c, cpp | active |
| 29 | `resource.socket-leak` | CWE-772 | Medium | c, cpp | active |
| 30 | `resource.lock-misuse` | CWE-667 | High | c, cpp | active |
| 31 | `resource.refcount-misuse` | CWE-911 | Medium | c, cpp | active |

### crypto — 加密安全 (9 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 25 | `crypto.hardcoded-secrets` | CWE-798 | High | c, cpp, java, python, go, js | active |
| 26 | `crypto.weak-random` | CWE-338 | High | c, cpp, java, python, go, js | active |
| 27 | `crypto.weak-crypto-algorithm` | CWE-327 | High | c, cpp, java, python, go, js | active |
| 28 | `crypto.insufficient-key-length` | CWE-326 | Medium | c, cpp, java, python, go, js | active |
| 29 | `crypto.aes-ecb-mode` | CWE-327 | High | c, cpp, java, python, go, js | active |
| 30 | `crypto.tls-version` | CWE-326 | Medium | c, cpp, java, python, go, js | active |
| 31 | `crypto.custom-crypto` | CWE-327 | Critical | c, cpp, java, python, go, js | active |
| 32 | `crypto.password-storage` | CWE-916 | Critical | java, python, go, js | active |
| 33 | `crypto.hardcoded-iv` | CWE-329 | High | c, cpp, java, python, go, js | active |

### web — Web + 应用安全 (21 个)

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 34 | `web.xss` | CWE-79 | Critical | java, python, go, js | active |
| 35 | `web.ssrf` | CWE-918 | High | java, python, go, js | active |
| 36 | `web.csrf` | CWE-352 | High | java, python, go | active |
| 37 | `web.auth-bypass` | CWE-287 | Critical | java, python, go, js | active |
| 38 | `web.idor` | CWE-639 | High | java, python, go | active |
| 39 | `web.xxe` | CWE-611 | Critical | java, python, go | active |
| 40 | `web.jwt-misuse` | CWE-347 | High | java, python, go, js | active |
| 41 | `web.open-redirect` | CWE-601 | Medium | java, python, go, js | active |
| 42 | `web.missing-authentication` | CWE-306 | Critical | java, python, go, js | active |
| 43 | `web.missing-authorization` | CWE-862 | High | java, python, go, js | active |
| 44 | `web.unrestricted-upload` | CWE-434 | Critical | java, python, go, js | active |
| 45 | `web.sql-injection` | CWE-89 | Critical | java, go | active |
| 46 | `web.deserialization` | CWE-502 | Critical | java, python | active |
| 47 | `web.code-injection` | CWE-94 | Critical | python | active |
| 48 | `web.input-validation` | CWE-20 | High | c, cpp, java, python, go, js | active |
| 49 | `web.resource-exhaustion` | CWE-400 | Medium | c, cpp, java, python, go, js | active |
| 50 | `web.mass-assignment` ⭐ | CWE-915 | Critical | java, python, go, js | active |
| 51 | `web.excessive-data-exposure` ⭐ | CWE-200 | High | java, python, go, js | active |
| 52 | `web.nosql-injection` ⭐ | CWE-943 | Critical | js | active |
| 53 | `web.prototype-pollution` ⭐ | CWE-1321 | High | js | active |
| 54 | `web.ssti` ⭐ | CWE-1336 | Critical | java, python, go, js | active |

### error — 错误处理安全 (6 个) ⭐

| # | 命名空间路径 | CWE | 严重度 | 语言 | 状态 |
|---|------------|-----|--------|------|------|
| 55 | `error.stack-trace-leak` ⭐ | CWE-209 | High | c, cpp, java, python, go, js | active |
| 56 | `error.log-sensitive-data` ⭐ | CWE-532 | High | c, cpp, java, python, go, js | active |
| 57 | `error.exception-swallow` ⭐ | CWE-391 | Medium | c, cpp, java, python, go, js | active |
| 58 | `error.unified-error-format` ⭐ | CWE-544 | Medium | java, python, go, js | active |
| 59 | `error.debug-mode-production` ⭐ | CWE-489 | High | c, cpp, java, python, go, js | active |
| 60 | `error.panic-to-client` ⭐ | CWE-248 | Medium | go | active |

> ⭐ = 本次 CodePlan 新增 (16 个检测器)

## 过滤逻辑

```
输入 pattern       →  匹配规则
────────────────────────────────────────
memory              → namespace = memory (13 detectors)
memory.*            → namespace = memory (13 detectors)
memory.oob*         → 匹配 memory 下以 oob 开头的 detector
concurrency         → namespace = concurrency (4)
system              → namespace = system (7)
crypto              → namespace = crypto (9)
web                 → namespace = web (21)
error               → namespace = error (6)
web.sql*            → 匹配 web 下以 sql 开头的 detector
critical            → severity = Critical (跨 namespace)
* 或 空             → 全部 60 个（不含 secrets-detection 跨命名空间检测器）
xss\|sqli\|ssrf       → 模糊搜索所有 namespace 下的 detector 名
```

## 各产品共享的 6-topic 体系

| Topic | /secguard (detectors) | /secaudit (skills) | /secreview (languages) |
|-------|-----------------------|-------------------|----------------------|
| `memory` | 13 | data-flow-analysis, taint-analysis, state-machine-analysis | cpp |
| `concurrency` | 4 | state-machine-analysis | cpp, go |
| `system` | 7 | secrets-management, infra-hardening, secure-transport, data-protection, dependency-security, logging-and-monitoring, trust-boundary-analysis | cpp, python |
| `crypto` | 9 | cryptography, secrets-management, secure-transport | cpp, java, python, go, js |
| `web` | 21 | auth-and-session, authorization, input-validation, output-encoding, http-security-headers, attack-surface-analysis, trust-boundary-analysis | java, python, go, js |
| `error` ⭐ | 6 | logging-and-monitoring, trust-boundary-analysis | 全部 5 语 |

## 添加新检测器

1. 在 `knowledge/detectors/<name>.md` 创建检测器知识文件（4 步检测逻辑 + FP 排除表 + 模式汇总）
2. 更新本索引文件，分配 6 个 namespace 之一
3. 在 `manifest.json` 中更新 detector 计数
4. 运行 `bash scripts/dev-deploy.sh` 部署验证

## 覆盖统计

| 框架 | 覆盖数 | 总计 | 覆盖率 |
|------|--------|------|--------|
| CWE Top 25 (2024) | 25 | 25 | 100% |
| OWASP Top 10 (2021) | 10 | 10 | 100% |
| OWASP API Top 10 (2023) | 10 | 10 | 100% |
| memory | 13 | 13 | 100% |
| concurrency | 4 | 4 | 100% |
| system | 7 | 7 | 100% |
| crypto | 9 | 9 | 100% |
| web | 21 | 21 | 100% |
| error ⭐ | 6 | 6 | 100% |

## CWE Top 25 全覆盖明细

| CWE | 名称 | 覆盖检测器 | 状态 |
|-----|------|-----------|------|
| CWE-79 | XSS | web.xss | ✅ |
| CWE-89 | SQL 注入 | web.sql-injection | ✅ |
| CWE-120 | 缓冲区溢出 | memory.buffer-overflow | ✅ |
| CWE-22 | 路径遍历 | system.path-traversal | ✅ |
| CWE-77 | 命令注入 | system.command-injection | ✅ |
| CWE-287 | 认证缺陷 | web.auth-bypass | ✅ |
| CWE-352 | CSRF | web.csrf | ✅ |
| CWE-502 | 反序列化 | web.deserialization | ✅ |
| CWE-416 | UAF | memory.use-after-free | ✅ |
| CWE-415 | 双重释放 | memory.double-free | ✅ |
| CWE-476 | NULL 解引用 | memory.null-dereference | ✅ |
| CWE-190 | 整数溢出 | memory.integer-overflow | ✅ |
| CWE-362 | 竞态条件 | concurrency.race-condition | ✅ |
| CWE-798 | 硬编码凭证 | crypto.hardcoded-secrets | ✅ |
| CWE-327 | 弱加密 | crypto.weak-crypto-algorithm | ✅ |
| CWE-918 | SSRF | web.ssrf | ✅ |
| CWE-20 | 输入验证 | web.input-validation | ✅ |
| CWE-125 | 越界读取 | memory.oob-read | ✅ |
| CWE-276 | 权限缺陷 | system.insecure-permissions | ✅ |
| CWE-400 | 资源耗尽 | web.resource-exhaustion | ✅ |
| CWE-306 | 缺认证 | web.missing-authentication | ✅ |
| CWE-434 | 文件上传 | web.unrestricted-upload | ✅ |
| CWE-862 | 缺授权 | web.missing-authorization | ✅ |
| CWE-200 | 信息泄露 | web.excessive-data-exposure ⭐ | ✅ |
| CWE-209 | 错误信息泄露 | error.stack-trace-leak ⭐ | ✅ |
| CWE-532 | 日志敏感数据 | error.log-sensitive-data ⭐ | ✅ |
| CWE-611 | XXE | web.xxe | ✅ |
