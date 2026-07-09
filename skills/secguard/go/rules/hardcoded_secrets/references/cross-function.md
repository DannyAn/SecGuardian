# Hardcoded Secrets — 跨函数追踪 (Go)

适用于 `go.crypto.secrets` skill（CWE-798）。max depth 1。

## 场景一: 硬编码凭据跨包使用

```go
package config

var DBPassword = "admin123"            // Source: 硬编码

package main

import "myapp/config"

func main() {
    db.Init(config.DBPassword)          // Sink: 使用硬编码凭据
}
```

## 场景二: 凭据通过初始化函数传入

```go
func initConfig() {
    apiKey = "sk-abcdef123456"           // Source
    initClients(apiKey)
}

func initClients(key string) {
    httpClient.DefaultHeader("Authorization", "Bearer "+key)  // Sink
}
```

## 深度限制

- 跨包引用（全局变量导出）也追踪
- 硬编码值在 `init()` 函数中赋值，然后被多个函数使用
