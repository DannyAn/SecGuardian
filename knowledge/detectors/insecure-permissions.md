---
detector: insecure-permissions
severity: medium
cwe: CWE-276
language: [c, cpp, java, python, go]
tags: [filesystem, permissions, configuration]
---

# 不安全的默认权限 (Incorrect Default Permissions)

## 检测概要

检查文件、目录、共享内存等资源在创建时是否设置了过于宽松的权限（全局可读/写/执行）。

## 检测逻辑

### Step 1: 搜索文件创建操作

```c
// C
FILE *f = fopen("/etc/app/config.ini", "w");  // 默认权限 666 & umask
open("/tmp/data", O_CREAT | O_WRONLY);         // 未指定权限位
mkdir("/var/data", 0777);                      // 宽松权限
```

```python
# Python
open("/etc/app/config.ini", "w").write(data)   # 默认权限
os.mkdir("/tmp/data", 0o777)                    # 777 权限
```

```java
// Java
File f = new File("/tmp/data");
f.createNewFile();                              // 默认权限
f.setExecutable(true, false);                   // 全局可执行
```

```go
// Go
os.OpenFile(path, os.O_CREATE|os.O_WRONLY, 0666)  // 默认 666
os.MkdirAll(dir, 0777)                              // 全局可写
```

### Step 2: 检查权限值

```c
// BAD: 全局可写
open(path, O_CREAT | O_WRONLY, 0666);   // 任何人可写
mkdir(path, 0777);                      // 任何人可写 + 执行

// GOOD: 最小权限
open(path, O_CREAT | O_WRONLY, 0600);   // 仅所有者读写
mkdir(path, 0750);                      // 所有者全部，组读+执行
```

```python
# BAD
os.chmod("/etc/config.ini", 0o777)  # 任何人可写

# GOOD
os.chmod("/etc/config.ini", 0o600)  # 仅所有者
```

### Step 3: 检查 umask 设置

```c
// BAD: 默认 umask 可能导致不安全
// 未主动设置 umask → 继承父进程 umask

// GOOD: 降低默认权限
umask(0077);  // 创建文件时默认 600，目录 700
```

### Step 4: 检查敏感路径

```
BAD: /etc/* + fopen("w") 无初始权限控制
BAD: /var/log/* + 0666 权限
BAD: 共享内存 + shm_open + 0777
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 公共数据目录（/tmp, 下载目录） | 设计上需要宽权限 |
| 容器内应用，单用户运行 | 多租户隔离由容器保证 |
| 创建后立即调整权限 | 补救措施存在 |
| Windows 环境 | ACL 模型不同 |

## 检测模式汇总

```
# 创建操作 + 宽松权限
fopen|open|mkstemp|creat|os\.open|createNewFile
→ 无权限参数 或 权限为 0666|0777|077

# chmod + 世界可写
chmod|fchmod|os\.chmod|Files\.setPosixFilePermissions
→ 777|666|0777|0666|all|everyone

# umask 未设置
main|启动|init 中
→ 无 umask 调用
```

## CWE 映射

- CWE-276: Incorrect Default Permissions
- CWE-266: Incorrect Privilege Assignment
- CWE-732: Incorrect Permission Assignment for Critical Resource
