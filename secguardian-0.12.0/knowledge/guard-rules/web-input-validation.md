---
detector: input-validation
severity: high
cwe: CWE-20
language: [c, cpp, java, python, go]
tags: [web, validation, injection]
precision: high
confidence: dynamic
---

# 输入验证不足 (Improper Input Validation)

## 威胁定义 (Threat Definition)

用户输入在使用前未经过充分的类型/长度/格式/范围验证。输入验证不足是注入漏洞（SQL/命令/XSS）、缓冲区溢出和路径遍历的根本原因（CWE-20是CWE Top 25中影响面最广的类别）。

**核心原则：所有来自信任边界外的数据必须在使用前验证。验证必须是白名单模式（拒绝非白名单），而非黑名单模式（过滤已知危险字符）。**

## 检测逻辑 (Detection Logic)

### Step 1: 识别外部输入入口

```c
// C/C++: argv, getenv, scanf, fgets, read, recv
char *input = argv[1];
char *env = getenv("USER_INPUT");
scanf("%s", buffer);
```

```java
// Java: @RequestParam, @PathVariable, HttpServletRequest
@RequestParam("input") String input;
request.getParameter("user_input");
```

```python
# Python: request.args, request.form, input()
query = request.args.get("q", "")
user_input = input("Enter name: ")
```

```go
// Go: r.URL.Query(), r.FormValue()
username := r.URL.Query().Get("username")
```

### Step 2: 检查使用前是否有验证

```c
// BAD: 无验证直接使用
char *buf = (char *)malloc(strlen(input));
strcpy(buf, input);  // 未检查长度

// GOOD: 验证长度
if (strlen(input) >= MAX_SIZE) return -1;
```

```java
// BAD: 无验证
String sql = "SELECT * FROM users WHERE id = " + input;

// GOOD: 验证类型
if (!input.matches("\\d+")) return "Invalid input";
```

### Step 3: 检查不安全的使用模式

| 模式 | 风险 | 正确做法 |
|------|------|---------|
| 输入直接拼接 SQL | SQL 注入 | 参数化查询 |
| 输入直接传入 eval | 代码注入 | 白名单检查 |
| 输入直接做数组索引 | 越界访问 | 边界检查 |
| 输入直接格式化输出 | 格式化字符串 | 指定格式 |

### Step 4: 验证不充分检查

```c
// BAD: 只检查是否为空，未检查长度
if (strlen(input) == 0) return -1;     // 检查了存在性，未检查长度
strcpy(buf, input);                     // 如果 input > buf，溢出

// BAD: 类型检查不完整
if (!isdigit(input[0])) return -1;      // 只检查第一个字符
int val = atoi(input);                  // "999999999999" 越界
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：外部输入入口（argv/getenv/scanf/@RequestParam/request.args/r.URL.Query 等）及其后续使用点的完整代码，标注输入来源类型和信任边界位置
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析输入使用前是否存在验证——验证覆盖了哪些维度（类型/长度/格式/范围/字符集）；验证是白名单模式还是黑名单模式；是否存在验证不充分的场景（如只检查非空但未检查长度、只检查首字符类型等）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：输入从外部来源 → 变量赋值 → (可能验证) → 安全敏感操作（SQL/命令/文件路径/数组索引/格式化字符串）的完整数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：输入入口函数 → 中间处理函数 → 敏感 sink 函数的完整调用链，确认验证是否在调用链中持续有效
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：输入变量的实际值示例、验证表达式/正则、敏感 sink 函数的参数列表、输入是否来自内部系统（非用户可控）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在框架级验证（@Valid/@Validate/Bean Validation/JSR-303）、是否存在全局输入过滤器/拦截器（如 XSS Filter/WAF）
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **白名单验证**：允许的值列表 > 拒绝的值列表
2. **类型验证**：确保输入是期望的类型（整数/字符串/布尔/枚举）
3. **长度验证**：整数范围检查、字符串长度上限
4. **格式验证**：正则匹配期望的格式（邮箱/URL/IP/文件名）
5. **间接输入**：HTTP 头、环境变量、文件内容同样是外部输入

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 输入来自内部系统（非用户可控） | 信任边界内，验证风险低 | 确认输入来源为内部服务调用/消息队列/数据库读出，非 HTTP 请求/env/argv |
| 经过框架级验证 (@Valid, validator) | 框架已处理 | 确认使用了 @Valid/@Validate 注解或 JSR-303 Bean Validation，且验证规则覆盖类型/长度/格式 |
| 输入仅用于显示（不参与逻辑） | 无注入风险 | 确认输入仅用于 HTML 展示（且经过输出编码），不参与 SQL/命令/文件/数组索引操作 |
| 白名单检查（仅允许几个固定值） | 验证充分 | 确认使用枚举/switch/白名单集合验证，拒绝非白名单值，非黑名单过滤 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 外部输入 + 无验证
argv|getenv|scanf|fgets|read|recv|request\.get
                                                       # → MUST: code_context (输入入口+使用点)
→ 无 if.*check|if.*valid|if.*match|if.*len
→ 直接用于危险操作 (strcpy|exec|eval|query)
                                                       # → MUST: judgment_rationale (验证充分性分析)

# 验证只做存在性检查
if.*NULL|if.*empty|if.*== ""
→ 无长度/类型/格式检查
→ 直接进入安全敏感操作

# 输入直接做数组/指针索引
input.*\[.*input|input\[.*user
→ 无边界检查

# === EXCLUDE (不报告) ===
→ if.*strlen.*>=|if.*strlen.*> MAX      # 长度验证存在
→ if.*!.*matches|if.*!.*regex           # 格式/正则验证
→ if.*isdigit|if.*isalpha               # 类型字符验证
→ @Valid|@Validate|@Pattern              # 框架验证注解
→ \.matches\(|\.find\(|re\.match         # 格式验证模式
→ PreparedStatement|\.setParameter       # 参数化查询（避免 SQL 注入）
→ htmlspecialchars|html\.escape          # 输出编码（降低影响）
```
