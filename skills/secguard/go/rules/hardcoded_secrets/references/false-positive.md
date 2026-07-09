# Hardcoded Secrets — 误报抑制策略 (Go)

适用于 `go.crypto.secrets` skill（CWE-798）。

## 策略 1: 环境变量确认

确认代码中未从 `os.Getenv`/`os.LookupEnv` 读取对应配置。

**检查清单:**
- [ ] 代码中该变量是否有对应的 `os.Getenv` 调用？
- [ ] 是否有 `.env` 文件或环境变量配置文档？
- [ ] 是否使用了配置管理工具（viper, envconfig）？

## 策略 2: 变量名语义分析

```go
var defaultPassword = "changeme"     // 默认值 — 低风险
var exampleAPIKey = "sk-your-key"   // 示例 — 低风险
var dbPassword = "P@ssw0rd123"      // 硬编码 — 高风险
```

## 策略 3: 长度过滤

短字符串（<8 字符）作为密钥的可能性较低。

## 策略 4: 测试文件抑制

## 策略 5: 上下文分析

检查变量声明位置:
- `const` block 中的值比 `var` block 中的值风险更高（不可变）
- `init()` 函数中设置的值不如 main() 中从环境变量读取的值安全
