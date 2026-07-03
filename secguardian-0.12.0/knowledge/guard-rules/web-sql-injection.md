---
detector: sql-injection
severity: critical
cwe: CWE-89
language: [c, cpp, java, go]
tags: [web, injection, database, embedded]
precision: very-high
confidence: dynamic
---

# SQL 注入检测 (C/C++ / Java / Go)

## 威胁定义 (Threat Definition)

攻击者通过构造恶意输入拼接 SQL 语句，导致数据库执行非预期的查询，获取、篡改或删除数据。覆盖 Web 后端 (Java/Go) 和嵌入式/桌面应用 (C/C++ SQLite)。

**核心原则：任何用户输入不得直接拼接到 SQL 语句中。**

## 检测逻辑 (Detection Logic)

### Step 1: Java — 搜索危险 API

**高危 — 字符串拼接 SQL:**
```java
// BAD: Statement + 拼接
String sql = "SELECT * FROM users WHERE name = '" + username + "'";
Statement stmt = conn.createStatement();
ResultSet rs = stmt.executeQuery(sql);

// BAD: PreparedStatement 的 SQL 仍是拼接的
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = '" + username + "'");

// BAD: JPA nativeQuery 拼接
Query q = entityManager.createNativeQuery("SELECT * FROM users WHERE name = '" + username + "'");

// BAD: MyBatis ${} (字符串替换，非参数化)
@Select("SELECT * FROM users WHERE name = '${username}'")
User findUser(String username);
```

**Java 安全模式:**
```java
// GOOD: PreparedStatement 参数化
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = ?");
ps.setString(1, username);

// GOOD: MyBatis #{} (参数化)
@Select("SELECT * FROM users WHERE name = #{username}")
User findUser(String username);
```

### Step 2: C/C++ — SQLite / ODBC / MySQL C API 注入

嵌入式开发中，C/C++ 常通过 SQLite 做本地持久化存储（IoT 设备、车载系统、桌面应用）。SQLite 和 MySQL/PostgreSQL C API 一样，如果用户输入未经参数化直接拼进 SQL，就会产生注入。

#### SQLite C API 危险模式

**模式 1：`sqlite3_mprintf` 格式化拼接（高危）**

```c
// BAD: sqlite3_mprintf 将用户输入直接格式化到 SQL 中
const char *user_name = get_user_input();
char *sql = sqlite3_mprintf(
    "SELECT * FROM users WHERE name = '%q'", user_name  // %q 只转义单引号，不防注入
);
sqlite3_exec(db, sql, NULL, NULL, NULL);
sqlite3_free(sql);

// BAD: 用 %s 完全不转义
char *sql = sqlite3_mprintf(
    "SELECT * FROM users WHERE name = '%s'", user_name  // '%s' 完全不安全！
);
```

**关键点**：`sqlite3_mprintf` 的 `%q` 会转义单引号（`'` → `''`），这是一种**有限的防护**，但不能替代参数化查询。攻击者绕过 `%q` 的已知方法包括：
- 如果后续有其他字符串拼接，转义可能被绕过
- `%s` 格式完全不转义
- `%w` 格式（SQLite 3.44+）相对安全，但仅限表名/列名白名单场景

**模式 2：`snprintf` / `sprintf` 手工拼接 + `sqlite3_exec`（极高危）**

```c
// BAD: 手工拼接 SQL
char sql[512];
snprintf(sql, sizeof(sql),
    "SELECT * FROM users WHERE name = '%s' AND password = '%s'",
    user_name, user_password);
sqlite3_exec(db, sql, callback, NULL, NULL);

// 攻击输入: user_name = "admin' --"
// 结果 SQL: SELECT * FROM users WHERE name = 'admin' --' AND password = 'xxx'
// → 绕过密码验证
```

**模式 3：`sqlite3_prepare_v2` 但仍手动拼接 SQL（高危）**

```c
// BAD: prepare 的 SQL 本身是拼接出来的
char sql[256];
snprintf(sql, sizeof(sql),
    "SELECT * FROM users WHERE name = '%s'", user_name);
sqlite3_stmt *stmt;
sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);  // SQL 已被污染
sqlite3_step(stmt);
```

#### SQLite C API 安全模式

```c
// GOOD: sqlite3_prepare_v2 + sqlite3_bind_* (参数化查询)
const char *sql = "SELECT * FROM users WHERE name = ?1 AND age > ?2";
sqlite3_stmt *stmt;
sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
sqlite3_bind_text(stmt, 1, user_name, -1, SQLITE_STATIC);  // 参数绑定
sqlite3_bind_int(stmt, 2, min_age);
sqlite3_step(stmt);
sqlite3_finalize(stmt);
```

**为什么安全**：`sqlite3_bind_*` 将值作为数据传递，而非 SQL 文本的一部分。值的类型和边界由 SQLite 内部处理，完全不受注入影响。

```c
// GOOD: sqlite3_bind_* 同样适用于 INSERT/UPDATE/DELETE
const char *sql = "INSERT INTO logs (msg, level) VALUES (?1, ?2)";
sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
sqlite3_bind_text(stmt, 1, user_msg, -1, SQLITE_STATIC);
sqlite3_bind_int(stmt, 2, LOG_WARNING);
sqlite3_step(stmt);
sqlite3_finalize(stmt);
```

#### 其他 C/C++ 数据库 API

| 数据库 | 危险 API | 安全 API |
|--------|---------|---------|
| MySQL C API | `mysql_query(conn, buf)` + 拼接 | `mysql_stmt_bind_param()` + prepared stmt |
| PostgreSQL libpq | `PQexec(conn, sql)` + 拼接 | `PQexecParams()` 参数化 |
| ODBC | `SQLExecDirect(stmt, sql, ...)` + 拼接 | `SQLBindParameter()` + `SQLPrepare()` |
| Oracle OCI | `OCIStmtExecute()` + 拼接 | `OCIBindByName()` 参数绑定 |

**检测原则**：对于任何 C/C++ 数据库 API，如果 SQL 字符串的构造路径经过 `snprintf`/`sprintf`/`strcat`/`strcpy` 等且参数来自外部输入，则报告 SQL 注入。

#### SQLite FTS5 全文搜索注入

SQLite FTS5 扩展用于全文搜索，其 MATCH 语法有特殊的注入风险：

```c
// BAD: FTS5 MATCH 拼接用户输入
char sql[512];
snprintf(sql, sizeof(sql),
    "SELECT * FROM docs WHERE docs MATCH '%s'", user_search);
sqlite3_exec(db, sql, ...);

// 攻击输入: user_search = "\"*\" OR 1=1"
// 或更危险的: user_search = "a\" OR content MATCH '\"password\"' --"
// → 可通过 MATCH 语法遍历、读取敏感列
```

**安全做法**：FTS5 的 MATCH 参数也必须通过 `sqlite3_bind_text` 绑定，或对输入做严格的白名单校验。

### Step 3: Go — 搜索危险模式

```go
// BAD: database/sql + fmt.Sprintf 拼接
query := fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username)
rows, err := db.Query(query)

// BAD: GORM Raw() + 拼接
db.Raw(fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", username)).Scan(&users)

// BAD: GORM Order 动态字段
db.Order(userSuppliedField).Find(&users)
```

**Go 安全模式:**
```go
// GOOD: 参数化查询
rows, err := db.Query("SELECT * FROM users WHERE name = $1", username)

// GOOD: GORM 链式调用
db.Where("name = ?", username).Find(&users)
```

### Step 4: 检查 ORDER BY / 动态列 (C/C++ / Java / Go)

**C/C++ 中的 ORDER BY 注入：**

```c
// BAD: ORDER BY 字段来自用户输入
char sql[256];
snprintf(sql, sizeof(sql),
    "SELECT * FROM users ORDER BY %s", user_sort_field);
sqlite3_exec(db, sql, ...);

// 攻击: user_sort_field = "(CASE WHEN password LIKE 'a%' THEN name ELSE id END)"
// → 可通过排序结果推断密码内容（盲注）
```

> ORDER BY / GROUP BY / LIMIT 等 SQL 子句通常**无法用参数化绑定**（绑定只支持值，不支持标识符），必须用**白名单校验**。

```java
// Java BAD: ORDER BY 字段来自用户输入
String orderBy = request.getParameter("sort");
String sql = "SELECT * FROM users ORDER BY " + orderBy;
```

```go
// Go BAD: GORM Order 无白名单
db.Order(userSuppliedField).Find(&users)
```

```java
// GOOD: 白名单校验
Set<String> ALLOWED = Set.of("id", "name", "email");
if (!ALLOWED.contains(orderBy)) throw new IllegalArgumentException();
```

```go
// GOOD: 白名单校验
var allowed = map[string]bool{"id": true, "name": true}
if !allowed[orderBy] { return errors.New("invalid") }
db.Order(orderBy).Find(&users)
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：SQL 查询构建的完整代码，包含 SQL 字符串的构造路径（拼接方式/来源变量）、数据库执行 API（createStatement/sqlite3_exec/sqlite3_prepare_v2/db.Query）及参数绑定状态
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析 SQL 字符串从构造到执行的完整路径——是否存在参数化绑定（PreparedStatement/sqlite3_bind_*/db.Query args）；若使用拼接，分析是否所有拼接片段均可信（硬编码/内部枚举）；判断拼接操作符、格式化函数与执行 API 之间的数据流是否闭合；对于 sqlite3_mprintf("%q") 仅转义模式，分析是否存在二次拼接或绕过路径
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入 → 字符串拼接/格式化（sprintf/fmt.Sprintf/String.format/+）→ SQL 语句 → 执行 API（sqlite3_exec/db.Query/createStatement/executeQuery）的完整数据流，标注每层是否经过了参数化或转义处理
      → findings.evidence.data_flow_path
- [ ] **call_stack**：Controller/Handler → Service → DAO/Repository 的完整调用链（Java/Go）；或函数调用链从输入获取到数据库 API 调用（C/C++），确认每一层的 SQL 构建方式及是否使用了参数化查询
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：用户输入值、SQL 字符串最终形态、数据库 API 类型（Statement/PreparedStatement/sqlite3_exec/sqlite3_prepare_v2）、占位符绑定状态、格式化函数说明符（%s/%q/%w）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在 ORM 层安全 API（GORM Where("name = ?")/MyBatis #{}）、输入校验/白名单（ORDER BY 允许字段列表）、WAF 级 SQL 过滤；sqlite3_mprintf 的 %q 转义是否在同一作用域内且无后续二次拼接；FTS5 MATCH 参数是否经过绑定或严格白名单校验
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **首选**：使用参数化查询（PreparedStatement / sqlite3_prepare_v2 + sqlite3_bind_*）
2. **次选**：ORM 安全 API（非原生 SQL 接口）
3. **不得已时**：输入校验 + 白名单过滤（ORDER BY/GROUP BY 等无法参数化的子句）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `sqlite3_prepare_v2` + `sqlite3_bind_*` (C) | 参数化查询，安全 | 确认 prepare_v2 的 SQL 为静态字符串字面量，且 bind 绑定所有用户输入 |
| `PQexecParams()` / `mysql_stmt_bind_param()` (C) | 参数化，安全 | 确认使用参数绑定 API 且 SQL 模板不含拼接 |
| PreparedStatement + setString (Java) | 参数化，安全 | 确认 SQL 模板为静态字符串，所有变量通过 setXxx 绑定 |
| `db.Query(query, args...)` 占位符 (Go) | 参数化安全 | 确认 query 为静态字符串，args 覆盖所有动态值 |
| MyBatis #{} / GORM Where("name = ?") | 参数化，安全 | 确认使用 #{} 而非 ${}，Where 使用 ? 占位符 |
| `sqlite3_mprintf("%q", val)` — 仅转义单引号 | 不视为安全，仍需报告（非参数化） | 确认仅有 %q 转义，无参数化绑定 |
| 静态 SQL 字面量字符串无外部输入 | 无注入路径 | 确认 SQL 字符串为编译期常量，无任何运行时拼接 |
| ORDER BY 有白名单校验 | 已验证 | 确认存在白名单集合且字段名来自内部枚举 |
| 表名/列名来自内部枚举，非用户输入 | 无注入路径 | 确认标识符来源为硬编码映射或内部配置 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# C/C++ SQLite: snprintf/sprintf + sqlite3_exec
(snprintf|sprintf|strcat|strcpy).*SELECT|INSERT|DELETE|UPDATE
→ sqlite3_exec|sqlite3_prepare_v2 (同一调用链)
→ 排除 sqlite3_bind_text|sqlite3_bind_int|sqlite3_bind_* 在同一作用域
                                                       # → MUST: code_context (SQL构造链完整代码)

# C/C++ SQLite: sqlite3_mprintf 直接拼接
sqlite3_mprintf.*SELECT|INSERT|DELETE|UPDATE
→ 检查是否使用 %s (完全不安全) 或 %q (仅转义，仍报告)

# C/C++ 其他 C API
PQexec|mysql_query|SQLExecDirect
→ SQL 字符串来自拼接|外部输入

# Java: Statement + 拼接
createStatement|executeQuery
→ SQL 字符串中含 + 或 String.format
→ MyBatis \${  (非 #{})
                                                       # → MUST: judgment_rationale (拼接路径+参数化分析)

# Go: fmt.Sprintf 拼接到 SQL
fmt\.Sprintf.*SELECT|INSERT|DELETE|UPDATE
→ db\.Query|db\.Exec|db\.Raw (同一调用链)

# Go: GORM Raw/Exec 拼接
db\.Raw\(fmt\.Sprintf|db\.Exec\(fmt\.Sprintf

# 动态 ORDER BY/Group 无白名单 (所有语言)
ORDER BY|GROUP BY|LIMIT\s+\+
→ 参数来自外部 → 无白名单校验

# FTS5 MATCH 注入 (C/C++)
MATCH\s+'.*\+|snprintf.*MATCH
→ 用户输入拼接到 MATCH 表达式中

# === EXCLUDE (不报告) ===
→ sqlite3_bind_text|sqlite3_bind_int|sqlite3_bind_value  # SQLite 参数绑定
→ PQexecParams|mysql_stmt_bind_param|SQLBindParameter    # 其他 C API 参数化
→ PreparedStatement.*setString|\.setInt|\.setLong         # Java PreparedStatement
→ #\{|Where\(.*\?|Where\(.*\$\d+                         # MyBatis #{} / GORM ? / Go $1
→ Set\.of\(|ALLOWED.*contains|allowed\[.*\]               # ORDER BY 白名单校验
→ static final String SQL|const char \*sql = "             # 静态 SQL 字面量
```
