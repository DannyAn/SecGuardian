---
name: secguard-java
description: 对 Java 代码进行安全加固项排查，扫描危险 API 调用和常见漏洞模式
category: language-specific
language: java
---


# secguard-java

对 Java 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 执行流程

> **前置条件**: Command 层面已完成 `secguardian-index` 索引器调用，`index.json` 已生成在扫描输出目录下。包含 `symbols.functions`（函数→文件:行号）、`call_graph.edges`（调用关系）、`files`（文件清单）。**请在后续步骤中利用这些结构化数据定位检测目标，而非逐个读取文件。**

1. 读取 Command 生成的 `index.json`，获取扫描范围内的完整文件清单、符号表和调用图
2. 加载 `knowledge/languages/java.md` 获取 Java 危险 API 清单
3. 加载各 `knowledge/concepts/*.md` 获取安全概念和检测逻辑
4. 基于 index.json 的符号表定位检测目标，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | 反序列化漏洞 | ObjectInputStream / FastJson @type / Jackson enableDefaultTyping |
| Critical | SQL 注入 | Statement.execute / MyBatis ${} / JPA nativeQuery 拼接 |
| Critical | 命令注入 | Runtime.exec 单字符串 / ProcessBuilder + shell |
| Critical | SSTI/代码注入 | ScriptEngine.eval / 模板引擎未过滤输入 |
| High | XXE | XML Parser 未禁用外部实体 |
| High | 路径穿越 | 文件路径未 canonicalize |
| High | SSRF | HTTP 请求 URL 来自用户输入 |
| High | 弱加密 | MD5/SHA-1/DES/ECB/Random 非安全用途 |
| High | 硬编码密钥 | API Key / Password / Token 硬编码 |
| Medium | TOCTOU | 文件检查与使用非原子 |
| Medium | 日志注入 | 用户输入直接写日志 |

### 框架覆盖
- Spring (Spring Boot, Spring Security, Spring MVC)
- MyBatis
- Hibernate / JPA
- FastJson / Jackson / Gson
- Apache Shiro
- Log4j / Logback
