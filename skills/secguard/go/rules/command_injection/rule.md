---
name: secguard-go-command-injection
description: "Detect OS command injection via exec.Command shell mode — user input passed to shell execution produces arbitrary command execution"
language: go
topic: [web, exec]
skill_id: go.injection.command
signal_filter: go.injection.command*
signal_source: call_sites[category="*"]
severity: critical
cwe: [CWE-78]
trigger_functions: [exec.Command, exec.CommandContext, os.StartProcess]
---

# command_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `go.injection.command` |
| signal_filter | `go.injection.command*` |
| signal_source | `call_sites[category="*"]`（全量加载） |
| trigger_functions | `exec.Command`, `exec.CommandContext` 含 `"sh", "-c"` 模式，或参数来自用户输入 |
| 默认严重度 | Critical |
| CWE | CWE-78 (OS Command Injection) |
| Guard-rule | `system-command-injection` |

## Scenario 1: exec.Command shell 注入

### 威胁定义

Go 中 `exec.Command("sh", "-c", userInput)` 通过 shell 执行命令时，用户输入中的 shell 元字符（`;`, `|`, `` ` ``, `$`, `&` 等）可被攻击者利用执行任意命令。即使不使用 shell，`exec.Command(cmd, args...)` 中如果 args 来自不受信源，也可通过参数注入影响程序行为。

**核心原则：用户输入不得拼接到命令字符串中通过 shell 执行。** 始终使用 `exec.Command(cmd, args...)` 的分离参数形式。

### 检测逻辑

```go
// 脆弱 — shell 模式
exec.Command("sh", "-c", fmt.Sprintf("ping %s", userInput))

// 脆弱 — args 来自用户
exec.Command("ping", userInput)

// 安全 — 分离参数 + 白名单
exec.Command("ping", "-c", "1", validatedHost)

// 安全 — 绝对路径 + 参数数组
exec.Command("/usr/bin/ping", "-c", "1", "8.8.8.8")
```

### 检测模式

```
# MATCH（触发检测）
→ exec.Command("sh", "-c", *user*) — shell 模式
→ exec.Command("bash", "-c", *user*) — shell 模式
→ exec.Command(cmd, args...) 且 args 来自 HTTP request / os.Args / user input
→ os.StartProcess(path, argv) 且 argv 含用户输入

# EXCLUDE（不报告）
→ exec.Command 使用分离参数且所有参数来自白名单或常量
→ exec.CommandContext 使用硬编码常量参数
→ os.StartProcess 使用绝对路径 + 硬编码参数
```

### 修复指引

1. 使用 `exec.Command(cmd, args...)` 分离参数形式，不经过 shell
2. 对命令和参数做白名单校验
3. 避免使用 `"sh", "-c"` 模式；如必须使用，对用户输入做严格的 shell 元字符转义

---

## Scenario 2: 间接命令执行

### 威胁定义

通过 `os/exec` 的 LookPath 或间接 shell 执行（如 SQL 注入 → xp_cmdshell）绕开直接检测，或在 container/CI 环境中的动态编译执行。

### 检测逻辑

```go
// 脆弱 — LookPath + 用户可修改的路径
path, _ := exec.LookPath(userProvidedCmd)
cmd := exec.Command(path, args...)

// 脆弱 — 动态命令构造
cmd := exec.Command("/bin/sh")
cmd.Stdin = strings.NewReader(userInput)
```

### 检测模式

```
# MATCH（触发检测）
→ exec.LookPath 参数来自用户
→ exec.Command 的 Stdin 含用户输入的 shell 命令
→ syscall.Exec / syscall.ForkExec 参数来自用户
```

### 修复指引

1. `exec.LookPath` 不要信任用户提供的程序名
2. 通过分离参数而非 shell 重定向或管道来传递用户输入

---

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | exec.Command 调用点及前后 3 行，标注参数来源 |
| judgment_rationale | MUST | 用户输入是否经过 shell；是否有白名单/验证 |
| data_flow_path | SHOULD | 用户输入入口 → 命令执行点的完整路径 |
| call_stack | MAY | 调用链确认跨函数数据传递 |

## 输出格式

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 定义的输出契约。
