---
detector: privilege-escalation
severity: high
cwe: CWE-269
language: [c, cpp]
tags: [system, privilege, setuid]
precision: high
confidence: dynamic
---

# 权限提升 (Privilege Escalation)

## 威胁定义 (Threat Definition)

setuid/setgid 程序中权限操作不当——特权未及时丢弃、提权后未恢复、或权限检查可被绕过。攻击者可利用残留的高权限执行恶意操作。经典案例：`setuid(0)` 后未 `setuid(getuid())` 恢复。

**核心原则：最小权限原则——程序启动后立即用 `setgid(getgid())`/`setuid(getuid())` 丢弃特权，且不可恢复。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation Guide)

1. 程序启动后立即 `setgid(getgid()); setuid(getuid());` 永久丢弃特权
2. 如需临时提权，使用 `seteuid()`/`setegid()` + fork 子进程
3. 验证 `setuid(0)` 的返回值——失败必须退出程序
4. 使用 capabilities（Linux）替代完整的 setuid root

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 非 setuid 程序 | 无特权可提升 | 确认程序文件未设置 setuid/setgid 位（ls -l 无 s 位） |
| `prctl(PR_SET_NO_NEW_PRIVS, 1)` | SECCOMP 禁止提权 | 确认 prctl 调用存在且生效 |
| `capability` 基于能力而非 uid | 更细粒度 | 确认使用 cap_set_proc/cap_get_proc 等 capability API |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# seteuid 而非 setuid
seteuid(uid)              # 未丢弃 saved uid
→ 后续无 setuid 彻底降权
                                                       # → MUST: code_context (seteuid 调用+上下文)

# setuid 未检查返回值
setuid(uid);
→ (无 if 检查)
→ 后续以 root 操作
                                                       # → MUST: judgment_rationale (降权是否彻底)

# === EXCLUDE (不报告) ===
→ setuid\(getuid\(\)\)|setgid\(getgid\(\)\)               # 永久丢弃特权模式
→ setresuid|setresgid                                   # 使用 setresuid/setresgid 完整降权
→ PR_SET_NO_NEW_PRIVS|SECCOMP|no_new_privs              # 禁止提权机制
→ cap_set_proc|cap_get_proc|CAP_                        # Linux capabilities
→ if.*setuid.*<.*0.*exit                                # setuid 返回值检查
```
