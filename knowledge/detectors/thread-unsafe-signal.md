---
detector: thread-unsafe-signal
severity: medium
cwe: CWE-479
language: [c, cpp]
tags: [concurrency, signal, async-safety]
---

# 信号处理函数中调用非安全函数 (Thread-Unsafe Signal)

## 检测概要

检查信号处理函数（signal handler）中是否调用了非异步信号安全的函数。

## 检测逻辑

### Step 1: 识别信号处理函数

```c
signal(SIGINT, handler);
sigaction(SIGINT, &sa, NULL);
```

### Step 2: 检查信号处理函数内容

**POSIX 信号安全函数清单 (关键):**
`_exit`, `abort`, `accept`, `access`, `aio_error`, `aio_return`, `aio_suspend`, `alarm`, `bind`, `cfgetispeed`, `cfgetospeed`, `cfsetispeed`, `cfsetospeed`, `chdir`, `chmod`, `chown`, `clock_gettime`, `close`, `connect`, `creat`, `dup`, `dup2`, `execl`, `execle`, `execv`, `execve`, `faccessat`, `fchdir`, `fchmod`, `fchown`, `fcntl`, `fdatasync`, `fexecve`, `fork`, `fstat`, `fsync`, `ftruncate`, `futimens`, `getegid`, `geteuid`, `getgid`, `getgroups`, `getpeername`, `getpgrp`, `getpid`, `getppid`, `getsockname`, `getsockopt`, `getuid`, `kill`, `link`, `linkat`, `listen`, `lseek`, `lstat`, `mkdir`, `mkdirat`, `mkfifo`, `mknod`, `open`, `openat`, `pause`, `pipe`, `poll`, `posix_trace_event`, `pselect`, `pthread_kill`, `pthread_self`, `pthread_sigmask`, `raise`, `read`, `recv`, `recvfrom`, `recvmsg`, `rename`, `rmdir`, `select`, `sem_post`, `send`, `sendmsg`, `sendto`, `setgid`, `setpgid`, `setsid`, `setsockopt`, `setuid`, `shutdown`, `sigaction`, `sigaddset`, `sigdelset`, `sigemptyset`, `sigfillset`, `sigismember`, `signal`, `sigpause`, `sigpending`, `sigprocmask`, `sigqueue`, `sigset`, `sigsuspend`, `sleep`, `sockatmark`, `socket`, `socketpair`, `stat`, `symlink`, `symlinkat`, `sysconf`, `tcdrain`, `tcflow`, `tcflush`, `tcgetattr`, `tcsendbreak`, `tcsetattr`, `time`, `timer_getoverrun`, `timer_gettime`, `timer_settime`, `times`, `umask`, `uname`, `unlink`, `utime`, `utimensat`, `utimes`, `wait`, `waitpid`, `write`

**非信号安全的高危调用：**
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

**安全模式：**
```c
// GOOD: 设置标志位，让主循环处理
volatile sig_atomic_t got_signal = 0;
void handler(int sig) {
    got_signal = 1;               // 安全：sig_atomic_t 保证原子写入
}
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `write(STDERR_FILENO, ...)` | 信号安全的直接写入 |
| `sig_atomic_t` 赋值 | 标准保证原子性 |
| SIG_DFL/SIG_IGN 处理 | 无需信号处理函数 |
| `sigaction` 中 SA_SIGINFO handler 用 `write()` | 若只使用信号安全函数则安全 |

## 检测模式汇总

```
# 信号处理函数
void.*handler.*int|void.*sig_handler
→ printf|fprintf|malloc|free|exit|pthread_mutex_lock
```