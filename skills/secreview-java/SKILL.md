---
name: secreview-java
description: 对 Java 代码进行通用安全规范检视，关注危险函数使用和安全编码规范
category: language-specific
language: java
topic: [web, crypto, system]
---


# secreview-java

对 Java 代码进行通用安全规范检视，关注危险函数使用、安全函数规范和代码安全最佳实践。

## 检视范围

### 语义层面
- 是否使用了参数化查询（而非字符串拼接）
- 是否正确配置了 XML Parser（禁用 XXE）
- 是否使用了安全的加密算法和模式
- 反序列化是否有类型限制
- 日志输出是否包含敏感信息或可被注入

### 规范合规
- 密码学 API 使用是否符合公司安全基线
- HTTP 安全头是否正确配置
- 会话管理是否符合 OWASP 标准
- 异常处理是否泄露敏感信息

### 反模式识别
- `@Transactional` 使用不当导致事务失效
- Spring Security 过滤器链顺序错误
- `SecurityManager` 未正确设置
- `@Autowired` 字段注入而非构造函数注入（可测试性和安全）

## 与 secguard-java 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
