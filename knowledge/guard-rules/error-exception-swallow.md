---
confidence: dynamic
cwe: CWE-391
detector: error-exception-swallow
language: [c, cpp, java, python, go, js]
precision: very-high
severity: medium
tags: [error, exception, silent-failure, debugging]
---

# 异常吞掉 (Exception Swallow)

## 威胁定义 (Threat Definition)

检测捕获异常后不做任何处理（空 catch 块）或仅打印而不处理/传播，导致错误被静默忽略。这会造成安全隐患：安全检查失败被跳过、权限降级被忽略、加密操作失败后使用明文等。

## 检测逻辑 (Detection Logic)

### Step 1: 空 catch 块

```java
// BAD: 空 catch 块
try {
    SecurityManager.checkPermission(perm);
} catch (SecurityException e) {
    // 空块 — 安全检查被绕过!
}

// BAD: 仅有注释的空 catch
try {
    user = authService.authenticate(credentials);
} catch (AuthException e) {
    // TODO: handle later — 实际上永远没处理
}

// BAD: 仅 printStackTrace 不传播
try {
    encrypt(data, key);
} catch (CryptoException e) {
    e.printStackTrace();  // 加密失败被忽略，可能用明文继续!
}
```

### Step 2: Python 空异常处理

```python
# BAD: 空 except 块
try:
    check_permission(user, resource)
except PermissionError:
    pass  # 安全检查被静默绕过!

# BAD: 宽泛 except 不处理
try:
    sensitive_operation()
except Exception:
    pass  # 所有错误被吞掉

# BAD: 仅打印不传播
try:
    validate_token(token)
except InvalidTokenError:
    logger.debug("token invalid")  # 仅 debug 日志
    # 函数继续执行，未抛出异常!
```

### Step 3: C/C++ 错误码忽略

```c
// BAD: 忽略函数返回的错误码
int ret = pthread_mutex_lock(&mutex);
// ret 未被检查 — 锁失败被忽略!

// BAD: 安全检查返回值忽略
int rv = access(path, R_OK);
if (rv == -1) {
    // 空处理块或无 else
}
// 继续读取文件 — 权限检查被绕过!

// BAD: 信号处理函数忽略错误
signal(SIGTERM, handler);  // 返回值未检查

// BAD: 安全函数返回值忽略
if (SSL_accept(ssl) <= 0) {
    // 空处理或仅日志无 return/exit
}
```

### Step 4: Go — error 忽略

```go
// BAD: 使用 _ 忽略错误
token, _ := jwt.Parse(tokenString, keyFunc)  // 解析失败被忽略!
user, _ := auth.Authenticate(credentials)  // 认证失败被忽略!

// BAD: 仅 log 不 return
result, err := secureOperation(input)
if err != nil {
    log.Println(err)  // 仅打印，继续使用零值 result
}
process(result)  // result 可能为 nil/零值!

// BAD: err 被遮蔽
if err := validateInput(data); err != nil {
    log.Printf("validation: %v", err)
}
// err 作用域结束，但未返回 — 继续执行
```

### Step 5: JavaScript — Promise 错误忽略

```javascript
// BAD: Promise 未 catch
fetch('/api/secure').then(res => res.json());  // 网络/权限错误被忽略

// BAD: catch 空
secureOperation().catch(() => {});  // 错误被吞掉

// BAD: async/await 无 try-catch
async function handler() {
    const result = await insecureOperation();  // 异常未被捕获
    // ...
}

// BAD: Express 未 next(err)
app.get('/api/data', async (req, res, next) => {
    try {
        await db.query();
    } catch (err) {
        console.error(err);
        // 未调用 next(err)，请求挂起
    }
});
```

## 修复指引 (Remediation Guide)

1. 空 catch 块至少应包含明确的注释说明为什么可以忽略
2. 安全关键操作（认证、鉴权、加密）的异常必须传播或明确失败
3. 使用全局异常处理器统一记录和转换异常
4. Go 中 `if err != nil` 后必须 `return` 零值 + err

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `Thread.sleep()` 的 `InterruptedException` catch 有 `Thread.currentThread().interrupt()` | 正确恢复中断状态 | 确认 catch 块中调用了 `Thread.currentThread().interrupt()` |
| 资源清理 finally 块中的二次异常吞掉 | 有注释说明且不影响主逻辑 | 确认异常发生在 finally/defer 清理代码中，且主逻辑异常已正常传播 |
| `Optional.ifPresent()` 或类似模式 | 设计如此 | 确认使用 Optional/Maybe 等函数式容器，空值由容器语义处理 |
| Go 中 `defer` 函数内部错误不影响主流程 | 延迟清理场景 | 确认错误发生在 defer 块中，主返回值已正确设置 |
| 重试逻辑中特定异常允许吞掉 | 有重试机制且达到最大次数 | 确认存在明确的重试逻辑（循环 + 计数器），且达到最大重试次数后抛出 |
| 迭代器/`Closeable` 等框架要求的模式 | 标准模式 | 确认实现的是 Closeable/AutoCloseable/Iterator 等标准库接口 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: 空 catch
catch\s*\(.*\)\s*\{\s*\}                              → 完全空
catch\s*\(.*\)\s*\{\s*//.*\s*\}                        → 仅有注释
catch.*\{[^}]*\.printStackTrace\(\);[^}]*\}             → 仅打印不传播，且无 throw
→ MUST: code_context (catch 块及外层 try 代码)
→ MUST: judgment_rationale (捕获的异常类型是否为安全关键异常，吞掉后的安全影响)

# Python: 空 except
except\s+.*:\s*pass\s*$
except\s+.*:\s*#\s*\w+
except\s+Exception:.*\bpass\b

# C/C++: 返回值忽略
\w+\([^)]*\)\s*;  # 函数调用返回值未赋值 — 需要结合已知返回错误码的函数列表
SSL_accept|pthread_mutex_lock|access\s*\( — 返回值未检查

# Go: error 忽略
_,\s*_\s*:=.*\.Parse|Authenticate|Validate
if err != nil \{.*log\.Print.*\n[^}]*\}\s*\n[^r]  # 仅 log 未 return

# JS: Promise 未 catch / 空 catch
\.then\([^)]*\)$                                      → 无 .catch
\.catch\(\s*\(\)\s*=>\s*\{\s*\}\)                      → 空 catch

# === EXCLUDE (不报告) ===

→ Thread\.currentThread\(\)\.interrupt\(\)                                    # 正确恢复中断状态
→ finally\s*\{|defer\s+func|__exit__                                          # 资源清理 finally/defer
→ Optional\.ifPresent|\.map\(|\.orElse|\.flatMap\(                              # 函数式容器模式
→ for.*retry\|retries\+\+\|maxRetries\|retryCount                              # 重试逻辑
→ (implements|extends)\s+(Closeable|AutoCloseable|Iterator)                    # 标准框架接口
→ \/\/\s*(intentional|expected|safe to ignore|by design|deliberately)         # 有意忽略的注释
```
