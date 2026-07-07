---
detector: error-stack-trace-leak
description: Detects exposure of stack traces or internal error details to end users
severity: high
cwe: CWE-209
cvss: 6.5
language: [c, cpp, java, python, go, js]
tags: [error, information-leakage, exception, production]
precision: very-high
confidence: dynamic
target_functions: [__FILE__, body, code_context, detail, err, errorhandler, failed, fprintf, func, getLogger, getMessage, getStackTrace, get_data, internal_error, json, jsonify, judgment_rationale, printStackTrace, query, res, route, send, set, stack, status, stderr, str, strerror, syslog, toString, use]
match_patterns: [catch.*Exception.*\{[^}]*return.*e\.(getMessage|toString|getStackTrace), e\.printStackTrace\(\)       → 调用链上下文, fprintf.*stderr|printf.*Error → __FILE__|strerror, assert.*&&.*"                  → 非 Debug 环境保留的断言, return.*str\(e\)|jsonify.*str\(e\)|detail=str\(e\), DEBUG\s*=\s*True              → settings.py, recover.*fmt\.Fprintf.*w     → HTTP handler 中, http\.Error.*err\.Error\(\)   → 错误详情返回, err\.stack|err\.message       → res\.send|res\.json 调用链, app\.set\('env',\s*'development'\)  → 生产环境标签]
exclude_patterns: []
---

## 威胁定义 (Threat Definition)

检查异常/错误处理代码是否将内部堆栈轨迹、错误详情泄露给终端用户或调用方。生产环境中的详细错误信息会暴露内部架构、文件路径、SQL 语句等敏感信息。

## 检测逻辑 (Detection Logic)

### Step 1: Java — 异常信息直接返回

```java
// BAD: 直接返回异常消息
try {
    // ...
} catch (Exception e) {
    return ResponseEntity.status(500).body(e.getMessage());  // 堆栈泄露!
}

// BAD: 打印堆栈后返回异常信息
catch (SQLException e) {
    e.printStackTrace();
    return "Database error: " + e.toString();  // 可能包含表名、SQL
}

// BAD: 异常传播到框架默认错误页面（Spring Boot Whitelabel）
// Spring Boot 未配置 server.error.include-stacktrace=never
```

**Java 安全模式:**
```java
// GOOD: 返回通用错误，记录详细日志
catch (Exception e) {
    logger.error("Operation failed for user {}", userId, e);  // 内部日志
    return ResponseEntity.status(500).body("Internal server error");  // 通用返回
}
```

### Step 2: C/C++ — 错误消息控制

```c
// BAD: 系统错误直接输出
fprintf(stderr, "Error: %s\n", strerror(errno));  // 可能暴露路径信息
printf("Failed: %s (file: %s:%d)\n", errmsg, __FILE__, __LINE__);  // 源码路径泄露

// BAD: 断言消息泄露内部状态
assert(user_count > 0 && "user array is empty");  // 断言在生产环境遗留
```

**C/C++ 安全模式:**
```c
// GOOD: 生产环境关闭断言，错误消息不包含路径
#ifdef DEBUG
    fprintf(stderr, "Error at %s:%d: %s\n", __FILE__, __LINE__, errmsg);
#else
    syslog(LOG_ERR, "Operation failed (code: %d)", error_code);
#endif
```

### Step 3: Python — 异常直接返回

```python
# BAD: Django/Flask 异常直接返回
@app.route('/api/data')
def get_data():
    try:
        result = db.query()
    except Exception as e:
        return jsonify({"error": str(e)}), 500  # 堆栈泄露!

# BAD: Django DEBUG=True 生产环境
# settings.py: DEBUG = True  → 详细的 Django 错误页面

# BAD: FastAPI 默认异常处理未覆盖
raise HTTPException(status_code=500, detail=str(e))  # detail 包含敏感信息
```

**Python 安全模式:**
```python
# GOOD: 生产环境错误处理
import logging
logger = logging.getLogger(__name__)

@app.errorhandler(500)
def internal_error(e):
    logger.error(f"Internal error: {e}", exc_info=True)  # 内部日志
    return jsonify({"error": "Internal server error"}), 500  # 通用返回
```

### Step 4: Go — panic/error 泄露

```go
// BAD: panic 信息返回给客户端
http.HandleFunc("/api", func(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if err := recover(); err != nil {
            fmt.Fprintf(w, "Error: %v", err)  // panic 堆栈泄露!
        }
    }()
})

// BAD: error 直接返回
fmt.Fprintf(w, "Query failed: %v", err)  // 可能包含 SQL/表名
```

**Go 安全模式:**
```go
// GOOD: 通用错误返回，内部日志
http.HandleFunc("/api", func(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if err := recover(); err != nil {
            log.Printf("PANIC: %v\n%s", err, debug.Stack())  // 内部日志
            http.Error(w, "Internal server error", 500)  // 通用返回
        }
    }()
})
```

### Step 5: JavaScript/Node.js — 堆栈泄露

```javascript
// BAD: Express 错误中间件直接返回堆栈
app.use((err, req, res, next) => {
    res.status(500).json({ error: err.stack });  // 完整堆栈泄露!
});

// BAD: 错误详情直接返回
res.status(500).send(err.message);  // 可能包含文件路径

// BAD: 生产环境未禁用详细错误
app.set('env', 'development');  // 生产环境 Express 应设为 'production'
```

**JavaScript 安全模式:**
```javascript
// GOOD: 统一错误处理
app.use((err, req, res, next) => {
    logger.error('Unhandled error', { error: err.message, stack: err.stack });
    res.status(500).json({ error: 'Internal server error' });
});
```

### Step 6: 框架配置检测

| 框架 | 危险配置 | 检测模式 |
|------|---------|---------|
| Spring Boot | `server.error.include-stacktrace=always` | 检查 application.properties |
| Spring Boot | `server.error.include-message=always` | 检查 application.properties |
| Django | `DEBUG = True` | settings.py |
| Flask | `app.run(debug=True)` | app.py/wsgi.py |
| Express | `app.set('env', 'development')` | server.js |
| Go net/http | 无 recover 或 recover 直接写响应 | 代码模式 |

## 修复指引 (Remediation Guide)

1. 统一错误响应格式，只返回通用错误码和用户友好消息
2. 敏感详细信息记录在服务端安全日志（ELK/Splunk）
3. 生产环境关闭调试模式和详细堆栈输出
4. 错误监控系统（Sentry/DataDog）确保错误不直接返回客户端

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 开发环境 `DEBUG=True` 且有条件编译/环境判断 | 仅开发环境 | 确认有环境判断逻辑（如 NODE_ENV/spring.profiles.active） |
| 内部 API 间 RPC 调用 | 非对外接口 | 确认 API 为内部服务间调用且无外部路由 |
| 错误日志系统（Sentry/Datadog）正常上报 | 非直接返回给用户 | 确认异常发送到日志系统而非 HTTP 响应体 |
| `debug` 包/模块仅导入但未启用 | 未激活 | 确认 import 但无实际调用或条件禁用 |
| 异常消息仅包含用户提供的输入信息 | 无内部信息泄露 | 确认错误消息中无文件路径/表名/内部类名 |
| 测试代码 (`*_test.go`, `*Test.java`, `test_*.py`) | 非生产 | 确认文件位于 test/ 目录或含测试框架注解 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Java: 返回异常消息
catch.*Exception.*\{[^}]*return.*e\.(getMessage|toString|getStackTrace)
e\.printStackTrace\(\)       → 调用链上下文
                                                       # → MUST: code_context (catch 块完整代码)

# C/C++: 错误信息包含内部路径
fprintf.*stderr|printf.*Error → __FILE__|strerror
assert.*&&.*"                  → 非 Debug 环境保留的断言

# Python: 返回 str(e)
return.*str\(e\)|jsonify.*str\(e\)|detail=str\(e\)
DEBUG\s*=\s*True              → settings.py

# Go: panic 写入 HTTP 响应
recover.*fmt\.Fprintf.*w     → HTTP handler 中
http\.Error.*err\.Error\(\)   → 错误详情返回

# JS/Node: 返回 err.stack
err\.stack|err\.message       → res\.send|res\.json 调用链
app\.set\('env',\s*'development'\)  → 生产环境标签
                                                       # → MUST: judgment_rationale (错误响应内容分析)

# === EXCLUDE (不报告) ===
→ logger\.error|log\.Printf|logging\.error             # 内部日志（非 HTTP 响应）
→ sentry|Sentry|datadog|DataDog|newrelic               # 错误监控系统上报
→ "Internal server error"|"Internal Server Error"       # 通用错误消息
→ @ExceptionHandler|@ControllerAdvice.*500             # 统一异常处理返回通用消息
→ spring\.profiles\.active\s*=\s*dev|test               # 非生产 profile
→ NODE_ENV.*development|development.*NODE_ENV          # 开发环境标记
→ test_|_test\.|@Test                                   # 测试代码
```
