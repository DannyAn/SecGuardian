---
category: language
languages: [c, cpp, c++]
frameworks: [Qt, Boost, POCO, Win32 API, POSIX API]
---

# C/C++ 语言安全画像

C/C++ 的内存安全特性、危险函数清单、未定义行为和编译器安全选项。

## 危险函数清单

### 缓冲区溢出 (内存拷贝)
| 函数 | 风险 | 替代 |
|------|------|------|
| `strcpy(dst, src)` | 无边界检查 | `strncpy(dst, src, n)` + 手动截断 |
| `strcat(dst, src)` | 无边界检查 | `strncat(dst, src, n)` |
| `sprintf(buf, fmt, ...)` | 无边界检查 | `snprintf(buf, n, fmt, ...)` |
| `gets(buf)` | 完全无法安全使用 | `fgets(buf, n, stdin)` |
| `scanf("%s", buf)` | 无长度限制 | `scanf("%Ns", buf)` 指定宽度 |
| `vsprintf(buf, fmt, ...)` | 无边界检查 | `vsnprintf(buf, n, fmt, ...)` |
| `memcpy(dst, src, n)` | n 来自不可信源 | 验证 n ≤ dst 大小 |
| `memmove(dst, src, n)` | 同上 | 同上 |
| `bcopy(src, dst, n)` | 同上 | 同上 |

### 格式化字符串
| 函数 | 风险 |
|------|------|
| `printf(user_str)` | 格式字符串攻击 — `%n` 写入任意地址 |
| `fprintf(f, user_str)` | 同上 |
| `syslog(LOG_ERR, user_str)` | 同上 |
| `snprintf(buf, n, user_str)` | 同上（虽然限制了输出，但 `%n` 仍危险） |

### 命令执行
| 函数 | 风险 | 替代 |
|------|------|------|
| `system(user_cmd)` | Shell 注入 | `execve` 系列（不经过 shell） |
| `popen(user_cmd, "r")` | Shell 注入 | `fork+execve` |
| `execle`/`execlp` 路径受控 | 路径劫持 | 使用绝对路径 |

### 整数安全
| 模式 | 风险 |
|------|------|
| `size_t len + offset` | 整数溢出 wrap-around |
| `malloc(user_size)` | 大小为 0 或溢出 |
| `int * signed 比较 unsigned` | 符号转换导致检查绕过 |
| `size_t < 0` 检查 | 对无符号类型无意义 |
| `new int[n]` n 来自外部 | 分配过量内存 |

### 内存管理
| 模式 | 风险 |
|------|------|
| `malloc` 后未检查 NULL | 空指针解引用 |
| `free(ptr)` 后继续使用 ptr | Use-After-Free |
| `free(ptr)` 两次 | Double Free |
| 异常路径未释放资源 | 内存泄露 |
| C++ `new` 后异常未 `delete` | 泄露/不匹配 |

### 文件操作
| 模式 | 风险 |
|------|------|
| `open(user_path, ...)` 未验证 | 路径穿越 / 符号链接攻击 |
| `access(path, R_OK)` 后 `open(path)` | TOCTOU |
| `chmod` / `chown` 符号链接跟随 | 权限变更到错误文件 |
| `tmpfile()` / `tmpnam()` | 竞态条件 / 可预测文件名 |

### 进程/权限
| 模式 | 风险 |
|------|------|
| `setuid(0)` 未检查失败 | 权限维持失败未发现 |
| fork 后文件描述符未关闭 | fd 泄露到子进程 |
| 信号处理器中调用非异步安全函数 | 未定义行为 |

## 编译器安全

### 应启用的标志
```
-fstack-protector-strong   # Stack canary
-fPIE -pie                 # ASLR
-Wall -Wextra -Werror      # 编译时警告
-D_FORTIFY_SOURCE=2        # 加固内存函数
-Wformat -Wformat-security  # 格式字符串检查
-Wl,-z,relro -Wl,-z,now    # Full RELRO
-fno-omit-frame-pointer     # 便于调试
```

### C++ 特有问题
- RAII 违反（资源未绑定生命周期）
- 虚函数表覆盖（vtable 劫持）
- 异常抛出时的资源泄露
- `reinterpret_cast` 绕过类型安全
- Lambda 捕获引用悬空

## 检测优先级

1. `strcpy` / `strcat` / `sprintf` / `gets` → Critical
2. `printf(user_input)` → Critical
3. `system(user_input)` → Critical
4. `free(p)` 后使用 → Critical
5. `malloc(size)` 整数溢出 → High
6. TOCTOU `access+open` → High
7. 未启用栈保护 → Medium
