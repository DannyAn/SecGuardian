# Command Injection — 跨函数追踪 (Go)

适用于 `go.injection.command` skill（CWE-78）。max depth 1。

## 场景一: HTTP 参数 → shell 命令

```go
func adminHandler(w http.ResponseWriter, r *http.Request) {
    cmd := r.URL.Query().Get("cmd")          // Source
    executeShell(cmd)                           // 传入执行函数
}

func executeShell(command string) {
    out, _ := exec.Command("sh", "-c", command).Output()  // Sink: shell 执行
    fmt.Fprintf(w, "Result: %s", out)
}
```

## 场景二: 环境变量 → 命令参数

```go
func init() {
    dbHost := os.Getenv("DB_HOST")            // Source: 环境变量
    startService(dbHost)
}

func startService(host string) {
    out, _ := exec.Command("sh", "-c", "ping "+host).Output()  // Sink
}
```

## 场景三: 文件内容 → 命令执行

```go
func loadConfig(path string) error {
    data, _ := os.ReadFile(path)
    cmd := strings.TrimSpace(string(data))     // Source: 文件内容
    return runCmd(cmd)
}

func runCmd(c string) error {
    cmd := exec.Command("bash", "-c", c)       // Sink
    return cmd.Run()
}
```

## 场景四: WebSocket/SSE 实时命令

```go
func wsHandler(conn *websocket.Conn) {
    _, msg, _ := conn.ReadMessage()            // Source: WebSocket
    shellExec(string(msg))
}

func shellExec(cmd string) {
    exec.Command("/bin/sh", "-c", cmd).Run()   // Sink
}
```

## 深度限制

- max depth 1: 追踪从 Source 到 Sink 的一层调用链
- executor.Command → sh -c → 命令 路径即使在同一函数也要确认参数来源
- 深度超过 1 的报告降级为 suspicious

## 跨函数追踪难点

- Go 的 `exec.Command("sh", "-c", userInput)` 是最危险的模式（shell 注入）
- `exec.Command(program, args...)` 分离参数模式一般安全，需确认 args 中不含 `--flag=value;rm -rf /` 类参数注入
- `os/exec` 的 `Output()`/`CombinedOutput()`/`Run()` 是执行触发点，但命令构造早在之前完成
