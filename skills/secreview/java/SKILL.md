---
name: java
description: 对 Java 代码进行通用安全规范检视，关注危险函数使用和安全编码规范。当用户请求Java代码规范检视、Java反模式识别、Java安全编码规范、Java最佳实践审计时使用。
category: language-specific
language: java
topic: [web, crypto, system]
---

# 安全规范检视 — Java

对 Java 代码进行通用安全规范检视，关注危险函数使用、安全函数规范和代码安全最佳实践。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 执行流程

### Phase 1: 加载上下文

1. 读取 `index.json`，获取 `files`、`symbols.functions`、`call_graph.edges`
2. 加载 `knowledge/languages/java.md` 获取 Java 危险 API 清单
3. 加载 `knowledge/standards/sei-cert-java.md` 获取 SEI CERT Java 规范映射

### Phase 2: 语义层面检视

| # | 检查项 | 检测方法 | 示例：不合规 |
|---|--------|---------|-------------|
| 1 | SQL 参数化 | 搜索 `Statement.execute`/`createStatement` → 是否拼接用户输入 | `stmt.execute("SELECT * FROM users WHERE id=" + userId)` → 应使用 `PreparedStatement` |
| 2 | XML 安全配置 | 搜索 `DocumentBuilderFactory`/`SAXParserFactory` → 是否禁用 XXE | 未设 `FEATURE_DISALLOW_DOCTYPE_DECL` → 易受 XXE 攻击 |
| 3 | 加密算法安全 | 搜索 `Cipher.getInstance` → 算法参数（AES/ECB, DES, RC4） | `Cipher.getInstance("AES/ECB/PKCS5Padding")` → 应使用 GCM 模式 |
| 4 | 反序列化安全 | 搜索 `ObjectInputStream`/`readObject` → 有无类型白名单 | 无 `ObjectInputFilter` → 易受反序列化攻击 |
| 5 | 日志安全 | 搜索 `log.info(`/`logger.debug(` → 参数是否包含用户输入 | `log.info("User: " + request.getParameter("user"))` → 存在日志注入风险 |

### Phase 3: 规范合规检视

| # | 检查项 | 检测方法 | 修复指引 |
|---|--------|---------|---------|
| 1 | 密码学基线 | 检查加密密钥长度、算法版本、PRNG 选择 | AES-256-GCM + `SecureRandom`，禁用 DES/RC4/MD5/SHA-1 |
| 2 | HTTP 安全头 | 检查 Spring Security / Filter 配置 | 启用 HSTS/CSP/X-Frame-Options/X-Content-Type-Options |
| 3 | 会话管理 | 检查 `HttpSession`/`SecurityContext` 配置 | Cookie 设 `httpOnly`+`secure`+`sameSite`，超时后失效 |
| 4 | 异常信息泄露 | 搜索 `e.printStackTrace()` → 是否输出到 HTTP response | 全局异常处理器返回通用消息，内部日志记录完整堆栈 |

### Phase 4: 反模式识别

| # | 反模式 | 检测特征 | 修复方案 |
|---|--------|---------|---------|
| 1 | @Transactional 失效 | 同类内方法调用 @Transactional 方法 | 将事务方法移至独立 Service Bean 或使用 `AopContext.currentProxy()` |
| 2 | Spring Security 过滤器顺序 | 自定义 Filter 未指定 `@Order` | 明确指定 Filter 顺序，认证过滤器在授权过滤器之前 |
| 3 | @Autowired 字段注入 | `@Autowired private XxxService service;` | 改用构造函数注入 + `final`，提升可测试性和不变性 |
| 4 | SecurityManager 缺失 | 无 `System.setSecurityManager()` 且依赖安全策略 | 评估是否需要 SecurityManager，确保安全策略文件正确配置 |

### Phase 5: 输出

遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)：`report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json`。

## 与 secguard-java 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
| 覆盖 | CWE Top 25 + 检测器 | SEI CERT Java + OWASP 最佳实践 |

## 输出完整性要求

> **输出协议**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。
>
> Command 层 Step 4b 质量门禁强制检查每个检出的四段式完整性：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 违规代码行
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（指出违反的安全编码规范条款）
> 3. **⚠️ Impact** — 不合规可能导致的安全风险 + 适用攻击场景
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + SEI CERT/OWASP 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注关联代码位置，`fixes` 包含 before/after 替换。
