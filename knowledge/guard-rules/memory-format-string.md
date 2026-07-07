---
detector: format-string
severity: critical
cwe: CWE-134
language: [c, cpp]
tags: [printf, exploitation, information-disclosure]
precision: very-high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "memory.format-string",
  "type": "guard-rule",
  "namespace": "memory",
  "severity": "Critical",
  "cwe": "CWE-134",
  "cvss": 9.8,
  "confidence": "dynamic",
  "precision": "very-high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "fprintf",
    "getenv",
    "my_log",
    "syslog",
    "va_end",
    "va_start",
    "vfprintf"
  ],
  "match_patterns": [],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

攻击者控制 printf 系列函数的格式参数，利用 `%n` 写入任意地址、`%s` 读取栈数据、`%x` 泄露内存布局。这是 C/C++ 特有的高危漏洞，可导致 RCE 或信息泄露。

**核心原则：格式字符串必须是编译期字面量，绝不能来自外部输入。** `printf_s(user_input)` 和 `printf(user_input)` **一样危险**——`_s` 版本只防止溢出，不防格式字符串攻击。

## 检测逻辑 (Detection Logic)

### Step 1: 格式参数为变量的 printf 调用

识别以下函数调用中第一个参数非字面量的情况：

| 函数 | 检测重点 |
|------|---------|
| `printf(fmt, ...)` | fmt 是否来自变量/参数/返回值 |
| `fprintf(stream, fmt, ...)` | 同上 |
| `sprintf(buf, fmt, ...)` | 同上 |
| `snprintf(buf, n, fmt, ...)` | 同上 |
| `syslog(priority, fmt, ...)` | 同上 |
| `dprintf(fd, fmt, ...)` | 同上 |
| `vfprintf` / `vsprintf` / `vsnprintf` | 包装函数中 fmt 参数的来源 |

### Step 2: 区分"格式变量"和"格式字面量"

```
# 必须报告 — 格式参数来自非字面量
printf(user_input);                    # 完全可控
printf(buf);                           # buf 内容非编译期常量
fprintf(stderr, msg);                  # msg 来自变量
syslog(LOG_ERR, error_text);           # error_text 来自变量
printf(getenv("FORMAT"));              # 环境变量可控

# 不报告 — 格式参数是编译期字面量
printf("%s\n", user_input);            # 格式是字面量
printf("Error: %d\n", code);           # 格式是字面量
fprintf(stderr, "Value: %x\n", val);   # 格式是字面量
```

### Step 3: 间接路径

```c
// 检查包装函数的调用者
void my_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);  // 需检查调用者传入的 fmt
    va_end(ap);
}
// 调用 my_log("%s", user) → 安全（字面量）
// 调用 my_log(user_msg)    → 危险（变量）
```

## 修复指引 (Remediation)

1. **必须**：第一个参数始终是字符串字面量：`printf("%s", user_input)`
2. **禁止**：`printf(user_input)` 任何形式
3. **包装函数**：如果必须传递动态格式字符串，在调用点添加注释确认格式来源可信任
4. **编译器保护**：启用 `-Wformat-security` 和 `-Werror=format-security`

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：printf系函数调用及格式参数来源
      → findings.evidence.code_context
- [ ] **judgment_rationale**：格式参数是否为编译期字面量
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：格式参数从来源到printf的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：printf调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：格式参数的实际值/来源变量内容
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用-Wformat-security编译选项
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| `printf("%s", var)` — 格式是字面量 | 数据作为参数，安全 | 确认第一个参数以双引号 `"` 开头，为编译期字符串字面量 |
| `printf(gettext("msg"))` — gettext 返回可信翻译 | 翻译表内容非用户可控 | 确认 gettext/_() 的输入为编译期字面量，翻译文件不可被用户篡改 |
| `printf("%s" + (flag ? 1 : 0), val)` — 仍为字面量指针算术 | 编译器仍可追踪 | 确认指针算术不改变格式字符串的本质内容，编译器可静态分析 |
| C++ `std::cout << var` | 不经过 printf 格式化机制 | 确认使用的是 C++ 流式 I/O，不涉及 printf 格式字符串解析 |
| `puts(str)` / `fputs(str, f)` | 不解析格式说明符 | 确认使用的是 puts/fputs 而非 printf/printf-like 函数 |
| 格式参数来自 `#define` 宏（展开为字面量） | 编译期常量 | 确认宏展开结果为字符串字面量，非用户可控输入 |
| 测试代码中可控输入的非利用场景 | 测试环境 | 确认代码位于 test/ 目录或测试函数中，且输入来自测试 fixture |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# printf 系第一个参数是变量（非引号开头）→ evidence: code_context
(printf|fprintf|sprintf|syslog|dprintf)\s*\([^"]     # 注意排除如 printf("...
(printf|fprintf|sprintf|syslog)\s*\(\s*\w+\s*[,;\)]  # 参数是变量名 → evidence: variable_state

# vprintf 系的包装函数——检查调用者传入的格式参数 → evidence: data_flow_path
(vfprintf|vsprintf|vsnprintf)\s*\([^)]*fmt  # fmt 参数向上追溯到调用者
→ 调用者传入 fmt 为非字面量 → evidence: call_stack

# 特例：格式字面量但错位 → evidence: judgment_rationale
printf\(user_input,   # 无额外参数——user_input 被当作格式!
```

### 排除模式 (EXCLUDE)

```
# 格式字面量（以 " 开头）→ evidence: code_context
printf\("[^"]*%[sdxc]  # 标准的 printf("format %s", var)

# puts/fputs（不解析%）→ evidence: code_context
\bputs\(|\bfputs\(

# C++ 流 → evidence: code_context
std::cout\s*<<|std::cerr\s*<<

# gettext 可信翻译源 → evidence: sanitizer_analysis
printf\(gettext\(|printf\(_\(|fprintf\([^)]*gettext\(

# #define 宏展开为字面量 → evidence: code_context
#define\s+\w+\s+"[^"]*%[sdxc]  # 格式字符串宏定义
```
