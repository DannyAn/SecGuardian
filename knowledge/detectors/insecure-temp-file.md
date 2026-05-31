---
detector: insecure-temp-file
severity: medium
cwe: CWE-377
language: [c, cpp]
tags: [system, filesystem, temp]
---

# 不安全临时文件 (Insecure Temporary File)

## 威胁定义

临时文件使用可预测的文件名（`/tmp/myapp.tmp`）或非原子的创建方式（先检查再创建），攻击者可提前创建同名文件或符号链接劫持。典型攻击：CWE-377 / 符号链接替换。

**核心原则：使用 `mkstemp()`/`tmpfile()` 等原子化创建函数，且设置严格权限（0600）。禁止使用 `mktemp()`（已被 POSIX 弃用）。**

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

## 修复指引

1. **C 代码**：使用 `mkstemp(template)` 原子创建（自动生成唯一文件名）
2. **C 代码**：使用 `tmpfile()` — 创建匿名临时文件，关闭时自动删除
3. **禁止**：`mktemp()`（POSIX 已弃用，可预测文件名）
4. **权限**：创建时指定 `0600` 权限，防止其他用户读取

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