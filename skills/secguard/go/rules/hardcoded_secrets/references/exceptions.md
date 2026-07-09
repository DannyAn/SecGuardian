# Hardcoded Secrets — 例外规则 (Go)

适用于 `go.crypto.secrets` skill（CWE-798）。

## 例外 1: 从环境变量读取

```go
// EXCEPTION: 正确做法 — 从环境变量读取
password := os.Getenv("DB_PASSWORD")
apiKey, ok := os.LookupEnv("API_KEY")
if !ok { log.Fatal("API_KEY not set") }
```

## 例外 2: Vault/KMS/Secret Store

```go
// EXCEPTION: 从密钥管理服务读取
client, _ := vault.New(vaultConfig)
secret, _ := client.Logical().Read("secret/data/db")
password := secret.Data["password"]
```

## 例外 3: 测试/示例占位符

`_test.go` 或示例程序中的占位字符串。

```go
// Test 文件 — 不报告
const testAPIKey = "sk-test-1234567890abcdef"
```

## 例外 4: 默认值/空值

```go
// EXCEPTION: 空值初始化
var dbPassword = ""
var apiKey string  // 零值
```

## 例外 5: 非敏感常量

```go
// EXCEPTION: 非敏感配置值 — 不是凭据
const companyName = "Acme Corp"
const appVersion = "1.0.0"
```

## 例外 6: URL 中的密码占位符

```go
// EXCEPTION: URL 中的密码占位符
dbURL := "postgres://user:password@localhost:5432/db"     // 替换为实际值
dbURL := "postgres://user:" + url.QueryEscape(os.Getenv("DB_PASS")) + "@localhost/db"
```
