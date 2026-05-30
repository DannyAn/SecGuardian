---
detector: format-string
severity: critical
cwe: CWE-134
language: [c, cpp]
tags: [printf, exploitation, information-disclosure]
---

# 格式化字符串漏洞 (Format String)

## 检测概要

检查 `printf` 系列函数的格式参数是否来自用户输入或外部数据，攻击者可利用 `%n` 写入任意地址、`%s` 读取栈数据、`%x` 泄露内存布局。

## 检测逻辑

### Step 1: 搜索格式字符串非字面量的调用

定位以下函数的调用点：
```
printf        fprintf        sprintf        snprintf
dprintf       vprintf        vfprintf       vsprintf
syslog        setproctitle   err            warn

# C11 Annex K 安全版本 — 格式参数仍可能是变量，需同样检查
printf_s       fprintf_s       sprintf_s       snprintf_s
```

注意：`_s` 后缀的函数虽然防止了缓冲区溢出，但**不防止格式字符串攻击**。
`printf_s(user_input)` 和 `printf(user_input)` 一样危险 — `user_input` 中含 `%n` 仍可写入任意地址。

### Step 2: 检查格式参数

**危险模式：**
```c
// BAD: 用户输入直接作为格式字符串
printf(user_input);           // 格式字符串攻击!
fprintf(stderr, user_input);  // 同上
syslog(LOG_ERR, user_input);  // 同上

// BAD: 间接来自用户输入
char *fmt = get_user_format();
printf(fmt, arg1, arg2);      // 如果 fmt 含 %n 则危险

// BAD: 拼接后的格式字符串
char fmt[256];
sprintf(fmt, "Error: %s", user_msg);
printf(fmt);                  // 如果 user_msg 含 % 则危险
```

**安全模式：**
```c
// GOOD: 格式字符串是字面量
printf("%s", user_input);     // 安全——user_input 是数据不是格式
fprintf(stderr, "Error: %s\n", msg);
syslog(LOG_ERR, "%s", data);
```

### Step 3: 间接格式字符串路径

```c
// BAD: 包装函数传递非字面量格式字符串
void log_error(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);   // 检查 fmt 是否来自字面量
    va_end(ap);
}
// 调用者：log_error("%s", msg)  → 安全
// 调用者：log_error(user_input)  → 危险
```

### Step 4: C++ 流输出检查

```c++
// BAD: C++ 中使用 printf 风格
QString msg = getUserInput();
printf(msg.toStdString().c_str());  // 危险

// GOOD: C++ 流自动安全
std::cout << user_input;           // 安全——流式操作
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 格式字符串是编译期常量 | 如 `#define FMT "Value: %d\n"` |
| `snprintf(buf, n, "%s", src)` — 格式字面量 | 源数据作为参数而非格式 |
| `printf_s("%s", user)` — 格式是字面量 | `_s` 版本格式参数仍可能是常量 |
| C++ 流输出 (`std::cout`) | 不经过 printf 格式化机制 |

> **特别提醒**：`sprintf_s`、`printf_s` 等 C11 Annex K 函数**只防止溢出，不防格式字符串攻击**。如果格式参数是变量（非字面量），仍须报告。
| `puts(user_input)` / `fputs(user_input, f)` | 不解析格式说明符 |
| 格式化调用在测试代码中 | 测试环境下用户输入可控性不考虑 |

## 检测模式汇总

```
# 格式参数非字面量
printf|fprintf|sprintf|snprintf|syslog
→ 第一个参数不是 "..." 字符串字面量
→ 第一个参数来自变量|参数|返回值

# 特别的危险指示
printf.*%[^sd]     # 格式字符串字面量中以变量作为数据（可能参数和格式反了）
fprintf.*stderr.*user|input    # 用户输入作为格式参数

# 包装函数的格式参数传递
void.*log|error|warn.*const char *fmt
→ 内部调用 vfprintf|vsyslog
→ 调用者传入非字面量格式参数
```
