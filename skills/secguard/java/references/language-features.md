# Java 语言特性参考

## 命令执行
| API | 风险 | 替代 |
|-----|------|------|
| `Runtime.getRuntime().exec(cmd)` | Shell 注入（单字符串形式） | 使用字符串数组参数 |
| `ProcessBuilder(cmd)` | Shell 注入（如果调用 shell） | 直接调用命令，不用 shell |
| `ScriptEngine.eval(script)` | 脚本注入 | 沙箱执行 |

## SQL 注入
| API | 风险 | 替代 |
|-----|------|------|
| `Statement.execute(sql)` | SQL 注入 | PreparedStatement |
| `String.format` + SQL 拼接 | SQL 注入 | 参数化查询 |
| `MyBatis ${}` 参数替换 | SQL 注入 | 使用 `#{}` 参数化 |
| `JPA nativeQuery 拼接` | SQL 注入 | JPQL 参数化 / Criteria API |

## 反序列化
| API | 风险 | 替代 |
|-----|------|------|
| `ObjectInputStream.readObject()` | RCE 反序列化 | 类型白名单 + 签名验证 |
| `FastJson.parseObject(json)` | 任意类实例化 | 禁止 @type 指定 / 关闭 autoType |
| `Jackson enableDefaultTyping` | 多态类型注入 | 禁用默认类型 / 白名单 |
| `XStream.fromXML(xml)` | 反序列化执行 | 类型限制 Permission |
| `SnakeYAML.load(input)` | 类型注入 | 使用 safeLoad / Constructor 限制 |

## XML 处理 (XXE)
| API | 风险 | 替代 |
|-----|------|------|
| `DocumentBuilder` 未配置 | XXE | 禁用 DOCTYPE / 外部实体 |
| `SAXParser` 未配置 | XXE | 同上 |
| `TransformerFactory` 未配置 | XSLT 注入 | 安全配置 |

## 文件操作
| API | 风险 | 替代 |
|-----|------|------|
| `Paths.get(userInput)` 直接使用 | 路径穿越 | 先 getCanonicalPath + 前缀验证 |
| `ZipInputStream.getNextEntry()` 未验证 | Zip Slip | 验证每个 entry 路径 |

## 加密安全
| 禁止 | 推荐 |
|------|------|
| `MessageDigest.getInstance("MD5")` | `MessageDigest.getInstance("SHA-256")` |
| `Cipher.getInstance("DES")` | `Cipher.getInstance("AES/GCM/NoPadding")` |
| `new Random()` | `SecureRandom.getInstanceStrong()` |

## 日志
| 模式 | 风险 |
|------|------|
| `log.info(userInput)` | 日志注入（换行注入伪造日志） |
| `log.error("user: " + password)` | 敏感信息泄露 |

## 框架注意
- Spring Security: 默认启用 CSRF 保护，`@PreAuthorize`/`@PostAuthorize` 检查覆盖度
- Spring Boot Actuator: `/actuator` 端点暴露检查
- MyBatis: `#{}` vs `${}`: `${}` 直接拼接，除非用于 ORDER BY/GROUP BY
