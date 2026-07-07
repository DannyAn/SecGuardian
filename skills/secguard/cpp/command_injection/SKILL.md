---
name: secguard-cpp-command_injection
description: "Detects OS command injection vulnerabilities where user-controlled input reaches shell execution functions"
category: language-specific
language: cpp
topic: [security]
signal_source: call_sites[category="exec"]
---

# Command Injection 检视算子

## 元数据

- id: injection.command_injection
- severity: critical
- cwe: CWE-78
- category: exec
- signal_source: call_sites[category="exec"]

## 信号预筛

- callee 匹配: system, popen
- 按信号分组: exec_call_sites — 每个 system/popen 调用为检测起点
- index.json 交集: symbols.functions 含 system 或 popen 时激活

## 检视协议

### Step 1: 信号确认

收集 index.json 中所有 system() 和 popen() 调用点。记录每个调用点的文件、行号、所在函数及参数表达式。

```c
system(cmd);            // 信号 1 — 字符串参数
popen(cmd, mode);       // 信号 2 — 字符串参数
```

注意: execve/execv/execlp/execvp 虽不经过 shell，但如果可执行文件路径或参数来自用户输入，仍有安全隐患。仅当 exec 系列的参数完全硬编码时才排除。

### Step 2: 证据链构建 (Source→Propagate→Sink)

对每个 system/popen 调用点，反向追踪参数来源：

- Source: argv（命令行参数）、getenv（环境变量）、scanf/fgets（标准输入）、recv/read（网络 socket）、文件读取
- Propagate: snprintf/sprintf/strcat/strcpy 拼接、字符串赋值、跨函数参数传递
- Sink: system(cmd) / popen(cmd, mode) — 执行点

```c
// Source: argv → Propagate: snprintf → Sink: system
char cmd[256];
snprintf(cmd, sizeof(cmd), "ping %s", argv[1]);   // 用户输入传播
system(cmd);                                       // Sink

// Source: getenv → Propagate: strcpy → Sink: popen
char buf[128];
strcpy(buf, getenv("QUERY_STRING"));               // 用户输入传播
FILE *fp = popen(buf, "r");                        // Sink
```

### Step 3: 参数审计

对 system/popen 的每个参数，执行以下分析：

**3.1 参数来源追踪**
- 如果参数是硬编码字符串字面量（`system("ls -la")`）→ 不报告
- 如果参数包含用户输入（argv、getenv、scanf、文件、socket）→ 报告

```c
// SAFE: 硬编码字符串
system("ls -la");

// INJECTION: argv 用户输入
system(argv[1]);

// INJECTION: getenv 环境变量
system(getenv("SHELL"));
```

**3.2 拼接分析**
检查参数是否通过 snprintf/sprintf/strcat/strcpy 拼接待。即使部分拼接来自用户输入，整体即为注入风险：

```c
// INJECTION: snprintf 拼接部分用户输入
char cmd[256];
snprintf(cmd, sizeof(cmd), "ping -c 4 %s", argv[1]);
system(cmd);  // argv[1] = "8.8.8.8; rm -rf /" → 注入

// INJECTION: strcat 拼接
char cmd[256] = "cat ";
strcat(cmd, argv[1]);
system(cmd);
```

**3.3 验证检查**
检查 system/popen 调用前是否有输入验证：
- 白名单验证（is_allowed / switch-case 枚举）→ 降低风险
- 黑名单过滤（仅过滤 ; | & `）→ 仍可能绕过
- 无任何验证 → 确定报告

### Step 4: 跨函数补证 (max depth 1)

当命令字符串通过函数参数传递时，在调用链中追踪构造过程。深度 1 层。

见 `references/cross-function.md`。

### Step 5: 5 轮反思

1. 参数来源是否为完全硬编码的字符串字面量？若是，不报告。
2. 参数是否包含任何形式的用户输入（argv、getenv、scanf、socket、文件）？若有，即使部分也报告。
3. 参数是否经 snprintf/sprintf 格式化拼接，且格式化字符串中含有 %s 对应用户输入？报告。
4. 是否有严格的输入验证（白名单、枚举验证、正则白名单）若验证充分，降级为 low confidence 或抑制。
5. execve/execv 是否使用参数数组形式（argv[]）？若所有参数均为硬编码字面量，不报告。

## 参考文件

- [规则模式](./references/rule.md) — 脆弱 vs 安全代码模式
- [例外规则](./references/exceptions.md) — 误报抑制规则
- [跨函数追踪](./references/cross-function.md) — 跨函数参数追踪 (max depth 1)
- [误报策略](./references/false-positive.md) — 误报抑制策略
