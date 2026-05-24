---
detector: command-injection
severity: critical
cwe: CWE-77
language: [c, cpp]
tags: [system, injection, shell]
---

# 命令注入 (Command Injection)

## 检测概要

检查是否将不可信输入直接传递给 shell 执行函数 (`system`/`popen`/`exec*` 系列)。

## 检测逻辑

### Step 1: 搜索命令执行函数

```c
system(cmd);
popen(cmd, mode);
execvp(file, argv);
execv(path, argv);
execlp(file, arg, ...);
```

### Step 2: 检查参数来源

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

### Step 3: 安全替代

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

## 误报排除

| 场景 | 原因 |
|------|------|
| 参数来源于编译期常量 | 无外部输入 |
| `execve` 参数为可信列表 | 白名单控制 |
| 输入经过强校验（仅为数字/IP） | 不可注入 |
| 硬编码命令字符串 | 无用户输入路径 |

## 检测模式汇总

```
# system/popen 参数含用户输入
system|popen
→ 参数含 argv|getenv|scanf|fgets|recv|read

# exec 系参数可被控制
exec[lv]p? 
→ 参数来自外部 (argv/socket/文件)

# 格式化后不含引号转义
snprintf|sprintf.*%s.*user|input
→ system|popen (同一变量)
```