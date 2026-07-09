---
name: cwe-mapping
description: CWE → OWASP ASVS / SEI CERT 双向映射表。报告层输出时根据 findings 的 CWE 反查，追加合规标准附录。不修改规则本体。
type: mapping
updated: 2026-07-08
---

# CWE → 安全标准映射

## 用途

本文件为 **报告层附属映射**，不作为检测门控。检出结果（finding）的 CWE 字段通过此表反查对应的合规标准，在 `report.md` 附录中展示。

> **设计原则**：标准引用不嵌入 rule.md frontmatter（避免 60+ × 5 语言散弹修改），只在此文件集中维护。

---

## 1. CWE → OWASP ASVS 映射

OWASP ASVS v4.0 按章节（V-chapter）组织。CWE 归属与 ASVS 章节的对应：

| CWE | 名称 | OWASP ASVS 章节 |
|-----|------|----------------|
| CWE-20 | 输入验证不充分 | V5 (Input Validation) |
| CWE-22 | 路径遍历 | V5 (File Upload Validation) |
| CWE-61 | 符号链接攻击 | V12 (Infrastructure) |
| CWE-77 | 命令注入 | V5 (Input Validation) |
| CWE-78 | 操作系统命令注入 | V5 (Input Validation) |
| CWE-79 | 跨站脚本 (XSS) | V5 (Output Encoding) |
| CWE-89 | SQL 注入 | V5 (Input Validation) |
| CWE-94 | 代码注入 | V5 (Input Validation) |
| CWE-117 | 日志注入/伪造 | V7 (Logging) |
| CWE-200 | 信息泄露 | V8 (Data Protection) |
| CWE-209 | 错误信息信息泄露 | V7 (Error Handling) |
| CWE-248 | 未捕获异常 | V7 (Error Handling) |
| CWE-269 | 权限管理不当 | V4 (Access Control) |
| CWE-276 | 缺省权限不正确 | V4 (Access Control) |
| CWE-287 | 认证绕过 | V2 (Authentication) |
| CWE-306 | 关键功能认证缺失 | V2 (Authentication) |
| CWE-311 | 加密缺失 | V8 (Data Protection) |
| CWE-312 | 敏感数据明文存储 | V8 (Data Protection) |
| CWE-319 | 传输层加密缺失 | V9 (Communication) |
| CWE-326 | 密钥强度不足 | V8 (Data Protection) |
| CWE-327 | 弱加密算法 / 已被破解算法 | V8 (Data Protection) |
| CWE-329 | 硬编码 IV/Nonce | V8 (Data Protection) |
| CWE-338 | 弱随机数生成器 | V8 (Cryptographic Randomness) |
| CWE-347 | JWT 签名验证不当 | V3 (Session Management), V8 (Data Protection) |
| CWE-352 | 跨站请求伪造 (CSRF) | V3 (Session Management), V4 (Access Control) |
| CWE-362 | 竞态条件 | V4 (Access Control), V12 (Infrastructure) |
| CWE-367 | TOCTOU 竞态 | V4 (Access Control) |
| CWE-377 | 不安全临时文件 | V12 (Infrastructure) |
| CWE-391 | 异常吞掉 | V7 (Error Handling) |
| CWE-400 | 资源耗尽 | V4 (Rate Limiting) |
| CWE-401 | 内存泄露 | V12 (Infrastructure) |
| CWE-404 | 资源释放不当 | V12 (Infrastructure) |
| CWE-415 | 双重释放 | V12 (Infrastructure) |
| CWE-416 | 释放后使用 | V12 (Infrastructure) |
| CWE-434 | 无限制文件上传 | V5 (File Upload), V12 (Infrastructure) |
| CWE-476 | 空指针解引用 | V12 (Infrastructure) |
| CWE-489 | Debug 模式启用 | V7 (Error Handling) |
| CWE-502 | 反序列化不可信数据 | V5 (Input Validation) |
| CWE-522 | 凭据保护不足 | V2 (Authentication) |
| CWE-523 | 未限制认证尝试 | V2 (Authentication) |
| CWE-525 | 浏览器缓存泄露 | V8 (Data Protection) |
| CWE-532 | 日志中插入敏感信息 | V7 (Logging) |
| CWE-544 | 错误信息格式不统一 | V7 (Error Handling) |
| CWE-601 | 开放重定向 | V5 (Input Validation) |
| CWE-611 | XML 外部实体 (XXE) | V5 (Input Validation) |
| CWE-639 | 不安全直接对象引用 (IDOR) | V4 (Access Control) |
| CWE-667 | 锁错误使用 | V12 (Infrastructure) |
| CWE-675 | 文件重复关闭 | V12 (Infrastructure) |
| CWE-704 | 错误类型转换 | V12 (Infrastructure) |
| CWE-762 | 不匹配释放 | V12 (Infrastructure) |
| CWE-798 | 硬编码凭据 | V2 (Authentication), V8 (Data Protection) |
| CWE-833 | 死锁 | V12 (Infrastructure) |
| CWE-862 | 授权缺失 | V4 (Access Control) |
| CWE-863 | 授权不正确 | V4 (Access Control) |
| CWE-915 | 批量赋值 (Mass Assignment) | V4 (Access Control) |
| CWE-916 | 密码存储不安全 | V2 (Authentication) |
| CWE-918 | 服务端请求伪造 (SSRF) | V5 (Input Validation) |
| CWE-943 | NoSQL 注入 | V5 (Input Validation) |
| CWE-1104 | 未维护的第三方依赖 | V14 (Dependency) |
| CWE-1321 | 原型污染 | V5 (Input Validation) |
| CWE-1336 | 服务端模板注入 (SSTI) | V5 (Input Validation) |

---

## 2. CWE → SEI CERT 映射

SEI CERT 编码标准按语言组织：C (`ARR`, `EXP`, `FIO`, `INT`, `MEM`, `CON`, `SIG`, `STR`)、C++ (`CTR`, `MEM`, `OOP`) 和 Java (`IDS`, `MSC`, `SER`)。

| CWE | 名称 | SEI CERT 规则 |
|-----|------|--------------|
| CWE-61 | 符号链接攻击 | FIO15-C |
| CWE-120 | 缓冲区溢出 | ARR30-C, STR31-C |
| CWE-122 | 堆缓冲区溢出 | MEM35-C |
| CWE-125 | 越界读取 | ARR30-C |
| CWE-134 | 格式字符串 | FIO30-C |
| CWE-190 | 整数溢出 | INT30-C, INT32-C |
| CWE-193 | Off-by-One | ARR30-C |
| CWE-362 | 竞态条件 | CON33-C |
| CWE-366 | 数据竞态 | CON43-C |
| CWE-367 | TOCTOU | FIO01-C |
| CWE-377 | 不安全临时文件 | FIO21-C |
| CWE-401 | 内存泄露 | MEM31-C, MEM51-CPP |
| CWE-404 | 文件句柄泄露 | FIO22-C |
| CWE-415 | 双重释放 | MEM30-C, MEM31-C |
| CWE-416 | 释放后使用 | MEM30-C |
| CWE-457 | 未初始化内存 | EXP33-C |
| CWE-476 | 空指针解引用 | EXP34-C |
| CWE-479 | 信号处理器不安全 | SIG30-C |
| CWE-667 | 锁误用 | CON35-C |
| CWE-675 | 文件重复关闭 | FIO46-C |
| CWE-704 | 错误类型转换 | EXP05-C |
| CWE-762 | 不匹配释放 | MEM51-CPP |
| CWE-833 | 死锁 | CON35-C |
| CWE-911 | 引用计数误用 | MEM30-CPP |
| CWE-89 | SQL 注入 | IDS00-J |
| CWE-502 | 反序列化 | SER01-J |
| CWE-338 | 弱随机数 | MSC63-J |
| CWE-327 | 弱加密 | MSC61-J |
| CWE-79 | 跨站脚本 | MSC03-J |

---

## 3. 按 ASVS 章节反向索引

用于合规审计场景：给定 ASVS 章节，查询对应的 CWE 集合。

### V2 — Authentication
`CWE-287` `CWE-306` `CWE-522` `CWE-523` `CWE-798` `CWE-916`

### V3 — Session Management
`CWE-347` `CWE-352`

### V4 — Access Control
`CWE-269` `CWE-276` `CWE-352` `CWE-362` `CWE-367` `CWE-400` `CWE-639` `CWE-862` `CWE-863` `CWE-915`

### V5 — Input Validation & Output Encoding
`CWE-20` `CWE-22` `CWE-77` `CWE-78` `CWE-79` `CWE-89` `CWE-94` `CWE-434` `CWE-502` `CWE-601` `CWE-611` `CWE-918` `CWE-943` `CWE-1321` `CWE-1336`

### V7 — Error Handling & Logging
`CWE-117` `CWE-209` `CWE-248` `CWE-391` `CWE-489` `CWE-532` `CWE-544`

### V8 — Data Protection
`CWE-200` `CWE-311` `CWE-312` `CWE-326` `CWE-327` `CWE-329` `CWE-338` `CWE-347` `CWE-525` `CWE-798` `CWE-916`

### V9 — Communication
`CWE-319` `CWE-326` (TLS)

### V12 — Infrastructure
`CWE-61` `CWE-362` `CWE-377` `CWE-400` `CWE-401` `CWE-404` `CWE-415` `CWE-416` `CWE-434` `CWE-476` `CWE-667` `CWE-675` `CWE-704` `CWE-762` `CWE-833` `CWE-911`

### V14 — Dependency
`CWE-1104`

---

## 4. 使用方式

### 报告层附录生成

Agent 或 `render-report.py` 输出 `report.md` 时，对每条 finding 的 `cwe` 字段反查本文件 §1 表，追加附录章节：

```markdown
## 合规标准映射

| Finding | CWE | OWASP ASVS | SEI CERT |
|---------|-----|-----------|----------|
| buffer overflow in foo.c:42 | CWE-120 | V12 | ARR30-C, STR31-C |
```

### 维护规则

1. 新增检测规则时，若 CWE 已存在于本文件，无需任何额外操作
2. 新增 CWE 不在本文件时，在三张表中各加一行
3. 本文件变更不影响检出逻辑，只影响输出呈现
