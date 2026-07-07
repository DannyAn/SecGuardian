---
detector: error-debug-mode-production
description: Detects debug mode, verbose logging, or development features enabled in production
severity: high
cwe: CWE-489
cvss: 6.5
language: [c, cpp, java, python, go, js]
tags: [error, debug, production, configuration]
precision: very-high
confidence: dynamic
target_functions: [code_context, debug_handler, func, get, morgan, next, open, read, render, require, run, set, status, system, use]
match_patterns: [DEBUG\s*=\s*True$, app\.run\(debug\s*=\s*True\), app\.config\[.DEBUG.\]\s*=\s*True, server\.error\.include-stacktrace\s*=\s*always, server\.error\.include-exception\s*=\s*true, management\.endpoints\.web\.exposure\.include\s*=\s*\*, spring\.jpa\.show-sql\s*=\s*true, assert\(                     → 安全相关断言的 assert 调用, system\(.*cmd                → 调试接口残留, net/http/pprof              → import (生产环境), gin\.SetMode\(gin\.DebugMode\) → Gin 调试模式, app\.set\(.env.,\s*.development.\), require\(.inspector.\)\.open\(\), morgan\(.dev.\) → 开发日志格式]
exclude_patterns: []
---

## 威胁定义 (Threat Definition)

检测生产环境配置中是否启用了调试模式或保留了调试接口。调试模式会暴露内部错误详情、路由信息、数据库查询、配置参数等敏感信息。

## 检测逻辑 (Detection Logic)

### Step 1: Python 框架调试模式

```python
# BAD: Django DEBUG=True
# settings.py - 生产环境
DEBUG = True  # Critical!

# BAD: Flask debug 模式
# app.py / wsgi.py
app.run(debug=True)  # 生产环境 Critical!
app.config['DEBUG'] = True
app.debug = True

# BAD: FastAPI debug
app = FastAPI(debug=True)  # 暴露内部错误详情

# BAD: 条件判断不严格
DEBUG = os.environ.get('DEBUG', 'True') == 'True'  # 默认 True!
```

**安全模式:**
```python
# GOOD: 生产环境明确关闭
DEBUG = os.environ.get('DJANGO_DEBUG', 'False') == 'True'  # 默认 False
# 或: DEBUG = False  # 生产设置显式声明
```

### Step 2: Java 框架调试模式

```java
// BAD: Spring Boot 详细错误
# application.properties
server.error.include-stacktrace=always   # 生产环境泄露堆栈
server.error.include-message=always      # 泄露错误消息
server.error.include-exception=true      # 泄露异常类型

// BAD: Spring Actuator 全开
management.endpoints.web.exposure.include=*  # 生产环境暴露所有端点!
management.endpoint.health.show-details=always

// BAD: Hibernate SQL 日志
spring.jpa.show-sql=true                 # 泄露 SQL 语句
logging.level.org.hibernate.SQL=DEBUG    # 泄露参数绑定

// BAD: Spring Security debug
logging.level.org.springframework.security=DEBUG  # 泄露安全配置
```

**安全模式:**
```properties
# GOOD: 生产环境配置
server.error.include-stacktrace=never
server.error.include-exception=false
management.endpoints.web.exposure.include=health,info
spring.jpa.show-sql=false
```

### Step 3: C/C++ 调试残留

```c
// BAD: 调试断言在生产代码中
assert(ptr != NULL);  // NDEBUG 未定义时生效，但信息泄露到 stderr
assert(user_level >= ADMIN);  // 安全相关的断言

// BAD: 调试输出未条件编译
#ifdef DEBUG
    printf("Secret key: %s\n", key);  // 如果误编译到生产版本
#endif

// BAD: 调试接口未移除
void debug_handler(int client_fd) {  // 开发时的调试接口
    char cmd[256];
    read(client_fd, cmd, sizeof(cmd));
    system(cmd);  // 极其危险!
}
```

**安全模式:**
```c
// GOOD: 生产环境编译标志
// Makefile: CFLAGS += -DNDEBUG  (关闭 assert)
// 调试接口使用 #ifdef DEBUG 包裹
// 代码审查确认调试接口未进入主分支
```

### Step 4: Go 调试残留

```go
// BAD: debug/pprof 暴露
import _ "net/http/pprof"  // 生产环境开放!
http.ListenAndServe(":6060", nil)  // pprof 端口暴露

// BAD: 详细错误信息
http.HandleFunc("/api", func(w http.ResponseWriter, r *http.Request) {
    // ...
    fmt.Fprintf(w, "Error: %+v", err)  // 堆栈泄露
})

// BAD: GIN debug 模式
gin.SetMode(gin.DebugMode)  // 而非 gin.ReleaseMode
```

### Step 5: JavaScript/Node.js 调试残留

```javascript
// BAD: Express 开发模式
app.set('env', 'development');  // 生产环境应为 'production'

// BAD: 调试中间件未移除
app.use(morgan('dev'));  // 开发日志格式
app.use((req, res, next) => { console.log(req.body); next(); });  // 调试中间件

// BAD: Node Inspector 暴露
require('inspector').open();  // 调试端口开放

// BAD: 详细错误页
app.use((err, req, res, next) => {
    res.status(err.status || 500);
    res.render('error', { error: err });  // 开发时详细错误页
});
```

**JavaScript 安全模式:**
```javascript
// GOOD: 生产环境检测
if (process.env.NODE_ENV === 'production') {
    app.set('env', 'production');
}
app.use(morgan('combined'));  // 仅访问日志
```

## 修复指引 (Remediation Guide)

1. 生产环境 `DEBUG=False`（Django）/ `app.run(debug=False)`（Flask）/ `app.set('env', 'production')`（Express）
2. Actuator 端点配置 Spring Security 权限保护
3. C/C++ 使用 `-DNDEBUG` 编译标志关闭 assert
4. 生产环境移除 `pprof` / `inspector` 调试端口

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `DEBUG = os.environ.get('DEBUG')` 且有部署文档说明生产为 False | 环境变量控制 | 确认环境变量默认值为 False 或有部署文档说明 |
| Actuator endpoints 配置了 Spring Security 权限保护 | 有认证保护 | 确认 Spring Security 配置保护了 actuator 路径 |
| 内部部署/测试环境配置（`application-test.properties`） | 非生产 profile | 确认文件名包含 test/dev/local 标识或 spring.profiles.active=test |
| `assert` 宏在编译时通过 `-DNDEBUG` 关闭 | 编译期移除 | 确认 Makefile/CMakeLists.txt 包含 -DNDEBUG 标志 |
| pprof 端口仅监听 localhost 且有防火墙保护 | 内部监控 | 确认监听地址为 127.0.0.1 或 ::1 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# Python
DEBUG\s*=\s*True$
app\.run\(debug\s*=\s*True\)
app\.config\[.DEBUG.\]\s*=\s*True
                                                       # → MUST: code_context (调试配置行+上下文)

# Java properties
server\.error\.include-stacktrace\s*=\s*always
server\.error\.include-exception\s*=\s*true
management\.endpoints\.web\.exposure\.include\s*=\s*\*
spring\.jpa\.show-sql\s*=\s*true

# C/C++
assert\(                     → 安全相关断言的 assert 调用
system\(.*cmd                → 调试接口残留

# Go
net/http/pprof              → import (生产环境)
gin\.SetMode\(gin\.DebugMode\) → Gin 调试模式

# JS/Node
app\.set\(.env.,\s*.development.\)
require\(.inspector.\)\.open\(\)
morgan\(.dev.\) → 开发日志格式

# === EXCLUDE (不报告) ===
→ DEBUG\s*=\s*False|debug\s*=\s*False                 # 显式关闭
→ os\.environ\.get\([^,]+,\s*['\"]False['\"]           # 默认 False 安全模式
→ NODE_ENV.*production|production.*NODE_ENV           # Node.js 生产环境
→ gin\.ReleaseMode|gin\.TestMode                       # Gin 非 Debug 模式
→ application-test\.|application-dev\.|application-local\.  # 非生产配置文件
→ -DNDEBUG|NDEBUG                                     # 编译期 assert 关闭
→ localhost|127\.0\.0\.1|::1.*pprof                     # pprof 仅监听本地
→ management\.endpoints\.web\.exposure\.include\s*=\s*health  # Actuator 最小暴露
```
