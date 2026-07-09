---
name: secguard-java-log-injection
description: "检测 Java 日志注入 — 用户输入直接写入日志导致伪造日志条目或 CRLF 注入"
language: java
topic: [web, logging]
skill_id: java.log-injection.crlf
signal_source: call_sites[cat="logging"]
severity: medium
cwe: CWE-117
trigger_functions: [info, warn, error, debug, trace, log, LoggerFactory, LogManager, getLogger]
---

# log_injection 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.log-injection.crlf` | `call_sites[cat="logging"]` | `info`, `warn`, `error`, `debug`, `log` | Medium | CWE-117 |

## Scenario 1: 用户输入直接拼接到日志

### 威胁定义
攻击者将换行符（CRLF: `%0d%0a`）注入日志消息，伪造日志条目欺骗审核系统。Log4j / Logback / SLF4J 中用户输入直接拼接到格式化字符串即可实现。同时也可能泄露敏感信息（密码、Token）。

### 检测逻辑
```java
// BAD: 用户输入直接拼接到日志
log.info("User login failed: " + username);

// BAD: SLF4J 参数化但用户输入含换行
log.warn("Invalid input from user: {}", userInput);

// BAD: 敏感信息日志
log.error("Login failed, password was: " + password);

// GOOD: 用户输入无害化处理
String sanitized = userInput.replaceAll("[\\n\\r]", "_");
log.info("User login failed: {}", sanitized);

// GOOD: 仅记录不可变标识符
log.info("User login failed: userId={}", userId);
```

### 检测模式
**MATCH**: `log.info(.*user|.*password|.*token|.*input` + 字符串拼接 `+`；`log.warn|error|debug(.*+ ` 拼接用户输入

**EXCLUDE**: 日志消息已做 CRLF 替换（`replaceAll("[\\n\\r]", "_")`）；仅记录不可变标识符（userId / sessionId）；使用参数化占位符且参数已 sanitize

### 修复指引
1. 对用户输入做 CRLF 去除：`input.replaceAll("[\\n\\r]", "_")`
2. 避免日志中记录敏感信息（密码、Token、完整请求体）
3. 使用参数化日志（SLF4J `{}` 占位符）替代字符串拼接

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 日志调用行及参数来源 |
| judgment_rationale | MUST | 用户输入是否可能含 CRLF 或敏感数据 |
| data_flow_path | SHOULD | 用户输入到日志 API 的路径 |

## 输出格式
`[Medium][CWE-117] {file}:{line} — 日志注入（{logger}）`
