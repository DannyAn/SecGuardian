---
detector: toctou
severity: high
cwe: CWE-367
language: [c, cpp]
tags: [system, filesystem, race-condition]
---

# TOCTOU (Time-of-Check Time-of-Use)

## 威胁定义

程序在"检查条件"和"使用资源"之间存在时间差，攻击者利用这个窗口改变系统状态（替换符号链接、修改文件内容、改变权限）。覆盖文件系统 TOCTOU、权限检查竞态、数据库 SELECT-then-UPDATE 竞态。

**核心原则：检查和使用之间的操作必须原子化。**

## 检测逻辑

### Step 1: 识别 Check-Then-Use 模式

```c
// BAD: access 和 open 之间文件可能被替换
if (access(file, F_OK) == 0) {
    fd = open(file, O_RDONLY);   // TOCTOU: 中间可能被替换为符号链接
}
```

### Step 2: 常见危险组合

| Check 函数 | Use 函数 | 风险 |
|-----------|---------|------|
| `access()` | `open()` | 文件可能被替换 |
| `stat()` | `open()`/`fopen()` | 同上述 |
| `lstat()` | `open()` | 符号链接检查后仍可能变化 |
| `chmod()` | `open()` | 权限可能在执行时变化 |
| `chown()` | `open()` | 所有者可能在执行时变化 |

### Step 3: 安全做法

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

## 修复指引

1. **文件操作**：使用文件描述符（fd），避免路径操作（`fstat` → fd 操作 / `openat` + `O_NOFOLLOW`）
2. **数据库**：使用事务 + 行锁 或 `UPDATE ... WHERE version = ?`（乐观锁）
3. **权限检查**：检查后立即使用，或在操作内部再次验证

## 误报排除

| 场景 | 原因 |
|------|------|
| `fstat(fd, ...)` 在 `open` 后 | 文件描述符已锁定 |
| `openat(dirfd, name, O_NOFOLLOW)` | 限制目录 + 禁止跟随 |
| 单用户/不可写目录 | 攻击者无写入权限 |

## 检测模式汇总

```
# access/stat 后 open 同一文件
access|stat|lstat.*path
→ open|fopen (同一 path 变量)
→ 无 O_NOFOLLOW 标志
```
