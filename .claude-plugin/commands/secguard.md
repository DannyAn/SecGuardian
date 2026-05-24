---
allowed-tools: Bash(git diff:*)
description: 安全加固项排查 — 对指定路径的源码执行安全漏洞扫描
---

# /secguard — 安全加固项排查

对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 完整命令定义

Commands 加载了 `commands/secguard.md` 的完整命令定义。

## 可用检测器

C/C++: 30 个检测器覆盖 memory/concurrency/system/crypto 四大命名空间
Java/Python/Go: 语言专属的 Web 安全检测

请加载 `knowledge/protocols/scan-output.md` 了解输出格式。
请加载 `skills/secguard-cpp/references/detector-index.md` 查看完整检测器列表。
