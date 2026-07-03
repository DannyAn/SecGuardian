---
detector: command-injection
severity: critical
cwe: CWE-78
language: [c, cpp, java, python, go, js]
tags: [system, injection, shell]
precision: very-high
confidence: dynamic
---

# 命令注入 (Command Injection)

## 威胁定义 (Threat Definition)

攻击者通过用户输入拼接系统命令，导致服务器执行恶意的操作系统命令。

**核心原则：用户输入不得直接拼接到系统命令中。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索命令执行函数 (Identify Command Execution Functions)

```c
system(cmd);
popen(cmd, mode);
execvp(file, argv);
execv(path, argv);
execlp(file, arg, ...);
```

### Step 2: 检查参数来源 (Trace Argument Sources)

```c
// BAD: 用户输入直接拼接
char cmd[256];
snprintf(cmd, sizeof(cmd), "ping %s", user_host);
system(cmd);                     // 注入: user_host = "8.8.8.8; rm -rf /"

// BAD: popen 同样危险
FILE *fp = popen(user_cmd, "r");

// BAD: exec 系列参数未验证
execlp(user_prog, user_prog, user_arg, NULL);
```

### Step 3: 安全替代 (Safe Alternatives)

```c
// GOOD: 使用 execve 传递结构化参数
char *argv[] = {"ping", "-c", "1", validated_host, NULL};
execve("/bin/ping", argv, envp);

// GOOD: 白名单校验
static const char *allowed[] = {"ls", "cat", "echo", NULL};
if (!is_allowed(user_cmd, allowed)) {
    return ERROR;
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：命令执行函数调用（system/popen/exec*）及其参数构造的完整代码，标注用户输入来源（argv/getenv/scanf/fgets/recv/read/HTTP request）和拼接方式（sprintf/strcat/字符串拼接/+）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析用户输入是否可达命令字符串——追踪输入源到命令执行点的数据流，判断是否有严格的验证/转义/白名单拦截；分析 shell 元字符（; | & ` $ ( ) < > \n）的过滤完整性
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入入口（argv/socket/HTTP request/file/fgets） → 中间处理（验证/转义/拼接） → 命令执行点（system/popen/exec*）的完整数据流，标注每步的变换和验证
      → findings.evidence.data_flow_path
- [ ] **call_stack**：命令执行点 → 上层调用者 → 入参来源函数（main/servlet/handler）的完整调用链，确认跨函数数据传递中是否存在验证缺失
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：命令字符串的最终值（若可获取）、shell 元字符是否被转义、白名单列表内容及匹配逻辑
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用沙箱/seccomp/AppArmor、是否使用 execve（绕过shell）替代 system/popen、是否对用户输入做正则校验
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **首选**：使用 API 而非命令执行
2. **次选**：参数数组形式调用，绕过 shell 解析（`execve` / `subprocess.run([...], shell=False)`）
3. **不得已时**：严格白名单 + shell 元字符转义

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 参数来源于编译期常量 | 命令字符串完全由代码中的字面量组成，无任何外部输入参与拼接 | 确认命令字符串由 const char* 字面量或编译期常量组成，无变量拼接 |
| `execve` 参数为可信列表 | execve 使用参数数组形式（argv[]），不经过 shell 解析，每个参数独立传递 | 确认 execve 的 argv 数组中每个元素为独立字面量或已验证值 |
| 输入经过强校验（仅为数字/IP/字母数字） | 输入验证正则严格限制了允许的字符集（如 ^[0-9.]+$ 仅允许数字和点），禁止 shell 元字符 | 确认验证逻辑使用白名单正则（非黑名单），且不包含 shell 元字符 |
| 硬编码命令字符串 | 命令完全硬编码，不含任何用户输入或外部数据的占位符/拼接 | 确认命令字符串为编译期常量，无可变部分 |
| 使用 execve/execv 替代 system/popen | execve/execv 直接执行可执行文件，不经过 /bin/sh 解析，消除了 shell 注入途径 | 确认使用 execv/execve 且文件路径为可信值（如 /bin/ping 而非用户输入） |
| shell=False + 参数列表 (Python subprocess) | subprocess.run([...], shell=False) 以参数列表形式传递，不启动 shell | 确认 shell=False 且第一个参数为可执行文件完整路径 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# system/popen 参数含用户输入
system\(|popen\(|ProcessBuilder|Runtime\.exec\(           # 命令执行函数
                                                           # → MUST: code_context (执行点+参数构造)
→ 参数含 argv|getenv|scanf|fgets|recv|read|request\.|args\.  # 用户输入来源
→ 同一变量经 sprintf|snprintf|strcat|strcpy 拼接后传入    # 拼接后执行
                                                           # → MUST: judgment_rationale (数据流追踪+shell元字符分析)

# exec 系参数可被控制
exec[lv]p?\(|exec[lv]\(                                    # exec 系列
→ 参数来自外部 (argv/socket/request/文件)                   # 外部可控参数
→ exec[lv]p 且程序名来自用户输入                             # execlp/execvp 在 PATH 中搜索

# 格式化后不含引号转义
snprintf|sprintf.*%s.*user|input                           # 格式化拼接用户输入
→ system|popen (同一变量)                                   # 无shell转义即执行

# Java 命令执行
Runtime\.getRuntime\(\)\.exec\(|ProcessBuilder\(.*request  # Java 命令执行 + 用户输入

# Python 命令执行
os\.system\(.*request|os\.popen\(.*request|subprocess\..*request  # Python 命令执行
subprocess\..*,\s*shell\s*=\s*True                           # 危险的 shell=True

# Go 命令执行
exec\.Command\(.*r\.URL\.Query|exec\.Command\(.*c\.Param   # Go 命令执行 + 用户输入

# === EXCLUDE (不报告) ===
→ execve\(|execv\(                                          # 不经过shell，参数数组传递
→ execve.*argv\[\].*= "..."                                # 每个参数为字面量
→ is_allowed|CHECK_CMD|validate_cmd|sanitize_cmd            # 白名单验证存在
→ ^[0-9.]+$|^[a-zA-Z0-9_-]+$                               # 严格白名单正则
→ const char \*cmd = "|#define CMD "                       # 编译期常量命令
→ subprocess\.run\(.*shell\s*=\s*False                      # Python shell=False
→ exec\.Command\(".*", (?!.*r\.URL|.*r\.Form|.*c\.Param)   # Go 硬编码命令名
→ /bin/ping|/bin/ls|/bin/cat                                # 绝对路径可执行文件（需验证参数部分）
```
