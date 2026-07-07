---
detector: thread-unsafe-signal
description: Detects unsafe signal handler operations that call non-async-signal-safe functions
severity: medium
cwe: CWE-479
cvss: 5.5
language: [c, cpp]
tags: [concurrency, signal, async-safety]
precision: medium
confidence: dynamic
target_functions: [call_stack, code_context, exit, fclose, fopen, fprintf, free, getenv, handler, judgment_rationale, malloc, openlog, pthread_mutex_lock, putenv, setenv, sigaction, signal, snprintf, sprintf, strcat, strcpy, strlen, syslog]
match_patterns: [signal\(|sigaction\(                          # → MUST: code_context (handler函数体), void.*handler.*int|void.*sig_handler          # 信号处理函数签名]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

信号处理器中调用了非异步信号安全的函数（如 `printf`/`malloc`/`free`/`pthread_mutex_lock`），在信号到达时如果程序正处于这些函数的执行中，可能造成死锁或数据损坏。POSIX 标准明确限定了信号安全函数列表。

**核心原则：信号处理器中只能调用 `write()`/`_exit()`/`signal()` 等 POSIX 明确列为 async-signal-safe 的函数。**

## 检测逻辑 (Detection Logic)

### Step 1: 识别信号处理函数 (Identify Signal Handlers)

```c
signal(SIGINT, handler);
sigaction(SIGINT, &sa, NULL);
```

### Step 2: 检查信号处理函数内容 (Inspect Handler Body)

**POSIX 信号安全函数清单 (Async-Signal-Safe Functions):**
`_exit`, `abort`, `accept`, `access`, `aio_error`, `aio_return`, `aio_suspend`, `alarm`, `bind`, `cfgetispeed`, `cfgetospeed`, `cfsetispeed`, `cfsetospeed`, `chdir`, `chmod`, `chown`, `clock_gettime`, `close`, `connect`, `creat`, `dup`, `dup2`, `execl`, `execle`, `execv`, `execve`, `faccessat`, `fchdir`, `fchmod`, `fchown`, `fcntl`, `fdatasync`, `fexecve`, `fork`, `fstat`, `fsync`, `ftruncate`, `futimens`, `getegid`, `geteuid`, `getgid`, `getgroups`, `getpeername`, `getpgrp`, `getpid`, `getppid`, `getsockname`, `getsockopt`, `getuid`, `kill`, `link`, `linkat`, `listen`, `lseek`, `lstat`, `mkdir`, `mkdirat`, `mkfifo`, `mknod`, `open`, `openat`, `pause`, `pipe`, `poll`, `posix_trace_event`, `pselect`, `pthread_kill`, `pthread_self`, `pthread_sigmask`, `raise`, `read`, `recv`, `recvfrom`, `recvmsg`, `rename`, `rmdir`, `select`, `sem_post`, `send`, `sendmsg`, `sendto`, `setgid`, `setpgid`, `setsid`, `setsockopt`, `setuid`, `shutdown`, `sigaction`, `sigaddset`, `sigdelset`, `sigemptyset`, `sigfillset`, `sigismember`, `signal`, `sigpause`, `sigpending`, `sigprocmask`, `sigqueue`, `sigset`, `sigsuspend`, `sleep`, `sockatmark`, `socket`, `socketpair`, `stat`, `symlink`, `symlinkat`, `sysconf`, `tcdrain`, `tcflow`, `tcflush`, `tcgetattr`, `tcsendbreak`, `tcsetattr`, `time`, `timer_getoverrun`, `timer_gettime`, `timer_settime`, `times`, `umask`, `uname`, `unlink`, `utime`, `utimensat`, `utimes`, `wait`, `waitpid`, `write`

**非信号安全的高危调用 (Unsafe Calls in Handler):**
```c
// BAD: 都不安全
void handler(int sig) {
    printf("signal %d\n", sig);   // 非安全！
    malloc(1024);                 // 非安全！
    free(ptr);                    // 非安全！
    fprintf(stderr, ...);         // 非安全！
    exit(1);                      // 非安全！应该用 _exit()
}
```

**安全模式 (Safe Pattern — Flag + Main Loop):**
```c
// GOOD: 设置标志位，让主循环处理
volatile sig_atomic_t got_signal = 0;
void handler(int sig) {
    got_signal = 1;               // 安全：sig_atomic_t 保证原子写入
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：信号处理函数的完整代码体，标注所有非 async-signal-safe 的函数调用及其行号
      → findings.evidence.code_context
- [ ] **judgment_rationale**：逐函数说明为何该调用不在 POSIX async-signal-safe 清单中，引用具体清单条目
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：N/A — 单点漏洞，信号到达路径为内核触发，无需数据流追踪
      → findings.evidence.data_flow_path
- [ ] **call_stack**：信号注册点（signal/sigaction 调用位置）→ 信号处理函数体
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：`volatile sig_atomic_t` 标志位是否存在、信号处理函数中修改的全局变量列表
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：编译时是否启用 `-Wnonnull` / `-Wunused-result` 等针对信号安全的检测标志
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **只使用安全函数**：`write()`/`_exit()`/`signal()`/`sig_atomic_t` 变量
2. **设置标志位模式**：信号处理器仅设置 `volatile sig_atomic_t flag = 1`，主循环检查标志
3. **signalfd (Linux)** 或 **kqueue (BSD)** 替代信号处理器

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `write(STDERR_FILENO, ...)` 单独使用 | write() 在 POSIX async-signal-safe 清单中 | 确认信号处理函数中仅调用 write() 及相关安全函数 |
| `sig_atomic_t` 赋值 | POSIX 标准保证 sig_atomic_t 类型的读写为原子操作 | 确认变量声明为 volatile sig_atomic_t，且仅在信号处理器中写入 |
| SIG_DFL/SIG_IGN 处理 | 未注册自定义信号处理函数，使用系统默认行为 | 确认 signal() 第二个参数为 SIG_DFL 或 SIG_IGN |
| sigaction handler 仅用 write() | 若信号处理器内所有函数调用均位于 POSIX 安全清单中 | 逐行审查 handler 体，确认每个调用均在安全清单内 |
| 信号处理器为空函数体 | 无函数调用，无副作用 | 确认 handler 体为 `{}` 或仅含 return |
| handler 仅调用 _exit() | _exit() 在 POSIX async-signal-safe 清单中 | 确认 handler 体仅包含 _exit() 调用，无其他逻辑 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===
signal\(|sigaction\(                          # → MUST: code_context (handler函数体)
                                              # → SHOULD: call_stack (注册点→handler)
void.*handler.*int|void.*sig_handler          # 信号处理函数签名
→ printf|fprintf|malloc|free|exit|pthread_mutex_lock|fopen|fclose  # → MUST: judgment_rationale (说明非安全原因)
→ strlen|strcpy|strcat|sprintf|snprintf       # 非安全：无锁保护
→ getenv|setenv|putenv                        # 非安全：修改全局环境
→ syslog|openlog                              # 非安全：内部使用 malloc

# === EXCLUDE (不报告) ===
→ volatile sig_atomic_t =                     # POSIX 保证原子性，仅设置标志位
→ write\(STDERR_FILENO|write\(STDOUT_FILENO  # write() 在安全清单中
→ _exit\(                                     # _exit() 在安全清单中
→ signal\(|sigaction\(|sigaddset\(|sigdelset\(|sigemptyset\(|sigfillset\(  # 信号管理函数均在安全清单中
→ handler 为空体或仅含 return                   # 无操作，无风险
```
