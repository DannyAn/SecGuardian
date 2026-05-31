---
detector: input-validation
severity: high
cwe: CWE-20
language: [c, cpp, java, python, go]
tags: [web, validation, injection]
---

# 输入验证不足 (Improper Input Validation)

## 威胁定义

用户输入在使用前未经过充分的类型/长度/格式/范围验证。输入验证不足是注入漏洞（SQL/命令/XSS）、缓冲区溢出和路径遍历的根本原因（CWE-20是CWE Top 25中影响面最广的类别）。

**核心原则：所有来自信任边界外的数据必须在使用前验证。验证必须是白名单模式（拒绝非白名单），而非黑名单模式（过滤已知危险字符）。**

## 检测逻辑

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

## 修复指引

1. **白名单验证**：允许的值列表 > 拒绝的值列表
2. **类型验证**：确保输入是期望的类型（整数/字符串/布尔/枚举）
3. **长度验证**：整数范围检查、字符串长度上限
4. **格式验证**：正则匹配期望的格式（邮箱/URL/IP/文件名）
5. **间接输入**：HTTP 头、环境变量、文件内容同样是外部输入

## 误报排除

| 场景 | 原因 |
|------|------|
| 输入来自内部系统（非用户可控） | 信任边界内，验证风险低 |
| 经过框架级验证 (@Valid, validator) | 框架已处理 |
| 输入仅用于显示（不参与逻辑） | 无注入风险 |
| 白名单检查（仅允许几个固定值） | 验证充分 |

## 检测模式汇总

```
# 外部输入 + 无验证
argv|getenv|scanf|fgets|read|recv|request\.get
→ 无 if.*check|if.*valid|if.*match|if.*len
→ 直接用于危险操作 (strcpy|exec|eval|query)

# 验证只做存在性检查
if.*NULL|if.*empty|if.*== ""
→ 无长度/类型/格式检查
→ 直接进入安全敏感操作

# 输入直接做数组/指针索引
input.*\[.*input|input\[.*user
→ 无边界检查
```

## CWE 映射

- CWE-20: Improper Input Validation (本检测器)
- CWE-1289: Improper Validation of Array Index
- CWE-129: Improper Validation of Array Index
