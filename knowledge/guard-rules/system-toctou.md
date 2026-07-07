---
detector: toctou
description: Detects time-of-check/time-of-use race conditions in file system operations
severity: high
cwe: CWE-367
cvss: 7.5
language: [c, cpp]
tags: [system, filesystem, race-condition]
precision: medium
confidence: dynamic
target_functions: [access, code_context, data_flow_path, fopen, fstat, judgment_rationale, lstat, open, path, stat]
match_patterns: [access\(.*path|stat\(.*path|lstat\(.*path       # → MUST: code_context (check行), access\|stat\|lstat.*path]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

程序在"检查条件"和"使用资源"之间存在时间差，攻击者利用这个窗口改变系统状态（替换符号链接、修改文件内容、改变权限）。覆盖文件系统 TOCTOU、权限检查竞态、数据库 SELECT-then-UPDATE 竞态。

**核心原则：检查和使用之间的操作必须原子化。**

## 检测逻辑 (Detection Logic)

### Step 1: 识别 Check-Then-Use 模式 (Identify Check-Then-Use)

```c
// BAD: access 和 open 之间文件可能被替换
if (access(file, F_OK) == 0) {
    fd = open(file, O_RDONLY);   // TOCTOU: 中间可能被替换为符号链接
}
```

### Step 2: 常见危险组合 (Dangerous Check-Use Pairs)

| Check 函数 | Use 函数 | 风险 |
|-----------|---------|------|
| `access()` | `open()` | 文件可能被替换 |
| `stat()` | `open()`/`fopen()` | 同上 |
| `lstat()` | `open()` | 符号链接检查后仍可能变化 |
| `chmod()` | `open()` | 权限可能在执行时变化 |
| `chown()` | `open()` | 所有者可能在执行时变化 |

### Step 3: 安全做法 (Safe Pattern — Open-Then-Check)

```c
// GOOD: 先打开，再用 fstat 检查
fd = open(path, O_RDONLY | O_NOFOLLOW);
if (fd < 0) return -1;
fstat(fd, &st);
if (st.st_uid != expected_uid) {
    close(fd);
    return -1;
}
// 此时文件描述符 fd 锁定在打开时的文件上
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：check 操作的代码行 + use 操作的代码行，标注两者之间的指令序列及是否存在分支/函数调用插入
      → findings.evidence.code_context
- [ ] **judgment_rationale**：计算 check 和 use 之间的"攻击窗口"——两个操作之间是否存在系统调用、分支跳转、函数调用等可被抢占的时机，以及同一路径变量在此期间是否可被外部修改
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：路径变量从构造/接收到 check 再到 use 的完整流转，标注每个节点是否重新获取或验证
      → findings.evidence.data_flow_path
- [ ] **call_stack**：check 函数调用栈 → use 函数调用栈，确认是否在同一函数内还是跨函数调用
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：路径变量在 check 和 use 之间的值是否被重新赋值或重新获取（若被重新获取则缩小窗口）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用 O_NOFOLLOW / AT_SYMLINK_NOFOLLOW 标志、是否在 open 后使用 fstat 而非 stat
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **文件操作**：使用文件描述符（fd），避免路径操作（`fstat` → fd 操作 / `openat` + `O_NOFOLLOW`）
2. **数据库**：使用事务 + 行锁 或 `UPDATE ... WHERE version = ?`（乐观锁）
3. **权限检查**：检查后立即使用，或在操作内部再次验证

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `fstat(fd, ...)` 在 `open` 后 | 文件描述符在 open 时已绑定到具体 inode，后续通过 fd 操作不受路径替换影响 | 确认 fstat 参数为 open 返回的 fd，非路径字符串 |
| `openat(dirfd, name, O_NOFOLLOW)` | 限制目录范围 + 禁止符号链接跟随，消除了符号链接替换攻击面 | 确认同时使用 openat + O_NOFOLLOW，dirfd 为可信目录 |
| 单用户/不可写目录 | 攻击者无法在目标目录创建文件或符号链接 | 确认目录权限为非 root 不可写，且运行用户非 root |
| check 和 use 之间无任何可抢占点 | 两个操作在同一表达式内（如 `open(path, access(path, F_OK) == 0 ? ...)`）或之间无函数调用 | 确认 check 和 use 之间无分支、无函数调用、无系统调用 |
| 同一表达式/语句内完成 check+use | 原子表达式，无抢占窗口 | 确认 check 和 use 在同一语句中，中间无可抢占指令 |
| 使用 fstatat + AT_EMPTY_PATH | 通过已有 fd 间接引用，不依赖路径名 | 确认使用 fstatat(fd, "", &st, AT_EMPTY_PATH) 模式 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===
access\(.*path|stat\(.*path|lstat\(.*path       # → MUST: code_context (check行)
                                                # → MUST: judgment_rationale (攻击窗口分析)
→ open\(.*path|fopen\(.*path                    # 同一路径变量，check-use 窗口存在
→ 无 O_NOFOLLOW 标志                            # → SHOULD: data_flow_path (路径变量流转)
access\|stat\|lstat.*path
→ open\|fopen (同一 path 变量)                   # 跨函数需额外分析 → SHOULD: call_stack

# === EXCLUDE (不报告) ===
→ fstat\(fd,                                   # fd 已绑定 inode，不受路径替换影响
→ openat\(.*O_NOFOLLOW                         # 限制目录 + 禁止符号链接跟随
→ open\(.*O_EXCL                               # 独占创建，不存在竞态读
→ open\(.*O_NOFOLLOW.*fstat\(fd                # Open-Then-Fstat 模式，原子绑定后验证
→ 同一语句内完成 check + use                     # 无抢占窗口，原子表达式
→ access\(.*&&\s*open\(                         # 短路求值，同一条表达式
```
