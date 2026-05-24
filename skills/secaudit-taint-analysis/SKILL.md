---
name: secaudit-taint-analysis
description: 通过污点传播追踪检测不可信数据是否未经净化到达危险操作点，发现注入类和安全敏感操作漏洞
category: analysis
---

# 污点分析 (Taint Analysis)

## 分析方法概述

污点分析是一种代码安全分析方法，核心思想是：**标记不可信数据源 → 追踪数据传播路径 → 检测是否到达危险操作点而未经过净化**。

适用场景：
- 检测 SQL 注入、命令注入、XSS 等注入类漏洞
- 验证用户输入在到达敏感操作前是否经过充分净化
- 发现隐式的数据依赖链——看起来安全但实际上来自不可信源的数据

## 分析流程

### Phase 1: 识别 Taint Source（污染源）

定位代码中所有外部数据入口：

```
用户输入:
□ HTTP 请求参数 (query, body, headers, cookies)
□ 文件上传内容
□ WebSocket 消息
□ CLI 参数 (argv, args)

外部数据:
□ 数据库查询结果 (跨系统数据不可信)
□ 第三方 API 响应
□ 环境变量
□ 消息队列消息
□ 配置文件（可被外部修改的）

间接输入:
□ 共享内存/缓存 (可能被其他进程污染)
□ 网络文件系统 (NFS/CIFS)
```

**关键原则**：不是只有用户输入才需要怀疑。任何来自系统边界之外的数据都应标记为污染源。

### Phase 2: 追踪传播路径

从每个 Source 出发，追踪数据经过的每一次赋值、函数调用、对象传递：

```python
# 示例传播链
username = request.GET['user']      # SOURCE: 用户输入污染 username
query = "SELECT * FROM users WHERE name = '%s'" % username  # PROPAGATION: query 被污染
cursor.execute(query)               # SINK: 污染数据到达危险操作
```

#### 传播规则

| 操作 | 传播行为 | 示例 |
|------|---------|------|
| 直接赋值 | 污染传播 | `b = a` (a 被污染 → b 被污染) |
| 字符串拼接/格式化 | 污染传播 | `s = f"Hello {user}"` (user 被污染 → s 被污染) |
| 数组/对象字段访问 | 污染传播 | `arr[0]` 被污染 → 取出值被污染 |
| 函数调用 | 污染传播到返回值 | `y = transform(x)` (x 被污染 → y 可能被污染) |
| 白名单校验 | **净化** | `if x in allowed_list: use(x)` (x 经过校验 → 安全) |
| 类型转换 | 部分净化 | `int(user)` (防止了注入，但可能仍不可信) |
| 显式转义/编码 | **净化** | `html.escape(user)` (XSS 净化后安全) |
| 参数化查询 | **Sink 安全** | `cursor.execute("SELECT ?", [user])` (user 不改变 SQL 语义) |

#### 跨函数传播分析

```
调用链:
  handler() → process_input(user) → build_query(user) → db.execute()
  
分析策略:
  1. 从 handler 开始，标记 user 为污染
  2. 追踪进入 process_input → 参数标记为污染
  3. 在 process_input 内追踪到 build_query 调用
  4. 在 build_query 内发现字符串拼接 → 确认污染未净化
  5. 追踪到 db.execute() → 确认到达 Sink
```

### Phase 3: 定位 Sink（危险操作点）

识别代码中所有安全敏感操作：

| Sink 类型 | 危险操作 | 示例 API |
|-----------|---------|---------|
| SQL 执行 | 数据库查询 | `cursor.execute`, `db.Query`, `Statement.execute` |
| 命令执行 | 系统命令 | `os.system`, `exec`, `Runtime.exec`, `proc.Start` |
| XSS 输出 | HTML 响应 | `response.write`, `innerHTML`, `document.write` |
| 文件操作 | 路径可控的文件读写 | `open(user_path)`, `fs.readFile` |
| 代码执行 | eval 类函数 | `eval`, `exec`, `ScriptEngine.eval` |
| 网络请求 | SSRF | `requests.get(user_url)`, `http.NewRequest` |
| 反序列化 | 对象还原 | `pickle.load`, `ObjectInputStream.readObject` |
| 权限操作 | 授权检查 | `setuid`, `sudo`, 文件权限变更 |

### Phase 4: 净化验证

对每个 Source → Sink 的路径，检查是否存在有效净化。

#### 有效的净化方式

| 威胁类型 | 有效净化示例 |
|---------|------------|
| SQL 注入 | 参数化查询 (`?` / `$1`)、ORM 安全 API、白名单 + 转义 |
| XSS | 上下文感知编码 (`html.escape`, `html/template`) |
| 命令注入 | 绕过 shell 的参数数组形式、白名单命令 |
| 路径穿越 | `canonicalize` + 前缀验证、UUID 映射 |
| LDAP 注入 | 专用 LDAP 转义函数 |

#### 无效的净化方式

| 常见错误 | 为什么无效 |
|---------|-----------|
| 仅黑名单过滤 | 总有遗漏的恶意字符 |
| 客户端仅校验 | 服务端信任了客户端数据 |
| `trim()` 后使用 | 不改变字符串的注入可能性 |
| `htmlspecialchars` 用于 JS 上下文 | 上下文不匹配 |
| 先拼接后净化 | 净化应用在字符串拼接之后无效 |

#### 净化不足的判断

```python
# BAD: 仅过滤了单引号，忽略其他注入方式
username = request.GET['user'].replace("'", "")
query = "SELECT * FROM users WHERE name = '%s'" % username

# BAD: 黑名单不完整
blacklist = ['<script>', 'javascript:']  # 总有绕过方法
clean = filter_blacklist(user_input)

# GOOD: 参数化查询
cursor.execute("SELECT * FROM users WHERE name = ?", (username,))
```

### Phase 5: 产出

#### 污点传播图

对每条 Source → Sink 的路径，输出传播链：

```
SOURCE: request.GET['user'] (HTTP query param)
  → user (local variable)
  → username = user.lower() (string method, taint preserved)
  → query = f"SELECT * FROM users WHERE name='{username}'" (f-string, taint preserved)
  → SINK: cursor.execute(query)

Verdict: VULNERABLE
  - Path: SOURCE → SINK (4 hops)
  - Sanitization: NONE
  - Vulnerability: SQL Injection (CWE-89)
  - Severity: Critical

Fix: cursor.execute("SELECT * FROM users WHERE name=?", (username,))
```

#### 安全的路径

```
SOURCE: request.GET['user']
  → user (local variable)
  → clean = html.escape(user)
  → SINK: response.write(f"<div>{clean}</div>")

Verdict: SAFE
  - Sanitization: html.escape() applied before sink
```

#### 需要人工审核的路径

```
SOURCE: request.GET['order_by']
  → order_col = WHITELIST[request.GET['order_by']]
  → SINK: cursor.execute(f"SELECT * FROM users ORDER BY {order_col}")

Verdict: NEEDS REVIEW
  - Sanitization: whitelist lookup, but sink requires concatenation
  - Risk: whitelist correctness is critical
```

## 跨语言 Taint Source/Sink 速查

详见 `references/taint-source-sink-reference.md`。

## 分析输出

1. **漏洞清单**：所有 Source → Sink 的未净化路径
2. **传播图**：每条漏洞路径的完整数据流
3. **安全路径确认**：已正确净化的路径（审计覆盖度证据）
4. **待审核清单**：使用了净化但需人工验证正确性的路径
