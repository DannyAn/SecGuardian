---
name: secguard-java-command-injection
description: "检测 Java 命令注入漏洞 — Runtime.exec 单字符串 / ProcessBuilder + shell / ProcessBuilder 命令含用户输入"
language: java
topic: [system, injection, shell]
skill_id: java.command-injection.exec
signal_source: call_sites[cat="exec"]
severity: critical
cwe: CWE-78
trigger_functions: [exec, ProcessBuilder, getRuntime]
---

# command_injection 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.command-injection.exec` | `call_sites[cat="exec"]` | `exec`, `ProcessBuilder`, `getRuntime` | Critical | CWE-78 |

## Scenario 1: 用户输入拼接到系统命令

### 威胁定义
攻击者通过用户输入拼接系统命令，导致服务器执行恶意 OS 命令。`Runtime.exec(String)` 单字符串形式会经 shell 解析（空格和特殊字符可注入额外命令）。`ProcessBuilder` 的参数列表形式更安全，但如果调用 shell（如 `cmd.exe /c` 或 `/bin/sh -c`）则同样危险。

### 检测逻辑
```java
// BAD: Runtime.exec 单字符串拼接
String cmd = "ping " + userInput;
Runtime.getRuntime().exec(cmd);  // userInput = "8.8.8.8; rm -rf /"

// BAD: ProcessBuilder + shell
ProcessBuilder pb = new ProcessBuilder("/bin/sh", "-c", "ping " + userInput);

// BAD: ProcessBuilder 命令名来自用户
ProcessBuilder pb = new ProcessBuilder(userInput, arg1, arg2);

// GOOD: Runtime.exec 字符串数组（绕过 shell）
Runtime.getRuntime().exec(new String[]{"/bin/ping", "-c", "1", validatedHost});

// GOOD: ProcessBuilder 非 shell 形式
ProcessBuilder pb = new ProcessBuilder("/bin/ping", "-c", "1", validatedHost);
```

### 检测模式
**MATCH**: `Runtime.getRuntime().exec(` 单字符串含外部变量拼接；`ProcessBuilder(` 含外部变量且含 `"/bin/sh"`/`cmd.exe"` 类参数

**EXCLUDE**: `exec(String[])` 或 `exec(cmd, null, null)` 以数组形式传递；`ProcessBuilder` 命令名为硬编码字面量且参数经白名单验证

### 修复指引
1. 首选：使用 API 替代命令调用（如 Java NIO 替代 ping/curl 系统命令）
2. 次选：`Runtime.exec(String[])` 数组参数绕过 shell 解析
3. 严格白名单：允许的命令和参数列表，shell 元字符正则校验

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 命令执行的完整代码及参数构造方式 |
| judgment_rationale | MUST | 用户输入是否可达命令字符串、shell 解析路径 |
| data_flow_path | SHOULD | 用户输入到命令执行的完整数据流 |
| sanitizer_analysis | SHOULD | 白名单 / 输入校验存在性分析 |

## 输出格式
`[Critical][CWE-78] {file}:{line} — 命令注入（{api}）`
