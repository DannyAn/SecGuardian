# Command Injection — 误报抑制策略

## 策略 1: 硬编码字符串确认

最常见的误报来源：system/popen 的参数看似变量，实际内容为编译期常量。

```c
// 伪误报: 变量实际只包含固定值
const char *action = "list";
system(action);     // 看似变量，实际为 const 字面量

// 真实误报: 宏展开
#define BACKUP_CMD "tar czf /backup/data.tar.gz /data"
system(BACKUP_CMD);
```

验证方法: 检查变量的赋值链，确认其最终来源仅为字面量（const char*/#define）。

## 策略 2: execve/execv 排除

execve/execv 不经过 shell 解析，参数以 argv 数组形式独立传递。仅当可执行文件路径或 argv[0] 也来自用户输入时考虑报告。

```c
// execve 参数数组 — 默认不报告
execve("/bin/ls", (char *[]){"/bin/ls", "-la", NULL}, environ);

// 但若程序路径来自用户输入，即使 execve 也需注意:
execve(user_path, argv, environ);  // 参数中 user_path 路径遍历风险
```

## 策略 3: 调用链输入验证分析

当 system/popen 的调用链中存在输入验证时，按以下标准评估抑制可能性:

| 验证类型 | 抑制级别 | 说明 |
|---------|---------|------|
| 严格白名单（枚举/switch） | 完全抑制 | 仅允许固定的几个命令 |
| 正则白名单（^[a-zA-Z0-9.-]+$） | 可抑制 | 禁止所有 shell 元字符 |
| 正则黑名单（检查 ; \| & ` 等） | 不抑制 | 黑名单可绕过（$(cat /etc/passwd)） |
| 仅 NULL/空字符串检查 | 不抑制 | 未检查注入字符 |
| 无任何验证 | 不抑制 | 确定报告 |

## 策略 4: 环境差异抑制

| 环境因子 | 抑制条件 | 说明 |
|---------|---------|------|
| 用户输入为纯栈本地变量（非外部传入） | 不抑制 | 除非确认变量值为内部生成 |
| argv 仅在函数内赋值后使用 | 报告 | 默认 argv 为不可信 |
| getenv 调用 | 报告 | 环境变量不可信（可被 LD_PRELOAD 等方式修改） |
| 测试代码（test/ *_test.c） | 选择性抑制 | 测试中若模拟注入场景，抑制为 low confidence |
| 嵌入式系统（无 shell /bin/sh） | 不抑制 | 嵌入式 shell 实现同样脆弱 |
| system("simple command") 不含参数 | 抑制 | 无双引号/变量，无注入点 |

## 策略 5: 格式字符串分析

当 system/popen 的参数通过 snprintf 构造时，分析格式字符串:

```c
// 格式字符串无 %s — 不拼接用户输入
snprintf(cmd, sizeof(cmd), "ls -la");
system(cmd);                  // 抑制 — 无 %s，cmd 是固定字符串

// 格式字符串有 %s 但对应的参数为内部值
int pid = getpid();
snprintf(cmd, sizeof(cmd), "kill %d", pid);
system(cmd);                  // 可抑制 — pid 是系统生成的整数，不是用户输入

// 格式字符串有 %s 且参数来自外部
snprintf(cmd, sizeof(cmd), "cat %s", argv[1]);
system(cmd);                  // 不抑制 — 含用户输入
```

## 策略 6: 指数回退 (Exponential Backoff)

同一 system/popen 调用点在多次扫描中重复被标记为注入漏洞，但人工审查确认为误报时:

| 重复 | 操作 |
|------|------|
| 第 1 次 | 正常报告（high confidence） |
| 第 2 次 | 降级 medium，注释建议白名单标为 false positive |
| 第 3 次 | 降级 low，添加 suppress-once 标签 |
| 4+ | 跳至 skip list 不报告 |

## 策略 7: unsigned char 类型白名单

```c
// 如果输入在 system 前被转换为特定类型且经过验证
unsigned int port = (unsigned int)atoi(argv[1]);  // 转为 unsigned
if (port < 1024 || port > 65535) return -1;        // 范围验证
char cmd[256];
snprintf(cmd, sizeof(cmd), "netstat -anp | grep %u", port);
system(cmd);  // port 为 unsigned int + 范围验证，注入风险极低
// 可降级为 low confidence
```

注意: 即使 port 值安全，格式字符串被注入的风险仍然存在（极低）。默认降级为 low 而非完全抑制。
