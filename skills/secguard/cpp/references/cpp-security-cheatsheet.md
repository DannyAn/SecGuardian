# C/C++ 安全速查表

SecGuard 快速参考：C/C++ 内存安全和系统安全速查。

## Top 10 检测信号

| # | 检测信号 | 严重度 | 关联概念 |
|---|---------|--------|---------|
| 1 | `strcpy(dst, src)` 未检查 dst 大小 | Critical | buffer-overflow |
| 2 | `sprintf(buf, fmt)` 未限制长度 | Critical | buffer-overflow |
| 3 | `gets(buf)` 任何使用 | Critical | buffer-overflow |
| 4 | `printf(user_str)` 格式参数非字面量 | Critical | format-string |
| 5 | `system(user_cmd)` 用户命令拼接 | Critical | command-injection |
| 6 | `free(p)` 后再次访问 p | Critical | use-after-free |
| 7 | `malloc(user_size)` 溢出 risk | High | integer-overflow |
| 8 | `access(path)` 后 `open(path)` | High | toctou |
| 9 | `scanf("%s", buf)` 无宽度限制 | High | buffer-overflow |
| 10 | 信号处理器调用 `printf`/`malloc` | Medium | signal-safety |

## 编译器安全标志

```makefile
CFLAGS += -fstack-protector-strong -D_FORTIFY_SOURCE=2
CFLAGS += -Wformat -Wformat-security -Werror=format-security
LDFLAGS += -Wl,-z,relro,-z,now -pie -fPIE
```

## 安全替代函数速查

| 危险函数 | 安全替代 |
|---------|---------|
| `strcpy` | `strncpy` + 手动 null 终止 |
| `strcat` | `strncat` |
| `sprintf` | `snprintf` |
| `gets` | `fgets` |
| `scanf("%s")` | `scanf("%Ns")` 指定宽度 |
| `system` | `execve` (不经过 shell) |
