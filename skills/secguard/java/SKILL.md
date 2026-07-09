---
name: secguard-java
description: 对 Java 代码进行安全加固检视，编排 11 个子 skill，覆盖 API 调用检测、反序列化语义分析、契约验证 (TOCTOU) 等多个维度。当用户请求 Java 安全扫描、Java 代码审计、反序列化漏洞、Spring 安全、Java 加密安全时使用。
category: language-specific
language: java
topic: [web, crypto, system]
---

# Java 安全加固排查 — 检视算子索引

本文件是 `skills/secguard/java/` 下 11 个检视算子 skill 的主索引 / 派发表。
每个算子对应 `rules/` 下的一个规则目录，包含自己的 `rule.md`。

> **执行流程由 `commands/claude/secguard.md` 的 Dispatcher 协议调度。**
> 本文件只做三件事：(1) 查表选 skill；(2) 按信号分类；(3) 引用 Dispatcher。

---

## 1. 检视算子一览

| # | Rule (目录名) | Severity | CWE | `signal_source` | `skill_id` |
|---|---------------|----------|-----|-----------------|------------|
| 1 | [`deserialization/`](./rules/deserialization/) | Critical | CWE-502 | Signal Type: deserialization | `java.deserialization.insecure` |
| 2 | [`sql_injection/`](./rules/sql_injection/) | Critical | CWE-89 | Signal Type: sql_operation | `java.sql-injection.dynamic` |
| 3 | [`command_injection/`](./rules/command_injection/) | Critical | CWE-78 | Signal Type: exec_operation | `java.command-injection.exec` |
| 4 | [`ssti_code_injection/`](./rules/ssti_code_injection/) | Critical | CWE-1336 | Signal Type: ssti (template injection) | `java.ssti-code-injection.dynamic` |
| 5 | [`xxe/`](./rules/xxe/) | High | CWE-611 | Signal Type: xml_operation | `java.xxe.insecure-xml` |
| 6 | [`path_traversal/`](./rules/path_traversal/) | High | CWE-22 | Signal Type: resource_acquire (file I/O) | `java.path-traversal.sanitize` |
| 7 | [`ssrf/`](./rules/ssrf/) | High | CWE-918 | Signal Type: http_request | `java.ssrf.open-redirect` |
| 8 | [`weak_crypto/`](./rules/weak_crypto/) | High | CWE-327 | Signal Type: crypto_operation | `java.weak-crypto.algorithm` |
| 9 | [`hardcoded_secrets/`](./rules/hardcoded_secrets/) | High | CWE-798 | Signal Type: crypto_operation | `crypto.hardcoded-secrets` |
| 10 | [`toctou/`](./rules/toctou/) | Medium | CWE-367 | Signal Type: resource_acquire (file I/O) | `java.toctou.race` |
| 11 | [`log_injection/`](./rules/log_injection/) | Medium | CWE-117 | Signal Type: log_operation | `java.log-injection.crlf` |

**按严重度排序执行**: Critical (4) → High (5) → Medium (2)

---

## 2. 信号源分类 → Skill 映射

`index.json` 的 `call_sites[].category` 和 `symbols.functions` 决定触发哪些算子。

Java 为 OO 语言，采用**文件级全量加载**预筛（区别于 C/C++ 的符号表精确匹配）：

| call_sites Category | 触发的 Skill 目录 | 信号函数（示例） |
|--------------------|------------------|-----------------|
| `"deserialization"` | `deserialization` | `readObject`, `parseObject`, `enableDefaultTyping`, `fromXML`, `load` |
| `"sql"` | `sql_injection` | `executeQuery`, `executeUpdate`, `createStatement`, `createNativeQuery` |
| `"exec"` | `command_injection` | `exec`, `ProcessBuilder`, `getRuntime` |
| `"template"` | `ssti_code_injection` | `evaluate`, `parseExpression`, `getValue`, `process`, `eval` |
| `"xml"` | `xxe` | `newDocumentBuilder`, `newSAXParser`, `parse` |
| `"file_io"` | `path_traversal`, `toctou` | `Paths.get`, `new File`, `exists`, `getCanonicalPath`, `ZipInputStream` |
| `"http"` | `ssrf` | `openConnection`, `getForObject`, `uri`, `RestTemplate` |
| `"crypto"` | `weak_crypto`, `hardcoded_secrets` | `getInstance`, `MessageDigest`, `Cipher`, `password`, `secret` |
| `"logging"` | `log_injection` | `info`, `warn`, `error`, `debug`, `log` |

---

## 3. 信号 → Skill 派发逻辑

Java 使用**文件级全量加载**（OO 语言策略）：

```
对 index.json.call_sites 中的每条记录:
  1. 遍历 call_sites:
     - 按 category 匹配「信号源分类 → Skill 映射」(§2)
     - 若 category 命中多个 skill → 全部加入候选集
  2. 对候选集逐个 skill:
     - 扫描 symbols.functions 中的函数名
     - skill 声明的 trigger_functions 存在于符号表中 → 激活（读取 rule.md）
     - 均不存在 → 跳过（记录 "Skipped: no matching symbol"）
  3. 排序: Critical → High → Medium（按 §1 表）
  4. 执行: 依序读取 skill rule.md → 执行检视协议 → record-finding.py
```

---

## 4. 执行流程（引用 Dispatcher 协议）

| Step | 职责 | 归属层 |
|------|------|--------|
| Step 1 | 初始化 + 索引构建 | Command |
| Step 2 | 读取 index.json（symbols / call_graph / files） | Command |
| Step 2.5 | 脱敏 + 扫描范围确定 | Command |
| Step 3a-3c | 语言匹配 + filter 裁剪 + 预筛 | Command |
| **Step 3c.5** | **Java 文件级全量匹配 → 激活候选 skill** | **Skill (本文件 §3)** |
| **Step 3d** | **加载激活 skill 的 SKILL.md → 执行检视协议** | **Skill (各算子目录)** |
| Step 3.5 | 三轮验证管道（P1-P3） | Command |
| Step 4 | record-finding.py 持久化 + render-report.py | Command |
| Step 5 | 输出摘要 | Command |

---

## 5. 参考文件

| 文件 | 内容 |
|------|------|
| [`references/language-features.md`](./references/language-features.md) | Java 危险 API 清单、框架特性、检测优先级 |
