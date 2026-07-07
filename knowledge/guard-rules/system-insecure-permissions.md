---
detector: insecure-permissions
description: Detects insecure file or resource permission settings that may allow unauthorized access
severity: medium
cwe: CWE-276
cvss: 5.5
language: [c, cpp, java, python, go]
tags: [system, filesystem, permissions]
precision: high
confidence: dynamic
target_functions: [all, chmod, code_context, creat, createNewFile, everyone, fchmod, fopen, init, judgment_rationale, main, mkdir, mkstemp, open, setExecutable, umask, write]
match_patterns: [fopen|open|mkstemp|creat|os\.open|createNewFile, chmod|fchmod|os\.chmod|Files\.setPosixFilePermissions, main|启动|init 中]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

文件/目录/共享内存等资源创建时设置过于宽松的权限（如 0777/0666），导致任意用户可读写敏感数据或覆盖可执行文件。`chmod 0777` 和 `umask(0)` 后创建文件是典型高危模式。

**核心原则：文件创建默认使用最严格权限（0600/0700），仅在充分验证后放宽。`fopen`/`open` 必须显式指定 mode 参数。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索文件创建操作

```c
// C
FILE *f = fopen("/etc/app/config.ini", "w");  // 默认权限 666 & umask
open("/tmp/data", O_CREAT | O_WRONLY);         // 未指定权限位
mkdir("/var/data", 0777);                      // 宽松权限
```

```python
# Python
open("/etc/app/config.ini", "w").write(data)   # 默认权限
os.mkdir("/tmp/data", 0o777)                    # 777 权限
```

```java
// Java
File f = new File("/tmp/data");
f.createNewFile();                              // 默认权限
f.setExecutable(true, false);                   // 全局可执行
```

```go
// Go
os.OpenFile(path, os.O_CREATE|os.O_WRONLY, 0666)  // 默认 666
os.MkdirAll(dir, 0777)                              // 全局可写
```

### Step 2: 检查权限值

```c
// BAD: 全局可写
open(path, O_CREAT | O_WRONLY, 0666);   // 任何人可写
mkdir(path, 0777);                      // 任何人可写 + 执行

// GOOD: 最小权限
open(path, O_CREAT | O_WRONLY, 0600);   // 仅所有者读写
mkdir(path, 0750);                      // 所有者全部，组读+执行
```

```python
# BAD
os.chmod("/etc/config.ini", 0o777)  # 任何人可写

# GOOD
os.chmod("/etc/config.ini", 0o600)  # 仅所有者
```

### Step 3: 检查 umask 设置

```c
// BAD: 默认 umask 可能导致不安全
// 未主动设置 umask → 继承父进程 umask

// GOOD: 降低默认权限
umask(0077);  // 创建文件时默认 600，目录 700
```

### Step 4: 检查敏感路径

```
BAD: /etc/* + fopen("w") 无初始权限控制
BAD: /var/log/* + 0666 权限
BAD: 共享内存 + shm_open + 0777
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：文件/目录/共享内存创建操作的完整代码，包含 open/fopen/mkdir/os.OpenFile 等调用及其权限参数（或缺少权限参数的情况）、目标路径字符串
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析权限值的宽松程度——是否设置了 world-writable（0222/0002/0666/0777）、group-writable（0020/0022）权限位；是否主动调用了 umask 设置严格默认值；路径是否指向敏感目录（/etc/、/var/、~/.ssh/）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：权限值从代码常量/变量 → 系统调用的数据流，标注权限值在传递过程中是否被修改
      → findings.evidence.data_flow_path
- [ ] **call_stack**：文件创建 → 权限设置的调用链，确认是否在 open 后立即调用 fchmod 收紧权限（排除 TOCTOU 窗口）
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：文件路径（是否为敏感路径）、权限八进制值、当前进程 umask 值、目标文件是否已存在
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：部署环境中 umask 的系统级默认值、SELinux/AppArmor MAC 策略是否提供了额外保护、容器是否单用户运行
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 文件创建：`open(path, O_CREAT, 0600)` — 仅所有者读写
2. 目录创建：`mkdir(path, 0700)` — 仅所有者访问
3. 禁止 `chmod 0777` 和 `umask(0)`
4. 使用 `fchmod(fd, mode)` 在创建后立即设置权限（避免 TOCTOU）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 公共数据目录（/tmp, 下载目录） | 设计上需要宽权限 | 确认路径为系统标准公共目录（/tmp、/var/tmp、/dev/shm），且有 sticky bit 保护 |
| 容器内应用，单用户运行 | 多租户隔离由容器保证 | 确认容器以非 root 用户运行（USER 指令），且无其他用户共享容器 |
| 创建后立即调整权限 | 补救措施存在 | 确认在同一函数内 open 后紧跟 fchmod 收紧权限，中间无其他文件操作 |
| Windows 环境 | ACL 模型不同 | 确认目标平台为 Windows，使用 SetFileSecurity/ACL 而非 POSIX 权限模型 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 创建操作 + 宽松权限
fopen|open|mkstemp|creat|os\.open|createNewFile
                                                       # → MUST: code_context (创建操作+权限参数)
→ 无权限参数 或 权限为 0666|0777|077
                                                       # → MUST: judgment_rationale (权限宽松度分析)

# chmod + 世界可写
chmod|fchmod|os\.chmod|Files\.setPosixFilePermissions
→ 777|666|0777|0666|all|everyone

# umask 未设置
main|启动|init 中
→ 无 umask 调用

# === EXCLUDE (不报告) ===
→ 0600|0700|0500|0400                        # 最小权限
→ 0640|0750                                   # 组权限但不含 other
→ umask\(0[2-7][2-7][2-7]\)                   # umask 非零设置
→ fchmod\(fd,\s*06                             # 创建后立即收紧权限
→ /tmp/|/var/tmp/|/dev/shm/                   # 公共目录（排除 0777 敏感路径）
→ security\.manager|AccessController          # Java 安全管理器
```
