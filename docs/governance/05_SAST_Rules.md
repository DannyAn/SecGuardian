# 05 — SAST 规则治理 (Static Analysis Security Testing Rules)

> **对应 Sheet:** `05_SAST_Rules`  
> **牵引方向:** SecGuardian SAST 检测规则体系的标准化建设——覆盖 5 大漏洞分类，共计 100 条检测规则。

---

## 1. 概述

SAST (Static Application Security Testing) 在不执行代码的情况下分析源代码以发现安全漏洞。本 sheet 定义了 **5 大 SAST 检测分类**，每类 20 条规则，共计 **100 条 SAST 规则**。

---

## 2. 分类体系

| 分类 | 规则数 | 严重度分布 | 当前 SecGuardian 支持 |
|---|---|---|---|
| **Injection** (注入) | 20 | 6×Medium, 6×High, 8×Critical | ✅ C/C++ SQLite C API |
| **XSS** (跨站脚本) | 20 | 6×Medium, 6×High, 8×Critical | ❌ 未实现 |
| **Path Traversal** (路径遍历) | 20 | 6×Medium, 6×High, 8×Critical | ❌ 未实现 |
| **Deserialization** (反序列化) | 20 | 6×Medium, 6×High, 8×Critical | ❌ 未实现 |
| **Secrets** (密钥泄露) | 20 | 6×Medium, 6×High, 8×Critical | ✅ 部分 (KeyLeak 检测) |

---

## 3. 各分类详解与最佳实践

### 3.1 Injection（注入）

**覆盖漏洞类型：**

| 类型 | CWE ID | OWASP Top 10 2021 |
|---|---|---|
| SQL 注入 | CWE-89 | A03:2021 |
| 命令注入 | CWE-77 | A03:2021 |
| 表达式注入 | CWE-94 | A03:2021 |
| LDAP 注入 | CWE-90 | A03:2021 |
| NoSQL 注入 | — | A03:2021 |
| XXE (XML 外部实体) | CWE-611 | A05:2021 |

**检测规则示例：**

| ID | 检测模式 | 语言 | 严重度 |
|---|---|---|---|
| INJ-01 | 字符串拼接 SQL 查询 | Java/Python/JS | Critical |
| INJ-02 | 不安全的 `system()` / `exec()` 调用 | C/C++/Python | High |
| INJ-03 | 用户输入传入 `eval()` | Python/JS | Critical |
| INJ-04 | 未参数化的 MyBatis `${}` 符号 | Java | Critical |
| INJ-05 | XML 解析未禁用外部实体 | Java/C# | High |

**规则实现模式：**

```python
# 示例检测模板 — Java SQL 拼接
AS016: "Hard Coded SQL"
  type: taint
  sources:
    - pattern: request.getParameter
  sanitizers:
    - pattern: PreparedStatement
  sinks:
    - pattern: Statement.executeQuery
  severity: Critical
```

### 3.2 XSS（跨站脚本）

**覆盖类型：**

| 类型 | 说明 | CWE |
|---|---|---|
| Reflected XSS | 反射型跨站脚本 | CWE-79 |
| Stored XSS | 存储型跨站脚本 | CWE-79 |
| DOM-based XSS | DOM 型跨站脚本 | CWE-79 |

**语言专项检测：**

| 语言 | 检测模式 | 严重度 |
|---|---|---|
| JavaScript/React | `dangerouslySetInnerHTML` + 用户输入 | Critical |
| JavaScript/Vue | `v-html` + 用户输入 | Critical |
| Java/JSP | 未编码的 `<%= request.getParameter() %>` | Critical |
| Python/Jinja2 | 模板渲染未转义 | High |
| Go | `template.HTML()` 转换后输出 | Critical |

**规则实现：**
- **Taint tracking** —— 用户输入 → 到达 HTML 输出点
- **编码检查** —— 输出点是否调用上下文感知编码 (HTML/URL/JS/CSS)
- **CSP 检查** —— 是否配置了足够严格的 Content-Security-Policy

### 3.3 Path Traversal（路径遍历）

**OWASP ASVS V12.1 (File and Resources)：**

| 检测规则 | 说明 | 严重度 |
|---|---|---|
| PT-01 | 用户输入直接传入文件操作函数 | High |
| PT-02 | 路径未规范化 (`../` 序列) | Critical |
| PT-03 | 未检查文件扩展名 | Medium |
| PT-04 | 压缩包内路径遍历 (Zip Slip) | Critical |
| PT-05 | 错误地使用 `..` 路径拼接 | High |

**安全文件操作模式：**

```java
// 不安全
String path = "/data/" + request.getParameter("file");
File file = new File(path);

// 安全
String filename = PathSanitizer.sanitize(request.getParameter("file"));
Path baseDir = Paths.get("/data").toRealPath();
Path resolved = baseDir.resolve(filename).normalize().toRealPath();
if (!resolved.startsWith(baseDir)) throw new SecurityException();
```

### 3.4 Deserialization（反序列化）

**OWASP Top 10 中反序列化是独立类别：**

| 检测规则 | 语言 | 严重度 |
|---|---|---|
| DES-01 | Java `ObjectInputStream.readObject()` + 不可信数据 | Critical |
| DES-02 | Python `pickle.loads()` + 不可信数据 | Critical |
| DES-03 | Java `@RequestBody` 未做类型校验 | High |
| DES-04 | PHP `unserialize()` | Critical |
| DES-05 | .NET `BinaryFormatter.Deserialize()` | Critical |
| DES-06 | JS `JSON.parse()` 大对象 DoS | Medium |

**缓解策略：**
- 使用白名单过滤可反序列化的类 (Java: `ValidatingObjectInputStream`)
- 改为 JSON/YAML 等文本格式
- 使用 Sealed 类 / final class
- 运行时检测：持续监控反序列化异常

### 3.5 Secrets（密钥泄露检测）

**覆盖的凭证模式：**

| 类别 | 正则/模式 | 严重度 |
|---|---|---|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | Critical |
| GitHub Token | `gh[pousr]_[A-Za-z0-9_]+` | Critical |
| Slack Token | `xox[baprs]-[0-9a-zA-Z-]+` | Critical |
| Private Key | `-----BEGIN (RSA|EC|DSA) PRIVATE KEY-----` | Critical |
| Generic Password | `password\s*=\s*['\"][^'\"]{6,}['\"]` | High |
| JWT Token | `eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+` | High |

**检测原则：**
1. 误报控制 — 测试用例中的密钥使用 `test:` 前缀过滤
2. 熵检测 — 对疑似密钥上下文计算信息熵，排除普通英文单词
3. 扫描范围 — 代码库 + 配置文件 + 历史 commits (Git Hooks)
4. 泄露响应 — 自动通知密钥轮转 Pipeline

---

## 4. SAST 规则架构

### 4.1 规则层级

```
SAST 规则引擎
  │
  ├─ 分类层 (Injection / XSS / Path Traversal / Deserialization / Secrets)
  │
  ├─ 规则层 (每分类 20 条规则)
  │   └─ 每条规则包含:
  │       ├─ 匹配模式 (Regex / AST Pattern / Taint Flow)
  │       ├─ 语言范围 (C/C++ / Java / Python / JS / Go / ...)
  │       ├─ 严重度 (Medium / High / Critical)
  │       ├─ CWE 编号
  │       └─ 修复建议 (Good Pattern / Bad Pattern)
  │
  └─ 元数据层
      ├─ OWASP ASVS 映射
      ├─ OWASP Top 10 2021 映射
      ├─ SEI CERT 映射
      └─ PCI DSS / GDPR / PIPL 映射
```

### 4.2 规则精准度分级

| 级別 | 误报率 | 漏报率 | 适用场景 |
|---|---|---|---|
| L1 高精度 | < 5% | < 30% | 红线门禁 (CI/CD 阻塞) |
| L2 标准 | < 20% | < 15% | PR 扫描 (提供报告) |
| L3 全覆盖 | < 50% | < 5% | 深度扫描 (定期执行) |

---

## 5. SecGuardian 牵引方向

### 5.1 现有检测器增强

| 分类 | 当前状态 | P0 目标 |
|---|---|---|
| 注入 | ✅ C/C++ SQLite C API | Java/Python SQL 注入 + 命令注入 |
| 密钥泄露 | ✅ 部分 | 20+ 凭证模式全覆盖 |
| XSS | ❌ | JS/React/Vue 输出点检测 |
| 路径遍历 | ❌ | Java/Python/Go 文件操作检查 |
| 反序列化 | ❌ | Java/Python 反序列化关键模式 |

### 5.2 规则格式标准化

建议所有规则采用统一 YAML 格式：

```yaml
# knowledge/detectors/injection/sql-injection.yaml
id: INJ-001
name: SQL Injection via string concatenation
category: injection
languages: [java, python, go, cpp]
severity: critical
cwe: CWE-89
owasp-top10: "A03:2021"
asvs: "V5.1"
cert: "IDS00-J"
sinks:
  - { language: java, pattern: "Statement.executeQuery" }
  - { language: python, pattern: "cursor.execute" }
  - { language: go, pattern: "db.Query" }
sanitizers:
  - { language: java, pattern: "PreparedStatement" }
  - { language: python, pattern: "cursor.execute(?, ...)" }
  - { language: go, pattern: "db.Query(?, ...)" }
remediation:
  bad: 'Statement stmt = conn.createStatement(); stmt.executeQuery("SELECT * FROM users WHERE id = " + userId);'
  good: 'PreparedStatement stmt = conn.prepareStatement("SELECT * FROM users WHERE id = ?"); stmt.setString(1, userId);'
```

### 5.3 发展方向

| 阶段 | 目标 |
|---|---|
| **Phase 1 (即时)** | 规则格式标准化，建立 20 条 P0 规则 (注入 + 密钥) |
| **Phase 2 (1-3月)** | 规则库扩展到 50 条 (新增 XSS + 路径遍历) |
| **Phase 3 (3-6月)** | 规则库扩展到 100 条 (全分类覆盖)，支持多语言 |
| **Phase 4 (6-12月)** | Taint tracking 分析引擎，上下文感知检测 |

### 5.4 标准映射矩阵

| 规则 | CWE | OWASP Top 10 2021 | ASVS | CIS |
|---|---|---|---|---|
| SQL 注入 | 89 | A03 | V5.1 | — |
| XSS | 79 | A03 | V5.3 | — |
| 路径遍历 | 22 | A01 | V12.1 | CIS 4.1 |
| 反序列化 | 502 | A08 | V13 | — |
| 密钥泄露 | 798 | A07 | V2.10 | CIS 4.2 |

---

> **本文档指引 SecGuardian 从当前 6 个活跃检测器扩展至 100 条 SAST 检测规则体系。**  
> 结合 [02_Secure_Coding](02_Secure_Coding.md) 的安全编码规范与 [06_SCA_Governance](06_SCA_Governance.md) 的开源组件治理，形成完整代码安全防线。
