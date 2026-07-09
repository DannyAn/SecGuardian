# 02 — 安全编码规范 (Secure Coding Standards)

> **对应 Sheet:** `02_Secure_Coding`
> **牵引方向:** SecGuardian 安全编码检测引擎——支持多语言的安全编码规则集，涵盖输入验证、内存安全、错误处理、密码学使用和安全 API。

---

## 1. 概述

安全编码规范定义了开发人员在编写代码时必须遵守的安全约束。本 sheet 涵盖 **5 大安全编码分类**，每类 24 条要求，共计 **120 条安全编码控制项**。

---

## 2. 分类体系

| 分类 | 控制目标 | 涉及语言 | 严重度分布 |
|---|---|---|---|
| **Input Validation** (输入验证) | 防止注入、路径遍历、XSS | C/C++/Java/Python/JS | 6×Medium, 6×High, 12×Critical(Gate) |
| **Memory Safety** (内存安全) | 防止缓冲区溢出、UAF、空指针 | C/C++ | 6×Medium, 6×High, 12×Critical(Gate) |
| **Error Handling** (错误处理) | 信息泄露防范、错误码规范化 | 全语言 | 8×Medium, 8×High, 8×Critical(Gate) |
| **Crypto Usage** (密码学使用) | 强制安全算法、密钥管理 | 全语言 | 6×Medium, 6×High, 12×Critical(Gate) |
| **Secure APIs** (安全 API 调用) | OWASP API Top 10 防护 | 全语言 | 6×Medium, 6×High, 12×Critical(Gate) |

---

## 3. 分类详解与最佳实践

### 3.1 输入验证 (Input Validation)

**OWASP ASVS V5 对标：**

| 检测项 | 业界实践 | SecGuardian 状态 |
|---|---|---|
| SQL 注入检测 | 参数化查询/PREPARE | ✅ C/C++ SQLite 已支持 |
| XSS 检测 | 输出编码/Content-Type 头 | ❌ 需开发 |
| 路径遍历 | 规范化 + 白名单 | ❌ 需开发 |
| 命令注入 | 禁止 system()/exec() | ❌ 需开发 |
| 整数溢出 | 范围检查 | ✅ C/C++ 部分支持 |

**语言专项建议：**

| 语言 | 关键关注点 |
|---|---|
| C/C++ | `gets()` / `strcpy()` / `sprintf()` 等不安全函数检测；format string 漏洞 |
| Java | SQL 注入 (JDBC/MyBatis)、表达式注入 (SpEL)、反序列化 |
| Python | eval/exec 执行、模板注入 (Jinja2 SSTI)、pickle 反序列化 |
| JavaScript | eval 执行、NoSQL 注入、Prototype Pollution |
| Go | SQL 注入、命令注入、模板注入 |

### 3.2 内存安全 (Memory Safety)

**主要应用于 C/C++，对标 CWE/SANS Top 25：**

| CWE | 名称 | 严重度 |
|---|---|---|
| CWE-119 | 内存缓冲区操作限制不当 | Critical |
| CWE-125 | 越界读取 | High |
| CWE-787 | 越界写入 | Critical |
| CWE-416 | Use-After-Free | Critical |
| CWE-476 | NULL 指针解引用 | High |
| CWE-122 | 堆缓冲区溢出 | Critical |

**SecGuardian 现有能力：**
- ✅ C/C++ SQLite C API 注入检测
- ✅ C11 Annex K `_s` 函数安全检查
- ✅ 自定义 allocator 感知

**需要扩展：**
- ❌ Java 数组边界检查
- ❌ C++ `std::string` 操作安全分析
- ❌ Python 缓冲区协议 (buffer protocol) 安全

### 3.3 错误处理 (Error Handling)

**核心原则 — OWASP ASVS V7 (Error Handling & Logging)：**

| 要求 | 错误实践 | 正确实践 |
|---|---|---|
| 不泄露内部信息 | `catch (Exception e) { return e.stackTrace }` | 返回通用错误码，内部日志记录详情 |
| 统一错误格式 | 每层不同格式 | 标准化错误响应 (JSON API 错误格式) |
| 日志脱敏 | `logger.info("User: {0}", user.password)` | 密码/token/密钥打码或跳过 |
| 异常封装 | 抛出原始异常 | 封装为业务异常，不泄露实现细节 |

### 3.4 密码学使用 (Crypto Usage)

**对标 OWASSP ASVS V6 (Cryptography) + NIST SP 800-175B：**

| 密码操作 | 推荐算法 | 禁止算法 | 最低密钥长度 |
|---|---|---|---|
| 对称加密 | AES-256-GCM | DES / 3DES / RC4 / AES-ECB | 256 bits |
| 非对称加密 | RSA-OAEP / ECDH | RSA-PKCS1v1.5 | RSA 2048 / ECC P-256 |
| 哈希 | SHA-256/384/512 | MD5 / SHA-1 | 256 bits |
| 消息认证 | HMAC-SHA256 | — | 256 bits |
| 密码存储 | bcrypt / scrypt / Argon2 | MD5 / SHA-1 / 简单哈希 | — |

**检测规则：**
1. `MD5` / `SHA1` 在安全场景中使用 → **High**
2. `AES-ECB` 模式 → **High** (不提供语义安全)
3. 自定义加密算法 → **Critical** (必须使用标准库)
4. 硬编码密钥 → **Critical**
5. TLS 1.0/1.1 → **Medium**

### 3.5 安全 API 调用 (Secure APIs)

**对标 OWASP API Security Top 10 (2023)：**

| 风险 | 检测规则 |
|---|---|
| 批量分配 (Mass Assignment) | 检测 `@RequestBody` / `request.form` 直接绑定到模型类 |
| 过度数据暴露 | 检测 API 返回包含 `password` / `secret` / `token` 字段 |
| SSRF | 检测用户输入直接传入 URL 请求函数 (如 `requests.get(user_input)`) |
| 不安全的直接对象引用 (IDOR) | 检测 API 端点是否对资源 ID 进行所有权校验 |
| 服务端模板注入 (SSTI) | 检测用户输入传入 Jinja2 / Freemarker / Pug 模板 |

---

## 4. 业界最佳实践集成

### 4.1 SEI CERT 编码标准

[SEI CERT Coding Standards](https://wiki.sei.cmu.edu/confluence/display/seccode/SEI+CERT+Coding+Standards) 提供了语言特定的安全编码规则：

| 语言 | 规则数 | 关键覆盖 |
|---|---|---|
| C | 120+ | 预处理器、声明、表达式、整数、字符串、内存管理 |
| C++ | 90+ | 类、异常、STL、并发 |
| Java | 60+ | 输入验证、序列化、访问控制 |
| Perl | 40+ | 输入处理、文件操作、命令执行 |

**SecGuardian 计划：** 将 SEI CERT 规则映射到现有 `detectors/` 体系。

### 4.2 MISRA C/C++

适用于嵌入式/IoT 场景，严格度高于普通安全编码：
- MISRA C:2012 — 143 条规则 (16 必遵 + 127 建议)
- MISRA C++:2008 — 228 条规则

### 4.3 OWASP 安全编码最佳实践

涵盖以下检查清单：
- **[认证](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)**
- **[授权](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)**
- **[输入验证](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)**
- **[输出编码](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)**

---

## 5. SecGuardian 牵引方向

### 5.1 检测器扩展路线图

| 阶段 | 分类 | 新检测器 | 优先级 |
|---|---|---|---|
| **P0** | 输入验证 | SQL 注入 (Java/Python)、路径遍历、命令注入 | 🔴 |
| **P1** | 密码学 | 弱算法检测、硬编码密钥、ECB 模式 | 🔴 |
| **P1** | 安全 API | 批量分配、SSRF、IDOR | 🔴 |
| **P2** | 错误处理 | 堆栈泄露、日志脱敏、错误格式 | 🟡 |
| **P3** | 内存安全 | Java Go 指针安全、`unsafe` 包检测 | 🟢 |

### 5.2 语言覆盖率规划

| 语言 | 当前 | P0 目标 | P1-P2 目标 |
|---|---|---|---|
| C/C++ | ✅ SQLite + Annex K | 内存安全 + 缓冲区溢出 | format string → integer 安全 |
| Java | ❌ | SQL 注入 + 反序列化 | 表达式注入 + SpEL + 路径遍历 |
| Python | ❌ | SQL 注入 + 命令注入 | SSTI + pickle + eval 执行 |
| JavaScript | ❌ | XSS + Prototype Pollution | NoSQL 注入 + SSRF |
| Go | ❌ | SQL 注入 + 命令注入 | 指针安全 + goroutine 泄露 |

### 5.3 知识库建设

在 `knowledge/` 目录中为每类安全编码建立专项知识：

```
skills/secguard-<lang>/references/language-features.md
├── skills/secguard-cpp/references/language-features.md    # C/C++ 安全编码语言画像
├── skills/secguard-java/references/language-features.md   # Java 安全编码语言画像
├── skills/secguard-python/references/language-features.md # Python 安全编码语言画像
├── skills/secguard-js/references/language-features.md     # JavaScript/Node.js 安全编码语言画像
└── skills/secguard-go/references/language-features.md     # Go 安全编码语言画像
```

---

## 6. 安全编码扫描流程

```
源码输入
  │
  ├─ 语言识别 (C/C++/Java/Python/JS/Go)
  │
  ├─ 【输入验证】  → SQL 注入 / XSS / 命令注入 / 路径遍历
  ├─ 【内存安全】  → 缓冲区溢出 / UAF / 空指针 (C/C++)
  ├─ 【错误处理】  → 信息泄露 / 日志脱敏 / 统一错误
  ├─ 【密码学】    → 弱算法 / 硬编码密钥 / ECB 模式
  └─ 【安全 API】  → 批量分配 / SSRF / IDOR / SSTI
      │
      ▼
  结果聚合 (按分类/严重度/语言)
      │
      ▼
  生成修复建议 + 代码示例 (good/bad pattern)
```

---

> **本文档指引 SecGuardian 构建多语言安全编码检测引擎。**
> 参考 [01_Security_Redlines](01_Security_Redlines.md) 的红线体系与 [05_SAST_Rules](05_SAST_Rules.md) 的 SAST 规则治理。
