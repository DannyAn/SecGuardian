# Command Injection — 误报抑制策略 (Go)

适用于 `go.injection.command` skill（CWE-78）。

## 策略 1: 分离参数确认

`exec.Command` 不经 shell 解释，参数不易注入。

**检查清单:**
- [ ] `exec.Command` 首个参数不是 `"sh"`/`"bash"`/`"zsh"`/`"cmd"`
- [ ] 不使用 `-c` 标志
- [ ] 所有参数都是独立字符串（非拼接的命令行字符串）

```go
exec.Command("ping", "-c", "1", hostname)         // ✅ 安全: 分离参数
exec.Command("sh", "-c", "ping -c 1 "+hostname)   // ❌ 危险: shell 模式
```

## 策略 2: 白名单确认

检查命令执行前是否有白名单校验。

```go
// 有白名单 — 确认白名单是否完整
allowedCommands := map[string]bool{"df": true, "free": true, "uptime": true}
if !allowedCommands[userInput] {
    return errors.New("command not allowed")
}
exec.Command(userInput)  // 白名单通过
```

## 策略 3: 参数硬编码确认

如果除第一个参数外所有参数均为常量字符串，即使第一个参数来自用户输入，风险也大幅降低。

```go
// 低风险: 仅命令名来自用户，参数固定
exec.Command(userInput, "--help")
exec.Command(userInput, "status")
```

## 策略 4: 管道和重定向检查

`exec.Command` 不经 shell，不支持 `|`、`>`、`<` 等 shell 操作符。即使参数包含这些字符也不会被解释。

```go
// 安全: shell 元字符不被解释
exec.Command("ls", userInput)  // userInput = "| rm -rf /" → ls 会查找叫该名字的文件
```

## 策略 5: 测试文件抑制

`_test.go` 完全抑制。

## 策略 6: 数值类型参数

参数经数值转换后风险降低（无法注入 shell 元字符）。

```go
port, err := strconv.Atoi(userPort)
exec.Command("curl", fmt.Sprintf("http://host:%d", port))  // 低风险
```
