---
detector: resource-file-double-close
severity: high
cwe: CWE-675
language: [c, cpp]
tags: [resource, file, double-close, fd]
---

# 文件句柄重复关闭 (Double Close)

## 威胁定义

同一 `FILE*`/fd 被关闭两次。多线程场景下，第一次 close 后 fd 被其他线程的 `open()` 复用，第二次 close 会关闭不相关的文件。

## 检测逻辑

```c
// BAD: 同一函数内两次 close
fclose(fp);
// ...
fclose(fp);                      // DOUBLE CLOSE!

// BAD: goto 导致重复关闭
fclose(fp);
if (error) goto cleanup;
cleanup:
    fclose(fp);                   // 已被关闭

// GOOD: close 后置 NULL，重复关闭安全
fclose(fp);
fp = NULL;
if (fp) fclose(fp);               // NULL guard
```

## 修复指引

每次 `fclose`/`close` 后立即置 `NULL`/`-1`

## 检测模式汇总

```
fclose\(fp\).*\n.*fclose\(fp\)   # 同一变量两次 fclose
close\(fd\).*\n.*close\(fd\)     # 同一变量两次 close
```
