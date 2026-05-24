# Java 安全反模式

代码审查中需要关注的 Java 特有安全反模式。

## 异常处理反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `catch (Exception e) { }` 空块 | 吞掉安全关键异常 | 至少记录日志 |
| `catch (Exception e) { e.printStackTrace(); }` | 异常信息泄露到 stdout | 使用日志框架 |
| `throw new RuntimeException(e)` 包装 | 丢失原始异常类型 | 保留 cause chain |
| finally 块中 return | 覆盖异常 | finally 仅做清理 |

## 序列化反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `implements Serializable` 无版本号 | 反序列化兼容性问题 | 明确 `serialVersionUID` |
| `transient` 字段含敏感数据 | 依赖 transient 保护不足 | 加密后存储 |
| `writeObject/readObject` 自定义但不调用 `defaultWriteObject` | 序列化不一致 | 遵循序列化协议 |

## 并发反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `synchronized(this)` 公开锁 | 外部代码可死锁 | 使用私有锁对象 |
| double-checked locking 无 volatile | 指令重排导致半初始化对象 | volatile + synchronized |
| `ThreadLocal` 在线程池中未清理 | 数据泄露跨请求 | finally 块清理 |

## Spring 反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `@Autowired` 字段注入 | 不可变性和可测试性问题 | 构造函数注入 |
| `@Transactional` 自调用 | 事务失效 | 通过代理调用 |
| `SecurityContext` 在新线程中使用 | 安全上下文丢失 | `DelegatingSecurityContextExecutor` |
