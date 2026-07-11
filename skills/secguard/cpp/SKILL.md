---
name: secguard-cpp
description: 对 C/C++ 代码进行安全加固检视，覆盖内存安全、并发、系统 API、资源管理和语义误用。当用户请求 C/C++ 安全扫描、内存安全检测、缓冲区溢出、指针安全或 C++ 代码审计时使用。
category: language-specific
language: cpp
topic: [memory, concurrency, system, io, security, semantics]
---

# C/C++ 安全加固检视

本文件是 C/C++ 语言入口，只提供语言范围和参考资料。它不定义运行时调度、规则清单、阶段顺序、工件路径或判决状态。

## Runtime Contract

- 共享调度契约唯一位于 `$SECGUARDIAN_HOME/knowledge/protocols/dispatch-protocol.md`。
- `rules/*/rule.md` frontmatter 是唯一规则注册表，拥有 `skill_id`、`signal_source`、severity 和 CWE。
- `partition-signals.py` 动态发现规则并生成稳定的 `rule_id + batch_id + signal_id` provenance。
- partition 失败后禁止改为 LLM 自行全库扫描；索引器未产出的信号类型必须作为 blind spot 报告。
- detector-specific 场景、证据标准、Q1-Q3 和安全变体只由对应 `rule.md` 及其本地 `references/` 拥有。

依赖方向固定为：

```text
platform command -> dispatch protocol -> rules/*/rule.md -> rule-local references/*
```

本文件不回指任何平台 command，避免 Claude/OpenCode/Gemini 之间形成循环依赖。

## C/C++ Scope

调查时优先使用 index 中真实存在的事实：函数与类型符号、call sites、call graph、alloc/free、锁使用以及其他已产出的语义信号。不存在于 index schema 的 CFG、DFG 或类型事实不得假定存在，也不得标记为“引擎确认”。

## Language References

| 文件 | 内容 |
|------|------|
| [`references/cpp-security-cheatsheet.md`](./references/cpp-security-cheatsheet.md) | C/C++ 高风险 API 与安全替代方式 |
| [`references/language-features.md`](./references/language-features.md) | 自定义分配器、编译器标志和 C++ 特有语义 |
| [`references/examples/`](./references/examples/) | 非规范性示例；输出格式以全局 scan-output protocol 为准 |
