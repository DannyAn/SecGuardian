---
detector: privilege-escalation
severity: high
cwe: CWE-269
language: [c, cpp]
tags: [system, privilege, setuid]
---

# 权限提升 (Privilege Escalation)

## 检测概要

检查 setuid/setgid 程序中的权限操作安全性，包括特权丢弃是否正确、临时提权是否可被滥用。

## 检测逻辑

### Step 1: 搜索权限相关操作

```c
setuid(uid);
seteuid(euid);
setgid(gid);
setegid(egid);
setreuid(ruid, euid);
setregid(rgid, egid);
cap_set_proc(cap);
```

### Step 2: 危险模式

**模式 1：特权丢弃顺序错误**
```c
// BAD: 先 setgid 再 setuid 在某些系统上失败
setgid(user_gid);                // 此时仍是 root，可以执行
setuid(user_uid);                // 降权到 user，但 gid 可能未降

// GOOD: 先降 uid 再降 gid（或使用 setresgid/setresuid）
```

**模式 2：特权未完全丢弃**
```c
// BAD: seteuid 只改变 effective uid
seteuid(user_uid);               // saved uid 仍为 0
// 可以通过 seteuid(0) 恢复 root！
```

**模式 3：exec 前未清理特权**
```c
// BAD: exec 前未确保关闭所有 fd 和清空环境
execl("/bin/program", "program", user_input, NULL);
// 子进程继承了 root 的 fd 和环境变量
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 非 setuid 程序 | 无特权可提升 |
| `prctl(PR_SET_NO_NEW_PRIVS, 1)` | SECCOMP 禁止提权 |
| `capability` 基于能力而非 uid | 更细粒度 |

## 检测模式汇总

```
# seteuid 而非 setuid
seteuid(uid)              # 未丢弃 saved uid
→ 后续无 setuid 彻底降权

# setuid 未检查返回值
setuid(uid);
→ (无 if 检查)
→ 后续以 root 操作
```