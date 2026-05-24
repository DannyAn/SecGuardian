---
detector: insecure-temp-file
severity: medium
cwe: CWE-377
language: [c, cpp]
tags: [system, filesystem, temp]
---

# 不安全临时文件 (Insecure Temporary File)

## 检测概要

检查临时文件创建是否使用了可预测的文件名或存在竞态条件的创建方式。

## 检测逻辑

### Step 1: 搜索临时文件创建

```c
// BAD: 可预测文件名
char tmp[256];
sprintf(tmp, "/tmp/myapp_%d", getpid());
fd = open(tmp, O_CREAT | O_RDWR, 0600);  // 竞态条件！
```

### Step 2: 危险模式

```c
// BAD: tmpnam 返回可预测名称
char *name = tmpnam(NULL);
fd = open(name, ...);            // 竞态！攻击者可抢占文件名

// BAD: mktemp 已废弃且不安全
char tmpl[] = "/tmp/myapp.XXXXXX";
mktemp(tmpl);                    // 未使用 mkstemp!

// BAD: 非独占创建
fd = open("/tmp/fixed_name", O_CREAT | O_RDWR, 0666);
```

### Step 3: 安全替代

```c
// GOOD: mkstemp 原子创建
char tmpl[] = "/tmp/myapp.XXXXXX";
int fd = mkstemp(tmpl);
if (fd < 0) return -1;

// GOOD: tmpfile (自动删除)
FILE *fp = tmpfile();

// GOOD: C++ filesystem
std::filesystem::path tmp = std::filesystem::temp_directory_path() / "myapp.XXXXXX";
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `mkstemp`/`mkostemp` | 原子操作，安全 |
| `tmpfile()` | 自动删除 + 原子 |
| `O_EXCL` 标志 | 独占创建 |
| `/run/user/$UID/` (Linux) | 用户私有目录 |

## 检测模式汇总

```
# tmpnam/mktemp 使用
tmpnam|mktemp|tempnam
→ 无 mkstemp 替代

# 可预测的 /tmp 路径
sprintf.*"/tmp/.*%d"
→ open|fopen (无 O_EXCL)

# 固定临时文件名
open("/tmp/fixed_...", O_CREAT
→ 无 O_EXCL 标志
```