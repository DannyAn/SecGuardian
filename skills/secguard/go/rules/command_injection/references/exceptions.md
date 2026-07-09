# Command Injection — 例外规则 (Go)

适用于 `go.injection.command` skill（CWE-78）。

## 例外 1: exec.Command 分离参数模式

`exec.Command(cmd, args...)` 直接调用操作系统 API（execve），不经过 shell 解析。参数中的特殊字符不会被解释为 shell 元字符，不易注入。

```go
// EXCEPTION: 分离参数 — 不经 shell，无注入风险
exec.Command("ls", "-l", userProvidedFilename)
exec.Command("git", "log", "--oneline", "-n", "10")
exec.Command("echo", userInput)              // echo 打印原样，无注入
```

**但注意**: 若分离模式下仍存在风险（如 `--flag=value` 格式的参数注入），不在此例外范围内，由 `api_semantic_misuse` skill 覆盖。

## 例外 2: 硬编码命令和参数

命令名和全部参数均为编译期常量，不来自用户输入。

```go
// EXCEPTION: 全常量 — 安全
out, _ := exec.Command("date").Output()
exec.Command("mkdir", "-p", "/tmp/backup").Run()
cmd := exec.Command("cp", "-a", src, dst)     // src/dst 也是常量
```

## 例外 3: 白名单命令名

用户输入仅在白名单中选取命令名，且无额外参数。

```go
// EXCEPTION: 白名单限制
allowed := map[string]bool{"ping": true, "traceroute": true, "nslookup": true}
cmd := r.URL.Query().Get("cmd")
if !allowed[cmd] {
    http.Error(w, "invalid command", 400)
    return
}
exec.Command(cmd)  // 仅白名单命令
```

## 例外 4: os.StartProcess 低层级调用

`os.StartProcess` 不经 shell，属性名参数模式。

```go
// EXCEPTION: StartProcess 不经 shell
attr := &os.ProcAttr{Files: []*os.File{os.Stdin, os.Stdout, os.Stderr}}
proc, err := os.StartProcess("/usr/bin/myapp", []string{"myapp", arg1, arg2}, attr)
```

## 例外 5: 测试代码

`_test.go` 文件中的命令执行完全抑制。

## 例外 6: Docker/K8s exec 管理接口

容器管理平台中的 exec 调用（如 Docker API exec/create），虽然名称为 `exec`，但不是 OS 命令执行。

```go
// EXCEPTION: Docker exec API — 非 shell 执行
cli.ContainerExecCreate(ctx, containerID, types.ExecConfig{Cmd: []string{"ls"}})
```
