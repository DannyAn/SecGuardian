---
name: secguard-js-command_injection
description: "Detects OS command injection where user input reaches child_process shell execution"
language: javascript
topic: [injection, shell, system]
skill_id: js.command_injection
signal_filter: js.command_injection*
signal_source: call_sites[category="exec"]
severity: critical
cwe: [CWE-78]
trigger_functions: [child_process.exec, child_process.execSync, child_process.spawn({shell:true}), child_process.fork]
---

# command_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.command_injection` |
| signal_source | `call_sites[cat="exec"]` |
| trigger_functions | `exec()`, `execSync()`, `spawn({shell:true})`, `fork()` |
| severity | Critical |
| CWE | CWE-78 |

## Scenario 1: Shell 注入

### 威胁定义

攻击者通过用户输入拼接 shell 命令，导致服务器执行恶意操作系统命令。Node.js 的 `child_process.exec()` 和 `execSync()` 默认调用 shell 解析，最危险。

### 检测逻辑

```javascript
// BAD: exec 直接拼接用户输入
const { exec } = require('child_process');
exec('ping ' + req.query.host);  // 攻击: host = "8.8.8.8; rm -rf /"

// BAD: execSync 拼接
const result = execSync(`git log --format="%s" ${req.query.msg}`);

// BAD: spawn 开启 shell
spawn('sh', ['-c', req.body.command]);

// GOOD: execFile 参数数组
execFile('/bin/ping', ['-c', '4', validatedHost]);
```

### 检测模式

```
# MATCH
exec\(|execSync\(|execFile\(|spawn\(|fork\(
→ 参数中含 req\.|params\.|query\.|body\.
→ process\.env\.\w+
spawn\(.*shell\s*:\s*true

# EXCLUDE
exec(File|Sync)\(['"][^'"]*['"]\s*[\),]  # 硬编码命令
execFile\(['"][^'"]*['"],\s*\[            # 参数数组
\$\{.+\}.*execFile                        # 结构性参数
```

### 修复指引

1. 首选: 使用 `execFile()` 以参数数组形式调用，绕过 shell 解析
2. 次选: `spawn()` 默认 `shell: false` + 参数数组
3. 穷尽: 严格白名单 + 禁止 shell 元字符

## 证据收集指引

- **code_context**: 命令执行函数调用及其参数构造的完整代码
- **judgment_rationale**: 用户输入是否可达命令字符串，shell 元字符过滤完整性

## 输出格式

三段式: Source（req.query/req.body）→ Propagate（字符串拼接/模板字符串）→ Sink（exec/execSync/spawn）。
