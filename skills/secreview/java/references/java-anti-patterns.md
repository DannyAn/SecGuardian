# Java 安全反模式检测矩阵

代码审查中需要关注的 Java 特有安全反模式及具体检测规则。

## 异常处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `catch (Exception e) { }` 空块 | `catch\s*\(\s*\w+\s+\w+\s*\)\s*\{\s*\}` | Critical |
| `catch (Exception e) { e.printStackTrace(); }` | `catch.*\{[^}]*e\.printStackTrace\(\)` — 异常信息泄露 + 吞掉 | High |
| 日志含敏感异常信息 | `log\.\w+\(.*e\.getMessage\(\)\|log\.\w+\(.*e\.toString\(\)` | High |
| finally 块中 return | `finally\s*\{[^}]*\breturn\b` | Medium |

## 序列化反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `Serializable` 无 `serialVersionUID` | `implements\s+Serializable` 且类体中无 `serialVersionUID` | Medium |
| `ObjectInputStream.readObject` 无类型检查 | `readObject\(\)[^;]*;(?!.*instanceof\|\.getClass\(\).*equals)` | Critical |
| FastJson `parseObject` 无 `autoType` 限制 | `JSON\.parseObject\|JSONObject\.parseObject` 无 `ParserConfig` 安全配置 | Critical |
| Jackson `enableDefaultTyping` | `enableDefaultTyping\|ObjectMapper\(\)\.enableDefaultTyping` | Critical |

## 并发反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `synchronized(this)` | `synchronized\s*\(\s*this\s*\)` | Medium |
| Double-checked locking 错误 | `if\s*\(.*==\s*null.*\)\s*\{[^}]*synchronized[^}]*if[^}]*\}[^}]*\}` 中字段无 `volatile` | High |
| `ThreadLocal` 未清理 | `ThreadLocal\.(set\|initialValue)\(\)[^}]*` 且 `finally` 块无 `.remove()` | Medium |

## Spring 反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `@Autowired` 字段注入 | `@Autowired\s+\n\s+private\s+\w+` (字段注入而非构造器) | Medium |
| `@Transactional` 自调用 | 同类的 `@Transactional` 方法调用另一个 `@Transactional` 方法（非代理调用） | High |
| `SecurityContext` 跨线程丢失 | `new\s+Thread\(` 或 `ExecutorService` 提交中访问 `SecurityContextHolder` | Medium |
| `server.error.include-stacktrace=always` | `include-stacktrace\s*=\s*always\|include-message\s*=\s*always` | High |

## 加密反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| MD5/SHA-1 安全用途 | `MessageDigest\.getInstance\("MD5"\|"SHA-1"\)` 且上下文含 `pass\|auth\|sign` | High |
| AES-ECB 模式 | `Cipher\.getInstance\("AES/ECB\|"AES"\)` | High |
| 硬编码密码/密钥 | `static\s+(final\s+)?String\s+\w*(PASS\|SECRET\|KEY\|TOKEN)` 初始化为字符串字面量 | High |

## 错误处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 异常抛到 Controller 未处理 | `@(GetMapping\|PostMapping).*throws\s` — 无 `@ExceptionHandler` | Medium |
| 日志注入 (Log Injection) | `log\.\w+\(.*\+\s*(request\|input\|param\|user)` 含 CRLF 未过滤 | Medium |
| DEBUG 级别日志泄露 | `log\.debug\(.*(token\|password\|secret\|key)` | Medium |
