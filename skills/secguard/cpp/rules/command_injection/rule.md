---
name: secguard-cpp-command_injection
description: "Detects OS command injection vulnerabilities where user-controlled input reaches shell execution functions"
category: language-specific
language: cpp
topic: [security]
skill_id: injection.command_injection
signal_filter: injection.command*
signal_source: call_sites[cat="exec"]
severity: critical
cwe: [CWE-78]
---

# command_injection 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `injection.command_injection` |
| signal_filter | `injection.command*`（供 `secguard ./src c injection.command_injection` 过滤匹配） |
| signal_source | `call_sites[cat="exec"]` |
| 默认严重度 | Critical |

---

## Scenario 1: system/popen 直接注入（CWE-78）

### 威胁定义

攻击者通过用户输入拼接系统命令，导致服务器执行恶意的操作系统命令。

**核心原则：用户输入不得直接拼接到系统命令中。** 区分"来自外部输入的命令执行"和"硬编码字符串的命令执行"——仅报告前者。

### 检测逻辑

**Step 1: 识别 system/popen 调用点**

收集所有 `system()` 和 `popen()` 调用。每个调用点为一个检测信号。

```c
system(cmd);            // 信号 — 字符串参数
popen(cmd, mode);       // 信号 — 字符串参数
```

**Step 2: 追踪参数来源（Source -> Propagate -> Sink）**

对每个 system/popen 调用点，反向追踪参数来源：

- **Source**: `argv`（命令行参数）、`getenv`（环境变量）、`scanf`/`fgets`（标准输入）、`recv`/`read`（网络 socket）、文件读取
- **Propagate**: `snprintf`/`sprintf`/`strcat`/`strcpy` 拼接、字符串赋值、跨函数参数传递
- **Sink**: `system(cmd)` / `popen(cmd, mode)` — 执行点

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

**Step 3: 参数审计**

对 system/popen 的每个参数：

1. **参数来源检查** — 如果参数是硬编码字符串字面量（`system("ls -la")`），不报告；如果包含用户输入，报告

   ```c
   // SAFE: 硬编码字符串
   system("ls -la");

   // INJECTION: argv 用户输入
   system(argv[1]);

   // INJECTION: getenv 环境变量
   system(getenv("SHELL"));
   ```

2. **拼接分析** — 检查参数是否通过 `snprintf`/`sprintf`/`strcat`/`strcpy` 拼接。即使部分拼接来自用户输入，整体即为注入风险

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

3. **验证检查** — 检查 system/popen 前是否有输入验证：
   - 白名单验证（is_allowed / switch-case 枚举）→ 可降级
   - 黑名单过滤（仅过滤 `; | & `` `）→ 仍可能绕过
   - 无任何验证 → 确定报告

### 检测模式

```
# MATCH（触发检测）

system(|popen(                                        # 命令执行函数
→ 参数含 argv|getenv|scanf|fgets|recv|read             # 用户输入来源
→ 同一变量经 sprintf|snprintf|strcat|strcpy 拼接后传入  # 拼接后执行

snprintf|sprintf.*%s.*argv|input                      # 格式化拼接用户输入
→ system|popen (同一变量)                              # 无shell转义即执行


# EXCLUDE（不报告）

system("hardcoded_string")                            # 硬编码字符串字面量
const char *cmd = "..."                                # 编译期常量

execve(|execv(                                        # 不经过shell，参数数组传递
execve.*argv[].*= "..."                               # 每个参数为字面量
→ /bin/ping|/bin/ls|/bin/cat                          # 绝对路径可执行文件

is_allowed|CHECK_CMD|validate_cmd|sanitize_cmd         # 白名单验证存在
^[0-9.]+$|^[a-zA-Z0-9_-]+$                           # 严格白名单正则
```

### 修复指引

1. **首选**：使用平台 API 而非系统命令执行（用 socket API 替代 `ping` 命令，用 `open`/`read`/`write` 替代 `cp` 命令）
2. **次选**：参数数组形式调用，绕过 shell 解析（`execve` 替代 `system`/`popen`）
3. **不得已时**：严格白名单 + shell 元字符转义

---

## Scenario 2: exec 系列参数可控（CWE-78）

### 威胁定义

exec 系列函数（execve/execvp/execlp 等）虽然不经过 shell 解析，但如果可执行文件路径或 argv 参数来自用户输入，仍存在安全隐患。攻击者可利用 PATH 搜索机制执行恶意可执行文件。

**核心原则：exec 系列的可执行文件路径和参数必须为硬编码或经过严格验证。**

### 检测逻辑

**Step 1: 识别 exec 系列调用点**

```c
execl(path, arg0, arg1, ..., NULL);      // 可执行文件路径 + 参数列表
execlp(file, arg0, arg1, ..., NULL);     // 在 PATH 中搜索 file
execv(path, argv);                        // 可执行文件路径 + argv 数组
execvp(file, argv);                       // 在 PATH 中搜索 file + argv 数组
execve(path, argv, envp);                 // 可执行文件路径 + argv 数组 + 环境变量
```

**Step 2: 检查参数来源**

```c
// INJECTION: execvp 程序名来自用户输入
execvp(user_provided_name, argv);
// 如果 user_provided_name = "rm;ls"，execlp 会在 PATH 中搜索 "rm;ls"
// 虽然不经过 shell，但可执行文件命名本身可能被利用

// INJECTION: execvp argv 来自用户
void run_with_args(const char *prog, char **user_args) {
    execvp(prog, user_args);     // 用户可控制程序和参数
}

// SAFE: execve 参数硬编码
execve("/bin/ping", (char *[]){"/bin/ping", "-c", "4", validated_host, NULL}, environ);
```

### 检测模式

```
# MATCH（触发检测）

exec[lv]p?\(|exec[lv]\(                                # exec 系列
→ 参数来自外部 (argv/socket/request/文件)                 # 外部可控参数
exec[lv]p 且程序名来自用户输入                            # execlp/execvp 在 PATH 中搜索

# EXCLUDE（不报告）

execve("/bin/ping", ...)                               # 可执行文件路径硬编码
execve.*argv[].*= "..."                                # 每个参数为字面量
is_allowed|CHECK_CMD|validate_cmd                        # 白名单验证存在
```

### 修复指引

1. 使用 `execve` 并确保可执行文件路径为硬编码绝对路径（如 `/bin/ping`）
2. 对所有参数实施白名单验证
3. 避免使用 `execlp`/`execvp`（涉及 PATH 搜索，引入额外风险）

---

## Worker 检视协议

### Step 1: 信号确认

收集 index.json 中所有 `system()`、`popen()` 及 `exec` 系列调用点。记录每个调用点的文件、行号、所在函数及参数表达式。

```c
system(cmd);            // 信号 1 — 字符串参数
popen(cmd, mode);       // 信号 2 — 字符串参数
execve(path, argv, e);  // 信号 3 — 参数数组
```

注意：execve/execv/execlp/execvp 虽不经过 shell，但如果可执行文件路径或参数来自用户输入，仍有安全隐患。仅当 exec 系列的参数完全硬编码时才排除。

### Step 2: 证据链构建（Source -> Propagate -> Sink）

对每个命令执行调用点，反向追踪参数来源：

| 环节 | 说明 |
|------|------|
| **Source** | argv（命令行参数）、getenv（环境变量）、scanf/fgets（标准输入）、recv/read（网络 socket）、文件读取 |
| **Propagate** | snprintf/sprintf/strcat/strcpy 拼接、字符串赋值、跨函数参数传递 |
| **Sink** | system(cmd) / popen(cmd, mode) / exec*(path, argv) — 执行点 |

```c
// Source: argv → Propagate: snprintf → Sink: system
char cmd[256];
snprintf(cmd, sizeof(cmd), "ping %s", argv[1]);
system(cmd);

// Source: getenv → Propagate: strcpy → Sink: popen
char buf[128];
strcpy(buf, getenv("QUERY_STRING"));
FILE *fp = popen(buf, "r");
```

### Step 3: 参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

对 system/popen/exec 的每个参数，执行以下分析：

**3.1 参数来源追踪**
- 如果参数是硬编码字符串字面量（`system("ls -la")`）→ 不报告
- 如果参数包含用户输入（argv、getenv、scanf、文件、socket）→ 报告

**3.2 拼接分析**
检查参数是否通过 snprintf/sprintf/strcat/strcpy 拼接。即使部分拼接来自用户输入，整体即为注入风险。

**3.3 验证检查**
检查命令执行前是否有输入验证：
- 白名单验证（is_allowed / switch-case 枚举）→ 降低风险
- 黑名单过滤（仅过滤 `; | & `` `）→ 仍可能绕过
- 无任何验证 → 确定报告

### Step 4: 跨函数补证（max depth 1）

当命令字符串通过函数参数传递时，在调用链中追踪构造过程。深度 1 层。

> 参考 [cross-function.md](references/cross-function.md)。

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → command_injection 参数可控）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 `cross_signal_analysis: true`

### Step 5: 事实锚定反思（3 问判定矩阵）

> 参考 [exceptions.md](references/exceptions.md) 确认边界情况。
> 参考 [false-positive.md](references/false-positive.md) 触发抑制。

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 参数来自外部源（argv, getenv, scanf, socket, 文件）?
**Q2**: Sink 前有校验（白名单/黑名单/正则）?
**Q3**: 纯字符串字面量（完全硬编码）?

判定矩阵规则：

| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

---

## 取证证据收集指引

### 必须收集（MUST）

- [ ] **code_context**：命令执行函数调用（system/popen/exec*）及其参数构造的完整代码，标注用户输入来源（argv/getenv/scanf/fgets/recv/read/HTTP request）和拼接方式（sprintf/strcat/字符串拼接/+）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析用户输入是否可达命令字符串——追踪输入源到命令执行点的数据流，判断是否有严格的验证/转义/白名单拦截；分析 shell 元字符（`; | & `` $ ( ) < >`）的过滤完整性
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）

- [ ] **data_flow_path**：用户输入入口（argv/socket/HTTP request/file/fgets）→ 中间处理（验证/转义/拼接）→ 命令执行点（system/popen/exec*）的完整数据流，标注每步的变换和验证
      → findings.evidence.data_flow_path
- [ ] **call_stack**：命令执行点 → 上层调用者 → 入参来源函数（main/servlet/handler）的完整调用链，确认跨函数数据传递中是否存在验证缺失
      → findings.evidence.call_stack

### 可选收集（MAY）

- [ ] **variable_state**：命令字符串的最终值（若可获取）、shell 元字符是否被转义、白名单列表内容及匹配逻辑
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用沙箱/seccomp/AppArmor、是否使用 execve（绕过 shell）替代 system/popen、是否对用户输入做正则校验
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "argv[1] 用户输入入口，通过 main 函数参数获取", "file": "src/ping.c", "line": 5},
    "propagate": {"description": "snprintf 将用户输入拼接到命令字符串中，格式 %s 无转义", "file": "src/ping.c", "line": 12},
    "sink": {"description": "拼接后的命令字符串传入 system() 执行，argv[1] 可包含 shell 元字符导致命令注入", "file": "src/ping.c", "line": 13}
  },
  "scenario": "Scenario 1: system/popen 直接注入",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
