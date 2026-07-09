# Command Injection — 例外规则

## 例外 1: 参数完全硬编码

命令字符串完全由代码中的字面量组成，无任何变量或外部数据参与拼接。

```c
// EXCEPTION: 完全硬编码的命令字符串
system("ls -la");                       // 无变量，纯字面量
system("date +%Y-%m-%d");               // 无变量

// NOT EXCEPTION: 即使有部分字面量，但包含变量拼接
char cmd[100];
snprintf(cmd, sizeof(cmd), "cat %s", filename);  // 含变量，需追踪来源
```

## 例外 2: execve/execv 参数数组形式

execve/execv 不经过 `/bin/sh` 解析，以参数数组形式直接传递给可执行文件，消除了 shell 注入途径。

```c
// EXCEPTION: execve 参数数组
char *argv[] = {"/bin/ls", "-la", "/tmp", NULL};
execve("/bin/ls", argv, environ);

// NOT EXCEPTION: execvp 可执行文件名来自用户输入
// execvp 会在 PATH 中搜索，如果第一个参数路径可控仍不安全
execvp(user_provided_name, argv);  // 程序名来自用户
```

## 例外 3: 白名单验证存在且充分

用户输入经过严格的白名单验证后传入命令执行函数。

```c
// EXCEPTION: 严格白名单验证后执行
static const char *valid_progs[] = {"ls", "cat", "echo", NULL};

if (!is_allowed(cmd, valid_progs)) {
    return ERROR;
}
system(cmd);   // cmd 已在白名单中 → 不报告

// NOT EXCEPTION: 黑名单过滤（仅过滤 ; | & `）
// 黑名单可绕过: $(), $(<file>), \n 等 shell 元字符
if (strstr(input, ";") || strstr(input, "|")) {
    return ERROR;  // 过滤不完整 — 仍报告
}
```

## 例外 4: 仅数字/IP 正则验证

如果用户输入经过严格的字符集白名单，仅允许数字、点和字母，且验证无误，可降级。

```c
// EXCEPTION: 正则验证仅允许数字和点
if (!regex_match(input, "^[0-9.]+$")) {
    return ERROR;  // 仅允许 IP 地址字符
}
// 此时 input 中不可能含 shell 元字符
```

## 例外 5: 编译期常量或宏定义

```c
// EXCEPTION: 编译期常量宏
#define BACKUP_CMD "tar czf /backup/data.tar.gz /var/data"

int backup(void) {
    system(BACKUP_CMD);  // 编译期常量 → 不报告
    return 0;
}
```

## 例外 6: 函数指针/回调间接执行

当 system/popen 通过函数指针间接调用，且实际调用的目标字符串无法静态确定时，本 skill 不报告（仅限于静态分析可达的直接调用）。

## 例外 7: argv[0] 程序自检（非用户输入）

在某些场景中，`argv[0]` 是程序自身路径（非用户提供的外部数据），可降级。

```c
// 检查 argv[0] 使用方式
// 如果 argv[0] 仅用于 self-inspection/help 消息，不用于命令拼接 → 低风险
// 但如果 argv[0] 被拼接到 system/popen 命令中 → 仍报告
```
