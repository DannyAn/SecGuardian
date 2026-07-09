---
category: index
description: 安全威胁目录 — 覆盖所有 15<!-- @secguardian:detector_count --> 个检测 Skill 对应威胁类型的快速索引
cwe_coverage: CWE Top 25 100%
owasp_coverage: OWASP Top 10 100%
---

# 安全威胁目录 (Threat Catalog)

每个威胁对应一个自包含的检测规则（`skills/secguard/{lang}/rules/{name}/rule.md`），内含完整威胁定义、检测逻辑、修复指引、误报排除和检测模式。

> 各语言完整检测规则清单见 `skills/secguard/{lang}/SKILL.md`。本文档提供按命名空间分组的人类可读威胁索引。

## 内存安全 (memory) — 13<!-- @secguardian:namespace:memory --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 空指针解引用 | CWE-476 | High | `memory.null-dereference` | C/C++ |
| 双重释放 | CWE-415 | Critical | `memory.double-free` | C/C++ |
| 释放后使用 | CWE-416 | Critical | `memory.use-after-free` | C/C++ |
| 缓冲区溢出 | CWE-120 | Critical | `memory.buffer-overflow` | C/C++ |
| 堆缓冲区溢出 | CWE-122 | Critical | `memory.heap-buffer-overflow` | C/C++ |
| 格式字符串攻击 | CWE-134 | Critical | `memory.format-string` | C/C++ |
| 整数溢出 | CWE-190 | High | `memory.integer-overflow` | C/C++ |
| 未初始化内存 | CWE-457 | Medium | `memory.uninitialized-memory` | C/C++ |
| 内存泄露 | CWE-401 | Medium | `memory.memory-leak` | C/C++ |
| 不匹配释放 | CWE-762 | High | `memory.mismatched-free` | C/C++ |
| Off-by-One | CWE-193 | High | `memory.off-by-one` | C/C++ |
| 错误类型转换 | CWE-704 | Medium | `memory.bad-cast` | C/C++ |
| 越界读取 | CWE-125 | High | `memory.oob-read` | C/C++ |

## 并发安全 (concurrency) — 4<!-- @secguardian:namespace:concurrency --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 竞态条件 | CWE-362 | High | `concurrency.race-condition` | C/C++ |
| 死锁 | CWE-833 | Medium | `concurrency.deadlock` | C/C++ |
| 数据竞态 | CWE-366 | High | `concurrency.data-race` | C/C++ |
| 信号处理器不安全 | CWE-479 | Medium | `concurrency.thread-unsafe-signal` | C/C++ |

## 系统安全 (system) — 8<!-- @secguardian:namespace:system --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 命令注入 | CWE-77 | Critical | `system.command-injection` | 全语言 |
| 路径遍历 | CWE-22 | High | `system.path-traversal` | 全语言 |
| 密钥泄露 | CWE-798 | High | `system.secrets-detection` | 全语言 |
| TOCTOU 竞态 | CWE-367 | High | `system.toctou` | C/C++ |
| 不安全临时文件 | CWE-377 | Medium | `system.insecure-temp-file` | C/C++ |
| 符号链接攻击 | CWE-61 | Medium | `system.symlink-attack` | C/C++ |
| 权限提升 | CWE-269 | High | `system.privilege-escalation` | C/C++ |
| 不安全权限 | CWE-276 | Medium | `system.insecure-permissions` | C/C++, Java, Python, Go |

## 加密安全 (crypto) — 9<!-- @secguardian:namespace:crypto --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 硬编码密钥 | CWE-798 | High | `crypto.hardcoded-secrets` | 全语言 |
| 弱随机数 | CWE-338 | High | `crypto.weak-random` | 全语言 |
| 弱加密算法 | CWE-327 | High | `crypto.weak-crypto-algorithm` | 全语言 |
| 密钥长度不足 | CWE-326 | Medium | `crypto.insufficient-key-length` | 全语言 |
| AES-ECB 模式 | CWE-327 | High | `crypto.aes-ecb-mode` | 全语言 |
| TLS 弱版本 | CWE-326 | Medium | `crypto.tls-version` | 全语言 |
| 自定义加密 | CWE-327 | Critical | `crypto.custom-crypto` | 全语言 |
| 密码存储不安全 | CWE-916 | Critical | `crypto.password-storage` | Java, Python, Go, JS |
| 硬编码 IV/Nonce | CWE-329 | High | `crypto.hardcoded-iv` | 全语言 |

## Web + 应用安全 (web) — 21<!-- @secguardian:namespace:web --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| XSS | CWE-79 | Critical | `web.xss` | Java, Python, Go, JS |
| SSRF | CWE-918 | High | `web.ssrf` | Java, Python, Go, JS |
| CSRF | CWE-352 | High | `web.csrf` | Java, Python, Go |
| 认证绕过 | CWE-287 | Critical | `web.auth-bypass` | Java, Python, Go, JS |
| IDOR | CWE-639 | High | `web.idor` | Java, Python, Go |
| XXE | CWE-611 | Critical | `web.xxe` | Java, Python, Go |
| JWT 误用 | CWE-347 | High | `web.jwt-misuse` | Java, Python, Go, JS |
| 开放重定向 | CWE-601 | Medium | `web.open-redirect` | Java, Python, Go, JS |
| 缺少认证 | CWE-306 | Critical | `web.missing-authentication` | Java, Python, Go, JS |
| 缺少授权 | CWE-862 | High | `web.missing-authorization` | Java, Python, Go, JS |
| 无限制上传 | CWE-434 | Critical | `web.unrestricted-upload` | Java, Python, Go, JS |
| SQL 注入 | CWE-89 | Critical | `web.sql-injection` | Java, Go |
| 反序列化 | CWE-502 | Critical | `web.deserialization` | Java, Python |
| 代码注入 | CWE-94 | Critical | `web.code-injection` | Python |
| 输入验证 | CWE-20 | High | `web.input-validation` | 全语言 |
| 资源耗尽 | CWE-400 | Medium | `web.resource-exhaustion` | 全语言 |
| 批量分配 | CWE-915 | Critical | `web.mass-assignment` | Java, Python, Go, JS |
| 过度数据暴露 | CWE-200 | High | `web.excessive-data-exposure` | Java, Python, Go, JS |
| NoSQL 注入 | CWE-943 | Critical | `web.nosql-injection` | JS (MongoDB) |
| 原型污染 | CWE-1321 | High | `web.prototype-pollution` | JS |
| SSTI 模板注入 | CWE-1336 | Critical | `web.ssti` | Java, Python, Go, JS |

## 资源安全 (resource) — 6<!-- @secguardian:namespace:resource --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 文件句柄泄露 | CWE-404 | Medium | `resource.file-leak` | C/C++ |
| Socket 泄露 | CWE-404 | Medium | `resource.socket-leak` | C/C++ |
| 文件重复关闭 | CWE-675 | Low | `resource.file-double-close` | C/C++ |
| 关闭后使用 | CWE-416 | High | `resource.file-use-after-close` | C/C++ |
| 锁误用 | CWE-667 | Medium | `resource.lock-misuse` | C/C++ |
| 引用计数误用 | CWE-911 | Low | `resource.refcount-misuse` | C/C++ |

## 错误处理安全 (error) — 6<!-- @secguardian:namespace:error --> 个 detectors

| 威胁 | CWE | 严重度 | Detector | 影响语言 |
|------|-----|--------|----------|---------|
| 堆栈轨迹泄露 | CWE-209 | High | `error.stack-trace-leak` | 全语言 |
| 日志敏感数据 | CWE-532 | High | `error.log-sensitive-data` | 全语言 |
| 异常吞掉 | CWE-391 | Medium | `error.exception-swallow` | 全语言 |
| 错误格式不统一 | CWE-544 | Medium | `error.unified-error-format` | Java, Python, Go, JS |
| 生产调试模式 | CWE-489 | High | `error.debug-mode-production` | 全语言 |
| Panic 返回客户端 | CWE-248 | Medium | `error.panic-to-client` | Go |

## 使用方式

### AI Agent 加载
执行 `/secguard` 时，Agent 按需加载具体的 detector 文件。每个 detector 文件自包含：
- **威胁定义** — 是什么、为什么危险、核心原则
- **检测逻辑** — 分步骤、分语言的检测方法
- **修复指引** — 首选/次选/禁止方案
- **误报排除** — FP 场景清单
- **检测模式汇总** — Regex/AST 级别检测规则

### 按严重度过滤
```
/secguard ./src critical  → 所有 Critical 严重度 detectors
```

### 按命名空间过滤
```
/secguard ./src error.*   → 错误处理类全部 6 个 detectors
/secguard ./src crypto.*  → 加密类全部 9 个 detectors
```
