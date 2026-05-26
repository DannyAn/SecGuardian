---
detector: sql-injection
severity: critical
cwe: CWE-89
language: [java, go]
tags: [web, injection, database]
---

# SQL 注入检测 (Java / Go)

## 检测概要

检查 Java 和 Go 代码中是否将不可信数据拼接到 SQL 查询字符串中。

## 检测逻辑

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

### Step 2: Go — 搜索危险模式

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

### Step 3: 检查 ORDER BY / 动态列 (Java + Go)

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

## 误报排除

| 场景 | 原因 |
|------|------|
| PreparedStatement + setString (Java) | 参数化，安全 |
| `db.Query(query, args...)` 占位符 (Go) | 参数化安全 |
| MyBatis #{} / GORM Where("name = ?") | 参数化，安全 |
| 静态 SQL 字符串无外部输入 | 无注入路径 |
| ORDER BY 有白名单校验 | 已验证 |

## 检测模式汇总

```
# Java: Statement + 拼接
createStatement|executeQuery
→ SQL 字符串中含 + 或 String.format
→ MyBatis ${  (非 #{})

# Go: fmt.Sprintf 拼接到 SQL
fmt\.Sprintf.*SELECT|INSERT|DELETE|UPDATE
→ db\.Query|db\.Exec|db\.Raw (同一调用链)

# Go: GORM Raw/Exec 拼接
db\.Raw\(fmt\.Sprintf|db\.Exec\(fmt\.Sprintf

# 动态 ORDER BY/Group 无白名单
db\.Order\(|ORDER BY\s+\+
→ 参数来自外部 → 无白名单校验
```
