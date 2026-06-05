---
detector: symlink-attack
severity: medium
cwe: CWE-61
language: [c, cpp]
tags: [system, filesystem, symlink]
---

# 符号链接攻击 (Symlink Attack)

## 威胁定义

程序对文件路径进行操作时，攻击者通过替换路径中某部分为符号链接，将操作重定向到敏感文件（如 `/etc/shadow`）。TOCTOU 场景中 access+open 的符号链接替换是典型攻击。

**核心原则：对共享目录中的文件，使用 `O_NOFOLLOW` 标志或 `lstat()` 检测符号链接后使用文件描述符操作。**

## 检测逻辑

### Step 1: 搜索无 O_NOFOLLOW 的 open

```c
// BAD: 跟随符号链接
int fd = open(user_path, O_RDONLY); // 若为 symlink，跟随到目标

// GOOD: 禁止跟随
int fd = open(user_path, O_RDONLY | O_NOFOLLOW);
```

### Step 2: 危险模式

**模式 1：创建文件时未禁止跟随**
```c
// BAD: 若 path 为 symlink，写入到 symlink 目标
int fd = open(path, O_CREAT | O_WRONLY, 0644);
```

**模式 2：递归删除跟随符号链接**
```c
// BAD: nftw/rm -rf 风格删除跟随 symlink
remove(user_path);               // 删除 symlink 目标而非 symlink 本身
unlink(user_path);               // 正确：删除 symlink 本身
```

**模式 3：chmod/chown 跟随符号链接**
```c
// BAD: fchmodat 默认跟随
fchmodat(AT_FDCWD, user_path, 0777, 0);  // 跟随 symlink!
// GOOD:
fchmodat(AT_FDCWD, user_path, 0777, AT_SYMLINK_NOFOLLOW);
```

## 修复指引

1. `open(path, O_NOFOLLOW)` — 如果目标是符号链接则失败
2. 先 `lstat()` 确认非符号链接，再用 `open()` 操作
3. 使用文件描述符（fd）操作替代路径操作
4. 共享目录中创建文件使用 `O_CREAT | O_EXCL` 原子操作

## 误报排除

| 场景 | 原因 |
|------|------|
| `open()` + `O_NOFOLLOW` | 已禁止跟随 |
| `lstat()` 代替 `stat()` | 不跟随 symlink |
| `unlink()` 删除 symlink 本身 | symlink 被安全处理 |
| 目录为 root 所有且不可写 | 攻击者无法创建 symlink |

## 检测模式汇总

```
# open 无 O_NOFOLLOW
open(path, 无 O_NOFOLLOW)
→ 路径可能来自外部

# fchmodat/fchownat 无 AT_SYMLINK_NOFOLLOW
fchmodat|fchownat
→ flag 字段为 0 (默认跟随)

# stat 跟随 symlink
stat(path)                # 使用 lstat 更安全
→ 后续基于不完整信息做决策
```
