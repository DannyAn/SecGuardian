---
detector: resource-file-leak
severity: high
cwe: CWE-775
language: [c, cpp]
tags: [resource, file, leak, fd, resource]
---

# 文件句柄泄漏 (File Descriptor Leak)

## 威胁定义

`fopen()`/`open()` 返回的文件句柄未在函数退出前关闭。长时间运行的服务会耗尽文件描述符，导致无法打开新文件或接受新连接（DoS）。`malloc` 未 `free` 属于 `memory.memory-leak`（CWE-401），不在本检测器覆盖范围。

## 检测逻辑

### Step 1: C 标准库 — 搜索文件打开

```c
// BAD: 所有路径都泄漏
FILE* fp = fopen(path, "r");     // 需要 fclose
int fd = open(path, flags);      // 需要 close
int fd = openat(dirfd, path, flags);
FILE* fp = freopen(path, mode, stream);
FILE* fp = tmpfile();
```

### Step 2: 验证无对应关闭

对每次 `fopen`/`open`，搜索同一作用域内的对应 `fclose`/`close`。

```c
// BAD: 错误路径泄漏
FILE* in = fopen(src, "r");
if (!in) return;
FILE* out = fopen(dst, "w");
if (!out) return;                // 'in' leaks!

// GOOD: goto cleanup 模式
FILE* fp = fopen(path, "r");
if (!fp) return;
int ret = do_work(fp);
fclose(fp);
```

### Step 3: C++ 安全替代

```cpp
// GOOD: RAII 自动关闭
std::ifstream ifs(path);         // 析构自动 close
```

## 修复指引

1. **C**: 使用 `goto cleanup` 或单出口 `fclose` 模式
2. **C++**: 使用 `std::fstream`（RAII）

## 误报排除

| 场景 | 原因 |
|------|------|
| `FILE*` 存入全局变量/传出参数 | 生命周期超出函数 |
| `fopen` 返回 NULL | 无需关闭 |
| C++ `std::fstream` 栈对象 | 析构自动关闭 |

## 检测模式汇总

```
fopen\s*\(.*\)(?!.*fclose)       # fopen 无对应 fclose
open\s*\(.*\)(?!.*close\s*\()    # open 无对应 close
```
