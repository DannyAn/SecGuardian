---
detector: path-traversal
severity: high
cwe: CWE-22
language: [c, cpp]
tags: [system, filesystem, traversal]
---

# 路径遍历 (Path Traversal)

## 检测概要

检查文件操作中是否使用了未过滤的用户输入路径，允许 `../` 遍历到预期目录之外。

## 检测逻辑

### Step 1: 搜索文件操作

```c
fopen(path, mode);
open(path, flags);
stat(path, &buf);
opendir(path);
unlink(path);
```

### Step 2: 检查路径来源

```c
// BAD: 直接拼接用户路径
char full_path[256];
snprintf(full_path, sizeof(full_path), "/var/www/%s", user_file);
FILE *fp = fopen(full_path, "r"); // user_file = "../../etc/passwd"

// BAD: realpath 使用不当（TOCTOU）
char resolved[PATH_MAX];
realpath(user_path, resolved);   // 解析前可能已被替换
fd = open(resolved, O_RDONLY);
```

### Step 3: 安全模式

```c
// GOOD: 验证解析后的路径在允许范围内
char resolved[PATH_MAX];
if (realpath(user_path, resolved) == NULL) return -1;
if (strncmp(resolved, BASE_DIR, strlen(BASE_DIR)) != 0) return -1;
fd = open(resolved, O_RDONLY);

// GOOD: openat + O_NOFOLLOW
int dir_fd = open(BASE_DIR, O_RDONLY);
int file_fd = openat(dir_fd, basename(user_path), O_RDONLY | O_NOFOLLOW);
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `realpath` 解析 + 前缀校验 | 已做沙箱检查 |
| `openat` + `O_NOFOLLOW` | 限制在基础目录内 |
| `basename()` 提取文件名 | 去除了目录部分 |
| 白名单文件名映射 | 用户输入仅作为 key |

## 检测模式汇总

```
# 路径拼接无过滤
snprintf|sprintf.*%s.*user|input|argv
→ open|fopen|opendir|stat (同一缓冲区)

# ../ 存在且无 realpath 校验
fopen|open
→ 参数含 ..
→ 无 realpath|basename 预处理
```