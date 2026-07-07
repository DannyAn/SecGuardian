# 缓冲区溢出规则定义 (Buffer Overflow Rule Definitions)

## 概述

C/C++ 标准库的字符串和内存操作函数在缺少边界检查的情况下直接操作裸指针，是缓冲区溢出的主要来源。本规则覆盖 CWE-120 (Buffer Copy without Checking Size of Input) 和 CWE-787 (Out-of-bounds Write)。

## 高危函数清单

### 无边界检查函数（unsafe）

| 函数 | 风险等级 | 溢出条件 | CWE 变体 |
|------|---------|---------|---------|
| `strcpy(dst, src)` | Critical | src 长度 >= dst 分配大小 | CWE-121 (栈) / CWE-122 (堆) |
| `strcat(dst, src)` | Critical | strlen(dst) + strlen(src) >= dst 大小 | CWE-121 |
| `sprintf(buf, fmt, ...)` | Critical | 格式化结果长度 >= buf 大小 | CWE-121 |
| `memcpy(dst, src, n)` | High | n > dst 分配大小 或 dst+n 越界 | CWE-787 |
| `gets(buf)` | Critical | 输入长度 >= buf 大小（无限制） | CWE-120 |
| `wcscpy(dst, src)` | Critical | wcslen(src) * sizeof(wchar_t) >= dst 大小 | CWE-121 |

### 安全变体（需参数审计）

| 函数 | 契约 | 检查要点 |
|------|------|---------|
| `strcpy_s(dst, dsize, src)` | dsize > strnlen(src, dsize) | dsize 必须正确反映 dst 容量 |
| `strcat_s(dst, dsize, src)` | dsize > strnlen(dst, dsize) + strnlen(...) | dsize 为 dst 总容量 |
| `sprintf_s(buf, size, fmt, ...)` | size > 格式化结果长度 | size 必须等于 sizeof(buf) |
| `memcpy_s(dst, dsize, src, n)` | dsize >= n | dsize 是 dst 容量，n 是要复制的字节数 |
| `gets_s(buf, n)` | n > 输入长度 | n 必须 <= buf 分配大小 |
| `snprintf(buf, size, fmt, ...)` | 返回值 < size | 返回值 >= size 表示截断 |

## 漏洞模式

### 模式 1: strcpy 栈溢出

```c
// VULNERABLE
void parse_header(const char *input) {
    char buf[64];
    strcpy(buf, input);  // input 可能 > 63 字节
    // buf[64] 上方栈帧被覆盖
}

// SAFE
void parse_header(const char *input) {
    char buf[64];
    strncpy(buf, input, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = '\0';
}
```

### 模式 2: sprintf 格式化溢出

```c
// VULNERABLE
void log_message(const char *user) {
    char buf[256];
    sprintf(buf, "User: %s [%d]", user, get_id());
    // user 恶意构造超长字符串时可溢出 buf
}

// SAFE
void log_message(const char *user) {
    char buf[256];
    snprintf(buf, sizeof(buf), "User: %s [%d]", user, get_id());
}
```

### 模式 3: gets 无限制输入

```c
// VULNERABLE
void read_line() {
    char buf[128];
    gets(buf);  // 无长度限制，栈溢出
}

// SAFE
void read_line() {
    char buf[128];
    if (fgets(buf, sizeof(buf), stdin)) {
        buf[strcspn(buf, "\n")] = '\0';
    }
}
```

### 模式 4: strcpy_s 参数误用

```c
// VULNERABLE: dsize 参数错误
char dst[64];
strcpy_s(dst, 32, src);  // dsize=32 但 dst 实际容量 64，语义矛盾

// VULNERABLE: 用 sizeof 指针
char *dst = (char*)malloc(64);
strcpy_s(dst, sizeof(dst), src);  // sizeof(dst) = 8（指针大小），非 64
```

### 模式 5: 堆缓冲区 memcpy 溢出

```c
// VULNERABLE
char *buf = (char*)malloc(input_len);
memcpy(buf, src, user_len);  // user_len > input_len → 堆溢出

// SAFE
char *buf = (char*)malloc(input_len);
if (user_len <= input_len) {
    memcpy(buf, src, user_len);
} else {
    // 处理截断或重新分配
}
```
