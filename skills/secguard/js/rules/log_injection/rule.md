---
name: secguard-js-log_injection
description: "Detects log injection where user input containing newlines or special characters reaches logging functions"
language: javascript
topic: [log, injection, integrity]
skill_id: js.log_injection
signal_filter: js.log_injection*
signal_source: call_sites[category="log"]
severity: medium
cwe: [CWE-117]
trigger_functions: [console.log, console.error, logger.info, winston.log, bunyan.info, pino.info]
---

# log_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.log_injection` |
| signal_source | `call_sites[cat="log"]` |
| trigger_functions | `console.log(userInput)`, `winston.info(userInput)`, `pino.info(userInput)` |
| severity | Medium |
| CWE | CWE-117 |

## Scenario 1: 日志注入

### 威胁定义

攻击者通过在输入中嵌入换行符（`\n`）或特殊字符伪造日志记录，误导日志分析工具或注入恶意内容。可能导致日志注入后 XSS（浏览器查看日志时）或 SIEM 规则绕过。

### 检测逻辑

```javascript
// BAD: 直接记录用户输入
console.log('User login: ' + req.body.username);
// 攻击: username = "admin\n[INFO] Login successful from 127.0.0.1"

// BAD: 无换行过滤
logger.info(`Request from ${req.ip}, path=${req.path}`);

// GOOD: 过滤换行符或结构化日志
const sanitized = req.body.username.replace(/[\n\r]/g, '_');
console.log('User login: ' + sanitized);
// GOOD: 结构化日志，注入无害
logger.info({ username: req.body.username }, 'User login');
```

### 检测模式

```
# MATCH
console\.(log|error|warn)\(.*req\.|logger\.\w+\(.*req\.
winston|bunyan|pino.*req\.(body|query|params)
console\.log\(.*user|console\.log\(.*input

# EXCLUDE
\.replace\([/\\n\\r]/ 或 .*sanitize|.*escape   # 有换行过滤
logger\.(info|error|warn)\s*\(\{[^}]+\}        # 结构化日志（key-value 分离）
```

### 修复指引

1. 用户输入传入日志前过滤 `\n`/`\r` 换行符
2. 使用结构化日志（key-value 分离，注入无害）
3. 日志查看器设置 Content-Security-Policy 防止日志 XSS

## 证据收集指引

- **code_context**: 日志调用及传递的完整参数
- **judgment_rationale**: 用户输入是否以字符串拼接传入日志函数，是否有换行过滤

## 输出格式

三段式: Source（用户输入含换行符）→ Propagate（字符串拼接/模板字符串）→ Sink（console.log/logger.info）。
