# Java 安全速查表

SecGuard 快速参考：Java 常见漏洞模式速查。

## Top 10 检测信号

| # | 检测信号 | 严重度 | 关联概念 |
|---|---------|--------|---------|
| 1 | `ObjectInputStream.readObject()` 不受信输入 | Critical | deserialization |
| 2 | `Runtime.exec()` 参数含用户输入 | Critical | command-injection |
| 3 | `Statement.execute()` + 字符串拼接 | Critical | sql-injection |
| 4 | `FastJson.parseObject()` 未禁用 autoType | Critical | deserialization |
| 5 | `SnakeYAML.load()` 非 safeLoad | Critical | deserialization |
| 6 | XML Parser 未禁用外部实体 | High | xxe |
| 7 | `MessageDigest.getInstance("MD5")` | High | weak-cryptography |
| 8 | `new Random()` 安全用途 | High | weak-cryptography |
| 9 | `Paths.get(userInput)` 未做 canonicalize | High | path-traversal |
| 10 | `log.info(request.getParameter(...))` | Medium | logging-and-monitoring |

## Spring Security 常见问题

- `@PreAuthorize` 缺失或粒度不足
- CORS `allowedOrigins("*")` + `allowCredentials(true)`
- CSRF 被禁用但没有替代的 Token 验证
- Actuator `/heapdump`、`/env` 端点暴露

## 快速检查命令

当不确定某个 API 是否安全时，在代码上下文中搜索以下关键字：
- `password`, `secret`, `key`, `token`, `private` → 硬编码检查
- `exec`, `Runtime`, `ProcessBuilder` → 命令注入
- `Statement`, `createQuery`, `concat` → SQL 注入
- `readObject`, `parseObject`, `load` → 反序列化
