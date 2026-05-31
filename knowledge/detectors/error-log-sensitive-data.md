---
detector: error-log-sensitive-data
severity: high
cwe: CWE-532
language: [c, cpp, java, python, go, js]
tags: [error, logging, sensitive-data, privacy]
---

# 日志敏感数据泄露 (Log Sensitive Data Exposure)

## 威胁定义

检查日志语句中是否记录了密码、Token、API Key、证书、身份证号等敏感数据。日志系统保护通常较弱，一旦被攻击者获取，后果严重。

## 检测逻辑

### Step 1: 敏感字段名识别

检测日志语句中是否包含以下敏感字段名：

```
password, passwd, pass, pwd, secret, token, apiKey, api_key, API_KEY,
accessToken, access_token, refreshToken, refresh_token, jwt, JWT,
privateKey, private_key, secretKey, secret_key, encryption_key,
credential, credentials, authorization, auth, cookie, session,
ssn, social_security, creditCard, credit_card, cardNumber, card_number,
idCard, id_card, passport, bankAccount, bank_account,
pin, cvv, cvv2, security_code
```

### Step 2: 语言特定检测

**Java:**
```java
// BAD: 日志中记录敏感字段
log.info("User login: {}", user);  // user.toString() 可能包含 password
log.info("Password: {}", password);
log.debug("Token: {}", authToken);
log.info("Request body: {}", requestBody);  // body 可能包含敏感数据
logger.info("User object: " + user);  // 完整序列化

// BAD: 日志框架不安全配置
// logback.xml: <pattern>%msg%n</pattern> 未过滤敏感字段
// log4j2.xml: <PatternLayout pattern="%m%n"/> 无 RegexFilter
```

**Java 安全模式:**
```java
// GOOD: 日志脱敏
log.info("User login: {}", user.getUsername());  // 只记录用户名
log.info("Token used: {}", token.substring(0, 4) + "****");  // 部分脱敏
// logback.xml 配置 %replace{%msg}{password=[^,]+}{password=****}
```

**C/C++:**
```c
// BAD: syslog 记录敏感数据
syslog(LOG_INFO, "User auth with password: %s", password);
syslog(LOG_DEBUG, "JWT token: %s", jwt_token);
fprintf(log_file, "API key: %s, secret: %s", api_key, secret);

// BAD: 完整结构体 dump
syslog(LOG_INFO, "Config: %s", (char*)&config);  // 包含密钥字段
```

**C/C++ 安全模式:**
```c
// GOOD: 敏感字段不记录或打码
syslog(LOG_INFO, "User authenticated (method: %s)", auth_method);
// 不在日志中记录密钥内容
```

**Python:**
```python
# BAD: 敏感数据直接记录
logging.info(f"User {username} password: {password}")
logger.debug(f"Token: {api_key}")
logging.info(f"Request data: {request.data}")  # 包含敏感字段

# BAD: Django 日志配置记录所有请求体
# settings.py: LOGGING 配置中包含 request.body
```

**Python 安全模式:**
```python
# GOOD: 脱敏日志
import re
def sanitize(data):
    return re.sub(r'(password|token|secret)=[^&]+', r'\1=****', str(data))
logger.info(f"Request: {sanitize(request.data)}")
```

**Go:**
```go
// BAD: 敏感数据记录
log.Printf("User login: password=%s", password)
log.Printf("Token: %s", token)
logger.Info("request", zap.Any("body", body))  // 完整 body

// BAD: 结构体 dump 包含敏感字段
log.Printf("User: %+v", user)  // Password 字段被输出
```

**Go 安全模式:**
```go
// GOOD: 结构体自定义 String() 脱敏
type User struct {
    Username string
    Password string `json:"-"`  // 不序列化
}
log.Printf("User: %s logged in", user.Username)
```

**JavaScript/Node.js:**
```javascript
// BAD: 敏感数据记录
console.log('User login:', { username, password });  // password 明文记录
logger.info('Request body:', req.body);  // body 可能含敏感字段
winston.info('Token:', token);

// BAD: JSON.stringify 完整对象
console.log(JSON.stringify(user));  // password hash 被记录
```

**JavaScript 安全模式:**
```javascript
// GOOD: 自定义序列化脱敏
function sanitize(obj) {
    const { password, token, secret, ...safe } = obj;
    return safe;
}
logger.info('User action:', sanitize(req.body));
```

### Step 3: 日志注入检测

```java
// BAD: 用户输入直接拼入日志（CRLF 注入）
logger.info("User input: " + userInput);  // \r\n 伪造日志条目

// Python BAD:
logging.info(f"User said: {user_input}")  // 无换行过滤

// C/C++ BAD:
syslog(LOG_INFO, user_data);  // 直接使用用户数据

// Go BAD:
log.Printf("Input: %s", userInput)  // \r\n 日志污染
```

## 修复指引

1. 日志框架配置敏感字段过滤器（Logback `%replace`, Log4j `RegexFilter`）
2. 使用结构化日志 + 字段级别脱敏（`logger.info("login", {user: username})` 而非 `logger.info(user.toString())`）
3. 敏感字段命名规范（password/token/secret/key/credential）自动识别并打码
4. 日志写入前统一脱敏中间件/拦截器

## 误报排除

| 场景 | 原因 |
|------|------|
| 变量名为 password 但值是脱敏后的（如 `****`） | 已脱敏 |
| 日志框架已配置敏感字段 RegexFilter | 已配置过滤 |
| 测试代码/Mock 数据 | 非生产 |
| 日志输出到安全的审计系统（SIEM）非本地文件 | 有访问控制 |
| 加密后的数据（`encrypt(password)` 输出为密文字符串） | 已加密 |
| 仅记录布尔值/长度（`len(password) > 8`） | 非实际值 |

## 检测模式汇总

```
# 敏感字段名 + 日志调用
(log|logger|logging|syslog|printf|console\.log|console\.error|log\.Printf).*
→ (password|passwd|secret|token|apiKey|api_key|privateKey|private_key
   |creditCard|credit_card|ssn|social_security|cvv|pin)

# 完整对象序列化入日志
(logger|log)\.(info|debug|warn|error).*\+
log\.Printf.*%\+v            → 结构体含敏感字段

# CRLF 日志注入
(logger|syslog|log\.Printf|console\.log).*\+(?!\s*%s)
→ 用户输入生拼入日志字符串

# 框架特定
LOGGING.*request\.body       → Django settings
%msg.*%n                     → logback/log4j pattern 无过滤
```
