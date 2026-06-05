---
detector: resource-file-use-after-close
severity: high
cwe: CWE-672
language: [c, cpp]
tags: [resource, file, use-after-close, fd]
---

# 文件句柄释放后使用 (Use-After-Close)

## Indexer Input

- `symbols.functions`: 定位包含 `fclose()`/`close()` 调用的函数
- 执行方式：从符号表筛选含 `fclose`/`close` 的函数，精准读取后检查 close 之后是否还有对同一 FILE*/fd 的读写，**不逐文件全文扫描**

## 威胁定义

`FILE*` 或 fd 在 `fclose()`/`close()` 后继续被引用。释放后的 fd 可能已被 OS 重新分配，写入操作会破坏其他文件的数据。

## 检测逻辑

```c
// BAD: fclose 后继续使用
fclose(fp);
fprintf(fp, "data");             // fp 已无效

// BAD: close 后使用 fd
close(fd);
write(fd, buf, len);             // fd 可能已被复用

// GOOD: 关闭后置 NULL/哨兵
fclose(fp);
fp = NULL;
```

## 修复指引

关闭后立即置 `fp = NULL` 或 `fd = -1`

## 检测模式汇总

```
fclose\(fp\).*\n.*\bfp\b         # fclose 后 fp 仍被引用
close\(fd\).*\n.*\bfd\b          # close 后 fd 仍被引用
```
