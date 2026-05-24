---
detector: java-sql-injection
severity: critical
cwe: CWE-89
language: [java]
tags: [web, injection, database]
---

# Java SQL 注入检测

## 检测概要

检查 Java 代码中是否将不可信数据拼接到 SQL 查询字符串中。

## 检测逻辑

### Step 1: 搜索危险 API

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

**安全模式:**
```java
// GOOD: PreparedStatement 参数化
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE name = ?");
ps.setString(1, username);

// GOOD: MyBatis #{} (参数化)
@Select("SELECT * FROM users WHERE name = #{username}")
User findUser(String username);

// GOOD: JPA Criteria API / JPQL 参数
Query q = entityManager.createQuery("SELECT u FROM User u WHERE u.name = :name");
q.setParameter("name", username);
```

### Step 2: 检查 ORDER BY / GROUP BY 动态字段

```java
// BAD: ORDER BY 字段来自用户输入
String orderBy = request.getParameter("sort");
String sql = "SELECT * FROM users ORDER BY " + orderBy;

// GOOD: 白名单校验
private static final Set<String> ALLOWED_COLUMNS = Set.of("id", "name", "email");
if (!ALLOWED_COLUMNS.contains(orderBy)) throw new IllegalArgumentException();
```

### Step 3: Hibernate/GORM 危险用法

```java
// BAD: Hibernate createSQLQuery 拼接
session.createSQLQuery("SELECT * FROM users WHERE name = '" + name + "'");

// BAD: JdbcTemplate 拼接
jdbcTemplate.queryForList("SELECT * FROM users WHERE name = '" + name + "'");
```

## 误报排除

| 场景 | 原因 |
|------|------|
| PreparedStatement + setString/setInt | 参数化，安全 |
| MyBatis #{} | 参数化，安全 |
| JPQL 命名参数 (:name) | 参数化，安全 |
| 静态 SQL 字符串无外部输入 | 无注入路径 |
| ORDER BY 有白名单校验 | 已验证 |

## 检测模式汇总

```
# Statement + 拼接
createStatement|executeQuery|executeUpdate
→ SQL 字符串中含 + 或 String.format 或 ${

# JPA nativeQuery 拼接
createNativeQuery|createQuery
→ 参数含字符串拼接

# MyBatis ${} 非参数化
@Select|@Update|@Delete
→ SQL 中含 ${  (非 #{)
```
