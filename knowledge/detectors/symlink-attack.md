---
detector: symlink-attack
severity: medium
cwe: CWE-61
language: [c, cpp]
tags: [system, filesystem, symlink]
---

# 符号链接攻击 (Symlink Attack)

## 检测概要

检查文件操作是否可能被攻击者通过符号链接重定向到意外目标。

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