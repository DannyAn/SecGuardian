---
name: secaudit-input-validation
description: 审计用户输入的验证和净化逻辑，检测各类注入漏洞和不充分的输入校验，覆盖 OWASP Top 10 注入类风险
category: domain
topic: web
---

# 输入验证安全审计

## 审计概览

输入验证失败是注入类漏洞的根源（OWASP A03:2021）。审计覆盖所有外部输入点：
- **SQL 注入**：参数化 vs 拼接
- **命令注入**：shell 拼接
- **XSS**：反射/存储/DOM
- **路径穿越**：文件操作
- **LDAP/XML/XPath 注入**：其他解释器注入

## 审计流程

### Phase 1: 输入点枚举

```
HTTP 输入:
□ Query parameters (req.query, request.GET, $_GET)
□ POST body (JSON/XML/Form/Multipart)
□ URL path parameters (/users/:id → req.params.id)
□ HTTP headers (User-Agent, Referer, Cookie, X-Forwarded-For)
□ Cookie values

文件输入:
□ 文件上传的内容
□ 文件名、路径、MIME type
□ CSV/Excel/XML/YAML 导入

间接输入:
□ 数据库读取的值（可能被其他途径污染）
□ 环境变量
□ 配置文件
□ 消息队列消息
□ WebSocket/SSE 消息
```

### Phase 2: 检查清单

#### 2.1 SQL 注入

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否使用了参数化查询 | 检查所有 SQL 执行点是否使用占位符 (?/$1) |
| [C] | 动态表名/列名是否白名单校验 | ORDER BY、GROUP BY、表名无法参数化时必须白名单 |
| [C] | ORM 原生 SQL 是否安全 | JPA nativeQuery、MyBatis ${}、GORM Raw() |
| [H] | 存储过程是否安全 | 存储过程内部是否拼接 EXEC/EXECUTE IMMEDIATE |

#### 2.2 命令注入

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否使用参数数组代替 shell 字符串 | `exec(["cmd", "arg1"])` vs `exec("cmd arg1")` |
| [C] | 是否显式设置 shell=False/True | Python subprocess 默认行为 |
| [H] | 是否有 shell 元字符过滤 | `; | & $ \` \` " ' ( ) { } < > # ! ~ * ? [ ]` |

#### 2.3 XSS

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 输出是否经过上下文编码 | HTML 体/属性/URL/CSS/JS 不同编码规则 |
| [C] | 是否使用了不安全的 DOM API | innerHTML、document.write、eval |
| [H] | 富文本是否经过安全清洗 | DOMPurify/OWASP AntiSamy/CKEditor 配置 |
| [H] | CSP 是否作为纵深防御 | 检查 CSP 是否限制了 inline script |

#### 2.4 路径穿越

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 文件路径是否可被用户控制 | open(userFilename)、Path 来自请求参数 |
| [H] | 是否做了路径规范化 | realpath/canonicalize 后检查前缀 |
| [H] | 解压是否防护 Zip Slip | 验证每个 archive entry 的规范路径 |

#### 2.5 其他注入

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | LDAP 注入 | LDAP 查询是否转义了特殊字符 `* ( ) \ & \|` |
| [H] | XML 外部实体 (XXE) | XML Parser 是否禁用了 DOCTYPE/external entities |
| [H] | XPath 注入 | XPath 查询是否使用了参数化 |
| [M] | 模板注入 (SSTI) | 用户输入是否进入了模板引擎的模板而非数据位置 |
| [M] | 正则注入 (ReDoS) | 用户可控的正则表达式可能导致拒绝服务 |

### Phase 3: 常见漏洞模式

#### 模式 1: 参数化遗漏

```java
// BAD: 动态 ORDER BY 直接拼接——无法参数化但也没做白名单
String orderBy = request.getParameter("sort");
String sql = "SELECT * FROM users ORDER BY " + orderBy;  // SQL 注入!

// GOOD: 白名单校验
private static final Set<String> ALLOWED_COLUMNS = Set.of("id", "username", "email", "created_at");
String orderBy = request.getParameter("sort");
if (!ALLOWED_COLUMNS.contains(orderBy)) {
    throw new IllegalArgumentException("Invalid column: " + orderBy);
}
String sql = "SELECT * FROM users ORDER BY " + orderBy;
```

#### 模式 2: ORM 不安全使用

```python
# BAD: Django raw() 拼接
cursor.execute("SELECT * FROM users WHERE name = '%s'" % username)

# BAD: SQLAlchemy text() 拼接
session.execute(text(f"SELECT * FROM users WHERE name = '{username}'"))

# GOOD: ORM 安全 API
User.objects.filter(name=username)      # Django — 自动参数化
session.query(User).filter(User.name == username)  # SQLAlchemy
```

#### 模式 3: 二次注入

```sql
-- 第一次注入：注册时用户名包含恶意字符
INSERT INTO users (username) VALUES ('admin''--');

-- 第二次使用：读取用户名后未参数化使用
SELECT * FROM users WHERE username = 'admin'--';
-- 如果没有参数化，这个读取的值可能被解释为 SQL
```

#### 模式 4: URL 路径参数

```go
// BAD: 路径参数直接用于文件读取
http.HandleFunc("/files/", func(w http.ResponseWriter, r *http.Request) {
    filename := r.URL.Path[len("/files/"):]
    data, _ := ioutil.ReadFile("/var/data/" + filename)
    // 攻击: GET /files/../../../etc/passwd
})

// GOOD: 路径规范化 + 前缀验证
filename := filepath.Clean(r.URL.Path[len("/files/"):])
if strings.HasPrefix(filename, "..") {
    http.Error(w, "Invalid path", 400)
    return
}
data, _ := ioutil.ReadFile("/var/data/" + filename)
```

### Phase 4: 净化验证矩阵

| 输入上下文 | 危险 Sink | 有效净化 |
|-----------|----------|---------|
| SQL 值 | `execute(sql)` | 参数化查询 |
| SQL 标识符 | `ORDER BY col` | 白名单 |
| HTML 体 | `innerHTML` | `html.escape` |
| HTML 属性 | `setAttribute` | 属性值编码 |
| URL | `location.href` | URL 编码 + 协议白名单 |
| 系统命令 | `exec(cmd)` | 参数数组 (不经过 shell) |
| 文件路径 | `open(path)` | canonicalize + 前缀验证 |
| LDAP | `search(filter)` | LDAP 转义函数 |
