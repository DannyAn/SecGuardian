# 缓冲区溢出假阳性抑制策略 (False Positive Suppression)

## 编译期常量抑制

### 1. 栈数组 + sizeof 检查

```c
// SUPPRESS: sizeof 确认 dsize 与分配一致
char buf[256];
strcpy_s(buf, sizeof(buf), src);       // sizeof(buf) == 256 → 安全

char *p = buf;
strcpy_s(p, sizeof(buf), src);         // SUPPRESS: p 指向同数组

// DO NOT SUPPRESS: sizeof 指针
char *p = (char*)malloc(256);
strcpy_s(p, sizeof(p), src);           // sizeof(p) = 8 → 假阳性？不，这是真漏洞
```

### 2. 编译期字符串字面量

```c
// SUPPRESS: 源为固定常量
strcpy(buf, "hello");                  // 5 字节 < sizeof(buf)
sprintf(buf, "%d", 42);                // 固定格式，已知最大输出

// DO NOT SUPPRESS
sprintf(buf, "%s", user_input);        // 不可控输入
```

### 3. 已知安全包装函数模式

以下模式声明为"已知安全"，在 index.json 中标记后自动抑制：

```c
// KNOWN-SAFE: glibc strlcpy/strlcat
size_t strlcpy(char *dst, const char *src, size_t size);
size_t strlcat(char *dst, const char *src, size_t size);

// KNOWN-SAFE: C11 Annex K 函数
errno_t strcpy_s(char *dst, rsize_t dsize, const char *src);

// KNOWN-SAFE: Windows Secure CRT
char *gets_s(char *buf, rsize_t n);
```

### 4. 第三方库安全抽象

项目自行封装的抽象层，在 `index.json` 中可通过配置标记安全：

```c
// SUPPRESS IF: my_safe_strcpy 在 index.json safe_wrappers 列表中
my_safe_strcpy(buf, sizeof(buf), src);

// SUPPRESS IF: CHECKED_MEMCPY 为项目自定义安全宏
CHECKED_MEMCPY(dst, src, n, dst_capacity);
```

## 运行时保护抑制

**警告**: 以下运行时保护仅作为抑制参考，不可作为唯一豁免理由。必须同时满足编译期证据。

```c
// CAN SUPPRESS WITH EVIDENCE: 先检查后使用
if (strlen(user) < sizeof(buf)) {
    strcpy(buf, user);    // 检查在 strcpy 之前
}

// CAN SUPPRESS WITH EVIDENCE: 循环内有界
for (int i = 0; i < sizeof(buf) - 1 && src[i]; i++) {
    buf[i] = src[i];
}
buf[sizeof(buf) - 1] = '\0';
```

## 配置驱动抑制

在 index.json 或扫描配置中加入抑制规则：

```json
{
  "suppressions": [
    {
      "pattern": "strcpy\\(buf,\\s*\"[^\"]{0,10}\"\\)",
      "reason": "source is compile-time constant short string",
      "confidence": "high"
    },
    {
      "file_pattern": "test_*",
      "reason": "test files use large buffers",
      "confidence": "medium"
    },
    {
      "function": "known_safe_wrapper",
      "reason": "project-verified safe wrapper",
      "confidence": "high"
    }
  ]
}
```

## 抑制决策树

```
发现 strcpy(dst, src) 调用点
├─ dst 是栈数组 (char buf[N])
│  ├─ src 是编译期常量且 strlen(src) < N → SUPPRESS (high)
│  ├─ src 长度在当前函数内已检查并确认 < N → SUPPRESS (high)
│  ├─ src 是函数参数 → 查调用者
│  │  ├─ 所有调用者传入已知小缓冲区 → SUPPRESS (medium)
│  │  └─ 任一调用者传入不可控输入 → CONFIRM (high)
│  └─ src 是用户输入无检查 → CONFIRM (critical)
├─ dst 是指针 (char *)
│  ├─ dst 在前 N 行内分配且大小已知
│  │  ├─ 已有长度检查 → SUPPRESS (high)
│  │  └─ 无长度检查 → CONFIRM (critical)
│  └─ dst 是函数参数 → 查调用者 (深度 1)
│      ├─ 可确认大小 → 按结果判定
│      └─ 不可确认 → SUSPICIOUS (medium)
└─ dst 是 malloc 返回值
    ├─ 分配大小已知且检查 src 长度 → SUPPRESS (high)
    └─ 分配大小未知或 src 不可控 → CONFIRM (high)
```
