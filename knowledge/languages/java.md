---
category: language
languages: [java, kotlin, scala]
frameworks: [Spring, Spring Boot, Jakarta EE, MyBatis, Hibernate, Apache Shiro]
---

# Java 语言安全画像

Java 平台的安全特性、危险 API 清单和常见反模式。

## 危险 API 清单

### 命令执行
| API | 风险 | 替代 |
|-----|------|------|
| `Runtime.getRuntime().exec(cmd)` | Shell 注入（单字符串形式） | 使用字符串数组参数 |
| `ProcessBuilder(cmd)` | Shell 注入（如果调用 shell） | 直接调用命令，不用 shell |
| `ScriptEngine.eval(script)` | 脚本注入 | 沙箱执行 |

### SQL
| API | 风险 | 替代 |
|-----|------|------|
| `Statement.execute(sql)` | SQL 注入 | PreparedStatement |
| `String.format` + SQL 拼接 | SQL 注入 | 参数化查询 |
| `MyBatis ${}` 参数替换 | SQL 注入 | 使用 `#{}` 参数化 |
| `JPA nativeQuery 拼接` | SQL 注入 | JPQL 参数化 / Criteria API |
| 动态 ORDER BY/表名 | SQL 注入 | 白名单校验 |

### 反序列化
| API | 风险 | 替代 |
|-----|------|------|
| `ObjectInputStream.readObject()` | RCE 反序列化 | 类型白名单 + 签名验证 |
| `FastJson.parseObject(json)` | 任意类实例化 | 禁止 @type 指定 / 关闭 autoType |
| `Jackson enableDefaultTyping` | 多态类型注入 | 禁用默认类型 / 白名单 |
| `XStream.fromXML(xml)` | 反序列化执行 | 类型限制 Permission |
| `SnakeYAML.load(input)` | 类型注入 | 使用 safeLoad / Constructor 限制 |

### XML 处理
| API | 风险 | 替代 |
|-----|------|------|
| `DocumentBuilder` 未配置 | XXE | 禁用 DOCTYPE / 外部实体 |
| `SAXParser` 未配置 | XXE | 同上 |
| `TransformerFactory` 未配置 | XSLT 注入 | 安全配置 |

### 文件操作
| API | 风险 | 替代 |
|-----|------|------|
| `Paths.get(userInput)` 直接使用 | 路径穿越 | 先 getCanonicalPath + 前缀验证 |
| `ZipInputStream.getNextEntry()` 未验证 | Zip Slip | 验证每个 entry 路径 |
| `File.createTempFile` | 竞态条件 | 使用 `Files.createTempFile` + 安全权限 |

### 加密
| 禁止 | 推荐 |
|------|------|
| `MessageDigest.getInstance("MD5")` | `MessageDigest.getInstance("SHA-256")` |
| `Cipher.getInstance("DES")` | `Cipher.getInstance("AES/GCM/NoPadding")` |
| `new Random()` | `SecureRandom.getInstanceStrong()` |

### 日志
| 模式 | 风险 |
|------|------|
| `log.info(userInput)` | 日志注入（换行注入伪造日志） |
| `log.error("user: " + password)` | 敏感信息泄露 |

## 框架特性

### Spring Security
- 默认启用 CSRF 保护（注意 API 场景的配置）
- `@PreAuthorize`/`@PostAuthorize` 检查覆盖度
- `SecurityContextHolder` 线程安全使用

### Spring Boot Actuator
- `/actuator` 端点暴露检查
- 敏感端点（env, configprops, heapdump）权限控制

### MyBatis
- `#{}` vs `${}`: `${}` 直接拼接，除非用于 ORDER BY/GROUP BY
- 动态 SQL 标签 `<if>` 不会防止 SQL 注入

## 检测优先级

1. ObjectInputStream / FastJson / Jackson 反序列化 → Critical
2. Statement.execute + 拼接 → Critical
3. Runtime.exec 字符串拼接 → Critical
4. XXE 未配置 → High
5. Spring Boot 端点未授权 → High
