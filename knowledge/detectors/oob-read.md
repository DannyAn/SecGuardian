---
detector: oob-read
severity: high
cwe: CWE-125
language: [c, cpp]
tags: [memory, bounds, read, information-leak]
---

# 越界读取 (Out-of-bounds Read)

## 检测概要

检查是否从分配的内存区域之外读取数据。越界读取可导致信息泄露（Heartbleed 类型）、程序崩溃和任意内存读取。

## 检测逻辑

### Step 1: 搜索越界读取模式

```c
// BAD: 读取超过字符串结束符
char buf[16] = "hello";
char c = buf[100];  // 读取 buf 之外的数据

// BAD: 负索引
int arr[10];
int val = arr[-1];  // 读取 arr 之前的数据

// BAD: 索引 >= 数组大小
int arr[10];
for (int i = 0; i <= 10; i++) {  // i=10 时越界
    val = arr[i];
}
```

### Step 2: 检查 memcpy/memmove 读取大小

```c
// BAD: memcpy 读取超过源缓冲区
memcpy(dst, src, user_len);   // 如果 user_len > src 大小

// BAD: 从消息中读取 header 时未校验
struct msg {
    uint16_t len;
    char data[0];
};
read_size = msg->len;            // 攻击者可设置 65535
memcpy(buf, msg->data, read_size);  // 越界读取

// GOOD: 校验长度
if (msg->len <= sizeof(msg->data)) {
    memcpy(buf, msg->data, msg->len);
}
```

### Step 3: 检查字符串读取操作

```c
// BAD: 无限制的字符串读取
char buf[64];
gets(buf);                      // Heartbleed 风格：读取直到换行，不检查大小
scanf("%s", buf);               // 无宽度限制，任意长字符串溢出
fgets(buf, 64, stdin);          // 安全的

// BAD: strlen 用在非 null 终止的缓冲区
char buf[4] = {'A', 'B', 'C', 'D'};  // 无 null 终止符
size_t len = strlen(buf);            // 读取到下一个 0x00 字节
```

### Step 4: 检查越界 read() 调用

```c
// BAD: read 从超过文件/套接字可读位置读取
char buf[1024];
ssize_t n = read(fd, buf, sizeof(buf));
// 如果 n < 0，读取失败；如果 n > 后续使用不当

// BAD: 从已关闭的文件描述符读取
close(fd);
read(fd, buf, sizeof(buf));  // 可能读取到其他文件数据
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 静态数组 + 编译期可确定边界 | 编译期安全 |
| 使用 `std::array::at()`（抛出异常） | 运行时边界检查 |
| 循环索引经 `min()` 限制了最大值 | 已做边界保证 |
| 从 mmap 文件的安全范围内读取 | 有范围校验 |

## 检测模式汇总

```
# 数组索引 >= 数组大小
arr\[user_var|arr\[i\] 中的 i 无边界检查
→ for.*i <=.*arr_size|for.*i >=.*arr_size

# memcpy 从用户控制长度
memcpy|memmove.*user|user.*memcpy
→ 无 if.*len < sizeof|if.*len <= MAX

# 无 null 终止符的字符串操作
strlen|strcpy|strcat|printf.*%s
→ 目标在赋值后未添加 '\0'
```

## CWE 映射

- CWE-125: Out-of-bounds Read
- CWE-126: Buffer Over-read
- CWE-786: Access of Memory Location Before Start of Buffer
