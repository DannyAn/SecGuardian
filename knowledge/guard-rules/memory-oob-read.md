---
detector: oob-read
description: Detects out-of-bounds read vulnerabilities that may leak sensitive information
severity: high
cwe: CWE-125
cvss: 7.5
language: [c, cpp]
tags: [memory, bounds, read, information-leak]
precision: high
confidence: dynamic
target_functions: [arr, arr_size, code_context, fgets, gets, judgment_rationale, memcpy, memmove, read, strcat, strcpy, strlen, user, user_var]
match_patterns: [arr\[user_var|arr\[i\] 中的 i 无边界检查, memcpy|memmove.*user|user.*memcpy, strlen|strcpy|strcat|printf.*%s]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

程序读取超出缓冲区边界的数据，可能泄露敏感内存内容（密钥、栈 canary、ASLR 基址）。著名的 Heartbleed（CVE-2014-0160）即为此类漏洞。

**核心原则：读取操作的索引和长度必须在分配大小范围内。特别关注 memcpy 的第三个参数和循环索引。**

## 检测逻辑 (Detection Logic)

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

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含越界读取的完整代码块，标注缓冲区声明（大小/类型）、索引/偏移量变量的来源（用户输入/循环变量/网络数据）以及实际访问的偏移量范围
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析缓冲区大小与访问索引/长度的关系——索引是否可能 >= 缓冲区大小、memcpy 的 count 参数是否来自外部输入且未经边界校验、循环终止条件是否使用了 <= 而非 <
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：索引/偏移量从外部输入（argc/env/网络数据/文件）→ 数组索引操作 或 memcpy count 参数的完整数据流，标注每层的范围变换
      → findings.evidence.data_flow_path
- [ ] **call_stack**：若越界发生在被调用函数中（指针参数传递后），记录调用者传入的缓冲区实际大小与被调用者使用的大小
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：缓冲区的声明大小、索引变量的当前值/可能范围、memcpy count 参数的值、循环计数器边界
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在 AddressSanitizer 运行时保护（-fsanitize=address）、是否使用了 std::array::at()/std::vector::at() 带边界检查的访问
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **读取前验证**：确保索引/偏移量 < 缓冲区大小
2. **使用安全封装**：`std::vector::at()` 越界抛异常，`std::array::at()` 同理
3. **编译器保护**：启用 AddressSanitizer（`-fsanitize=address`）运行时检测
4. **C 代码**：保持缓冲区大小与读取长度的一致性校验

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 静态数组 + 编译期可确定边界 | 编译期安全 | 确认数组大小和索引均为编译期常量，且索引 < sizeof(array)/sizeof(element) |
| 使用 `std::array::at()`（抛出异常） | 运行时边界检查 | 确认使用 .at() 方法，非 operator[]，编译选项无 -D_GLIBCXX_DEBUG 禁用 |
| 循环索引经 `min()` 限制了最大值 | 已做边界保证 | 确认循环条件中有 `i < min(user_val, ARRAY_SIZE)` 或等效边界限制 |
| 从 mmap 文件的安全范围内读取 | 有范围校验 | 确认 mmap 长度 >= 读取偏移量，且在读取前有 if(offset < mmap_size) 检查 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 数组索引 >= 数组大小
arr\[user_var|arr\[i\] 中的 i 无边界检查
                                                       # → MUST: code_context (缓冲区声明+访问代码)
→ for.*i <=.*arr_size|for.*i >=.*arr_size
                                                       # → MUST: judgment_rationale (索引范围 vs 缓冲区大小)

# memcpy 从用户控制长度
memcpy|memmove.*user|user.*memcpy
→ 无 if.*len < sizeof|if.*len <= MAX

# 无 null 终止符的字符串操作
strlen|strcpy|strcat|printf.*%s
→ 目标在赋值后未添加 '\0'

# === EXCLUDE (不报告) ===
→ if\s*\(.*<\s*sizeof                          # 边界检查存在
→ if\s*\(.*<=\s*MAX|if\s*\(.*<=\s*LIMIT        # 上限检查
→ \.at\(                                        # C++ 安全访问
→ std::array|std::vector                        # C++ 安全容器
→ fgets\(.*sizeof                                # 安全 fgets 使用
→ min\(.*sizeof|min\(.*ARRAY_SIZE               # min 边界限制
```
