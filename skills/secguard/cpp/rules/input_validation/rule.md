---
name: secguard-cpp-input_validation
description: "Detects missing or insufficient input validation where external input is used without proper length, type, or NULL checks — covering path traversal, symlink attacks, temp-file TOCTOU, and permission/privilege escalation"
category: language-specific
language: cpp
topic: [memory]
skill_id: validation.input
signal_filter: validation.input*
signal_source: call_sites[cat="exec"]
severity: high
cwe: [CWE-20]
---

# input_validation 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `validation.input` |
| signal_filter | `validation.input*`（供 `secguard ./src c validation.input` 过滤匹配） |
| signal_source | `call_sites[cat="exec"]` |
| 默认严重度 | High |

---

## Scenario 1: 路径穿越与符号链接劫持（CWE-22 / CWE-61）

### 威胁定义

攻击者使用 `../` 等特殊字符突破预期的文件目录边界，或将文件路径中的某部分替换为符号链接，将文件操作重定向到敏感文件（如 `/etc/passwd`、`/etc/shadow`）。

**核心原则：文件路径操作中，用户输入不得直接影响路径解析结果。对共享目录中的文件，使用 `O_NOFOLLOW` 标志或 `lstat()` 检测符号链接后使用文件描述符操作。**

### 检测逻辑

**Step 1: 识别外部输入来源（Source）**

```c
char *file = getenv("FILE_PATH");   // 环境变量指定文件路径
char *name = argv[1];               // 命令行参数指定文件名
scanf("%s", name);                  // 标准输入指定文件名
```

**Step 2: 追踪路径构造与文件操作（Propagate → Sink）**

```c
// BAD: 直接拼接用户路径 — 路径穿越
char full_path[256];
snprintf(full_path, sizeof(full_path), "/var/www/%s", user_file);
FILE *fp = fopen(full_path, "r");       // user_file = "../../etc/passwd"

// BAD: 无 O_NOFOLLOW — 符号链接跟随
int fd = open(user_path, O_RDONLY);     // 若为 symlink，跟随到目标

// BAD: fchmodat 默认跟随符号链接
fchmodat(AT_FDCWD, user_path, 0777, 0);

// BAD: realpath 使用不当（TOCTOU）
char resolved[PATH_MAX];
realpath(user_path, resolved);
fd = open(resolved, O_RDONLY);          // 解析前可能已被替换
```

**Step 3: 安全模式**

```c
// GOOD: realpath 解析后前缀校验
char resolved[PATH_MAX];
if (realpath(user_path, resolved) == NULL) return -1;
if (strncmp(resolved, BASE_DIR, strlen(BASE_DIR)) != 0) return -1;
fd = open(resolved, O_RDONLY);

// GOOD: openat + O_NOFOLLOW
int dir_fd = open(BASE_DIR, O_RDONLY);
int file_fd = openat(dir_fd, basename(user_path), O_RDONLY | O_NOFOLLOW);

// GOOD: open 时禁止跟随符号链接
int fd = open(user_path, O_RDONLY | O_NOFOLLOW);

// GOOD: basename 提取文件名（去除目录部分）
fopen(basename(user_path), "r");
```

### 检测模式

```
# MATCH（触发检测）

# 路径拼接无过滤
snprintf|sprintf.*%s.*user|input|argv
→ open|fopen|opendir|stat (同一缓冲区)

# open 无 O_NOFOLLOW
open(path, 无 O_NOFOLLOW) → 路径可能来自外部

# fchmodat/fchownat 无 AT_SYMLINK_NOFOLLOW
fchmodat|fchownat → flag 字段为 0 (默认跟随)

# stat 跟随 symlink
stat(path) → 后续基于不完整信息做决策

# ../ 存在且无 realpath 校验
fopen|open → 参数含 .. → 无 realpath|basename 预处理

# EXCLUDE（不报告）
→ realpath\(.*\)\s*&&|if.*realpath       # realpath 解析后检查
→ strncmp.*realpath|strncmp.*resolved    # 前缀校验
→ openat\(.*O_NOFOLLOW                    # openat + 不跟随符号链接
→ basename\(                              # basename 剥离目录
→ O_NOFOLLOW|AT_SYMLINK_NOFOLLOW          # 已禁止跟随符号链接
→ lstat\(                                 # 使用 lstat 不跟随
→ unlink\(                                # unlink 操作 symlink 本身
→ chroot|sandbox|jail                     # chroot/sandbox 限制
→ UUID|uuid|hash.*file|file.*hash        # 哈希/UUID 文件名映射
```

### 修复指引

1. **路径穿越**：不直接用用户输入做文件名，使用 UUID/哈希映射；或 `realpath` + 前缀校验 / `openat` + `O_NOFOLLOW`
2. **符号链接**：`open(path, O_NOFOLLOW)` 禁止跟随符号链接；先 `lstat()` 再 `open()`
3. **Zip Slip**：解压前验证每个条目的规范路径（basename + realpath 前缀校验）

---

## Scenario 2: 临时文件安全与 TOCTOU 竞态（CWE-377 / CWE-367）

### 威胁定义

临时文件使用可预测的文件名（`/tmp/myapp.tmp`）或非原子的创建方式（先检查再创建），攻击者可提前创建同名文件或符号链接劫持。同时，程序在"检查条件"和"使用资源"之间存在时间差，攻击者可利用此窗口改变系统状态。

**核心原则：临时文件使用 `mkstemp()`/`tmpfile()` 等原子化创建函数且设置严格权限（0600）。检查和使用之间的操作必须原子化。**

### 检测逻辑

**Step 1: 识别临时文件创建**

```c
// BAD: 可预测文件名
char tmp[256];
sprintf(tmp, "/tmp/myapp_%d", getpid());
fd = open(tmp, O_CREAT | O_RDWR, 0600);    // 竞态条件！

// BAD: tmpnam 返回可预测名称
char *name = tmpnam(NULL);
fd = open(name, O_RDWR);                    // 竞态！攻击者可抢占文件名

// BAD: mktemp 已废弃且不安全
char tmpl[] = "/tmp/myapp.XXXXXX";
mktemp(tmpl);                               // 未使用 mkstemp!
```

**Step 2: 识别 Check-Then-Use 模式**

```c
// BAD: access 和 open 之间文件可能被替换
if (access(file, F_OK) == 0) {
    fd = open(file, O_RDONLY);              // TOCTOU: 中间可能被替换为符号链接
}

// BAD: stat 检查后 open
struct stat st;
if (stat(path, &st) == 0) {
    fd = open(path, O_RDONLY);              // 窗口：path 可能已被替换
}
```

**Step 3: 安全替代**

```c
// GOOD: mkstemp 原子创建
char tmpl[] = "/tmp/myapp.XXXXXX";
int fd = mkstemp(tmpl);
if (fd < 0) return -1;

// GOOD: tmpfile（自动删除）
FILE *fp = tmpfile();

// GOOD: 先打开，再用 fstat 检查（Open-Then-Check）
fd = open(path, O_RDONLY | O_NOFOLLOW);
if (fd < 0) return -1;
fstat(fd, &st);
if (st.st_uid != expected_uid) {
    close(fd);
    return -1;
}
```

### 检测模式

```
# MATCH（触发检测）

# tmpnam/mktemp 使用
tmpnam|mktemp|tempnam                    # 废弃/不安全的临时文件名生成
→ 无 mkstemp 替代

# 可预测的 /tmp 路径
sprintf.*"/tmp/.*%d"                     # 拼接进程ID — 可预测！
→ open|fopen (无 O_EXCL)

# 固定临时文件名
open("/tmp/fixed_...", O_CREAT → 无 O_EXCL 标志
open\(.*O_CREAT.*0666|open\(.*O_CREAT.*0777  # 过于宽松的权限

# TOCTOU check-then-use
access\(.*path|stat\(.*path|lstat\(.*path
→ open\(.*path|fopen\(.*path → 无 O_NOFOLLOW 标志

# EXCLUDE（不报告）
→ mkstemp\(|mkostemp\(                    # 原子创建
→ tmpfile\(                               # 匿名临时文件
→ open\(.*O_EXCL                          # 独占创建标志
→ open\(.*0600                            # 严格权限
→ /run/user/|/var/run/user/               # 用户私有运行时目录
→ mkdtemp\(                               # 原子创建唯一目录
→ open\(.*O_TMPFILE                       # 无名称临时文件
→ fstat\(fd,                              # fd 已绑定 inode
→ openat\(.*O_NOFOLLOW                    # 限制目录 + 禁止符号链接跟随
→ open\(.*O_EXCL                          # 独占创建
→ 同一语句内完成 check + use              # 无抢占窗口
```

### 修复指引

1. **临时文件**：C 代码使用 `mkstemp(template)` 或 `tmpfile()`；禁止 `mktemp()`（POSIX 已弃用）；创建时指定 `0600` 权限
2. **TOCTOU**：使用文件描述符（fd），避免路径操作（`fstat` → fd 操作 / `openat` + `O_NOFOLLOW`）；数据库使用事务 + 行锁或乐观锁
3. **C++**：使用 `std::filesystem::temp_directory_path()` 配合随机名

---

## Scenario 3: 权限管理缺陷（CWE-269 / CWE-276）

### 威胁定义

文件/目录/共享内存创建时设置过于宽松的权限（如 0777/0666），导致任意用户可读写敏感数据或覆盖可执行文件。setuid/setgid 程序中特权未及时丢弃或提权后未恢复，攻击者可利用残留的高权限执行恶意操作。

**核心原则：文件创建默认使用最严格权限（0600/0700）。最小权限原则——程序启动后立即用 `setuid(getuid())` 丢弃特权，且不可恢复。**

### 检测逻辑

**Step 1: 搜索文件创建与权限操作**

```c
// BAD: 全局可写权限
open(path, O_CREAT | O_WRONLY, 0666);     // 任何人可写
mkdir(path, 0777);                         // 任何人可写 + 执行
chmod("/etc/config.ini", 0777);            // 任何人可写

// BAD: 未指定权限位
open("/tmp/data", O_CREAT | O_WRONLY);    // 依赖 umask
```

**Step 2: 搜索特权操作**

```c
// BAD: seteuid 只改变 effective uid
seteuid(user_uid);                         // saved uid 仍为 0，可通过 seteuid(0) 恢复 root！

// BAD: 降权顺序错误
setgid(user_gid);
setuid(user_uid);                          // gid 可能未完全降权

// BAD: setuid 未检查返回值
setuid(user_uid);                          // 可能失败！
```

**Step 3: 安全替代**

```c
// GOOD: 最小权限
open(path, O_CREAT | O_WRONLY, 0600);     // 仅所有者读写
mkdir(path, 0750);                         // 所有者全部，组读+执行
umask(0077);                               // 创建文件时默认 600，目录 700

// GOOD: 永久丢弃特权
setgid(getgid());
setuid(getuid());                          // 不可恢复

// GOOD: setuid 返回值检查
if (setuid(user_uid) < 0) {
    perror("setuid failed");
    exit(1);
}
```

### 检测模式

```
# MATCH（触发检测）

# 创建操作 + 宽松权限
fopen|open|mkstemp|creat
→ 无权限参数 或 权限为 0666|0777|077

# chmod + 世界可写
chmod|fchmod → 777|666|0777|0666

# umask 未设置（main 中无 umask 调用）
main|启动|init 中 → 无 umask 调用

# seteuid 而非 setuid
seteuid(uid) → 后续无 setuid 彻底降权

# setuid 未检查返回值
setuid(uid) → (无 if 检查) → 后续以 root 操作

# EXCLUDE（不报告）
→ 0600|0700|0500|0400                    # 最小权限
→ 0640|0750                              # 组权限但不含 other
→ umask\(0[2-7][2-7][2-7]\)             # umask 非零设置
→ fchmod\(fd,\s*06                       # 创建后立即收紧权限
→ /tmp/|/var/tmp/|/dev/shm/             # 公共目录
→ setuid\(getuid\(\)\)                    # 永久丢弃特权模式
→ setresuid|setresgid                     # 完整降权
→ PR_SET_NO_NEW_PRIVS|SECCOMP            # 禁止提权机制
→ cap_set_proc|cap_get_proc|CAP_         # Linux capabilities
→ if.*setuid.*<.*0.*exit                 # setuid 返回值检查
```

### 修复指引

1. **文件权限**：`open(path, O_CREAT, 0600)` — 仅所有者读写；`mkdir(path, 0700)` — 仅所有者访问；禁止 `chmod 0777` 和 `umask(0)`
2. **特权管理**：程序启动后立即 `setgid(getgid()); setuid(getuid());` 永久丢弃特权；使用 `capabilities`（Linux）替代完整的 setuid root
3. **exec 安全**：exec 前关闭所有 fd 并清空环境变量，防止子进程继承高权限

---

## Worker 检视协议

### Step 1: 信号确认

对每个预筛信号（callee 匹配：`getenv`, `scanf`, `sscanf`, `atoi`, `atol`, `strtol`）：
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在（排除注释/宏/条件编译）
3. 按 Scenario 分类：文件路径操作 → S1，临时文件/TOCTOU → S2，权限操作 → S3，否则归入基础输入验证

### Step 2: 证据链构建（Source → Propagate → Sink）

对每个外部输入 API 调用点，追踪输入值的使用路径：

| 环节 | 说明 |
|------|------|
| **Source** | getenv/scanf/sscanf/atoi/atol/strtol 调用点 |
| **Propagate** | 变量赋值、类型转换、传递给其他函数 |
| **Sink** | 安全敏感操作 — strcpy/sprintf/malloc/snprintf/system/popen/socket/connect/文件路径操作/数组索引 |

```c
// Source: getenv → Propagate: 变量赋值 → Sink: strcpy 到固定缓冲区
char *input = getenv("HOME");        // Source
char buf[64];
strcpy(buf, input);                  // Sink: 缓冲区溢出可能

// Source: atoi → Propagate: 直接赋值 → Sink: malloc 大小参数
int size = atoi(argv[1]);            // Source
void *ptr = malloc(size);           // Sink: 整数可能为负或零

// Source: scanf → Sink: 无宽度限制直接写缓冲区
scanf("%s", buf);                    // 同时是 Source 和 Sink
```

### Step 3: 参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。

对每个输入 API 调用点的结果，检查下游使用前是否存在充分验证：

**3.1 getenv 检查**
```c
// BAD: 无 NULL 检查
char *home = getenv("HOME");
strcpy(buf, home);                   // home 可能为 NULL → 段错误

// GOOD: NULL 检查 + 长度验证
char *home = getenv("HOME");
if (home == NULL) return -1;
if (strlen(home) >= sizeof(buf)) return -1;
strcpy(buf, home);
```

**3.2 scanf/sscanf 检查**
```c
// BAD: 无宽度限制
scanf("%s", buf);                    // 用户输入超过 buf 大小 → 溢出

// GOOD: 指定宽度
scanf("%63s", buf);                  // 限制最多读 63 字符
```

**3.3 atoi/atol/strtol 检查**
```c
// BAD: 无范围/错误检查
int n = atoi(argv[1]);
malloc(n);                           // 负数 → 漏洞；超大值 → 拒绝服务

// GOOD: strtol 有错误检测
char *endptr;
long n = strtol(argv[1], &endptr, 10);
if (endptr == argv[1] || *endptr != '\0') return -1;
if (n < 0 || n > MAX_SIZE) return -1;
malloc((size_t)n);
```

### Step 4: 跨函数补证

> 参考 [cross-function.md](references/cross-function.md)。

当外部输入值通过函数参数传递到目标函数时，追踪目标函数内部是否执行验证。深度 1 层。

```c
void handler(char *input) {
    process_input(input);            // 传入被调用函数
}

void process_input(char *data) {
    system(data);                    // 无验证 → 命令注入
}
```

深度 > 1 → 降级为 "suspicious"，标记 confidence: medium。

### Step 4.5: 多信号归并分析

同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 `cross_signal_analysis: true`

### Step 5: 事实锚定反思（3 问判定矩阵）

> 参考 [exceptions.md](references/exceptions.md) 确认边界情况。
> 参考 [false-positive.md](references/false-positive.md) 触发抑制。

必须回答 3 个域专用事实问题，答案必须基于源码证据链中的行号引用。

**Q1**: 输入来自不可信源？
**Q2**: 使用前有验证（长度/格式/范围/类型）？
**Q3**: 验证足够严格（白名单而非黑名单）？

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
- [ ] **code_context**：外部输入 API 调用点、文件操作 API、临时文件创建、权限操作的完整代码，包含路径变量来源、标志位、权限参数
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析外部输入从接收点到安全敏感操作的完整链路——是否存在验证（NULL/长度/范围/类型）、文件路径是否经过 realpath+前缀校验或 openat+O_NOFOLLOW、特权是否完全丢弃
      → findings.evidence.judgment_rationale

### 建议收集（SHOULD）
- [ ] **data_flow_path**：外部输入 → 变量传播 → 安全敏感操作的完整数据流，标注每层是否存在验证
      → findings.evidence.data_flow_path
- [ ] **call_stack**：输入接收点 → 安全敏感操作函数调用链，确认跨函数验证是否到位
      → findings.evidence.call_stack

### 可选收集（MAY）
- [ ] **variable_state**：外部输入原始值、拼接后的完整路径字符串、权限八进制值、umask 值
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：realpath/openat+O_NOFOLLOW/basename 安全模式是否存在、chroot/sandbox 限制、SELinux/AppArmor MAC 策略、FORTIFY_SOURCE 启用情况
      → findings.evidence.sanitizer_analysis

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "getenv(\"HOME\") 获取环境变量输入", "file": "src/main.c", "line": 42},
    "propagate": {"description": "返回值直接赋值给 input 指针，未做 NULL 检查", "file": "src/main.c", "line": 43},
    "sink": {"description": "strcpy 以 input 为源拷贝到 64 字节栈缓冲区，输入可能为 NULL 或超长", "file": "src/main.c", "line": 45}
  },
  "scenario": "Scenario 1: 路径穿越与符号链接劫持",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```
