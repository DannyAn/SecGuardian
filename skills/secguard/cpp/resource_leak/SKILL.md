---
name: secguard-cpp-resource_leak
description: "Detects file descriptor and socket descriptor leaks where opened resources are not properly closed on all exit paths"
category: language-specific
language: cpp
topic: [io]
signal_source: call_sites[category="io"]
---

# Resource Leak 检视算子

## 元数据

- id: resource.resource_leak
- severity: high
- cwe: CWE-404
- category: io
- signal_source: call_sites[category="io"]

## 信号预筛

- callee 匹配: fopen, open, socket, fclose, close
- 按信号分组: alloc_close_pairs — 每个 fopen/open/socket 必须有对应 fclose/close
- index.json 交集: symbols.functions 含上述任一 callee 时激活

## 检视协议

### Step 1: 信号确认

收集 index.json 中所有 fopen/open/socket/accept 调用点，构建 alloc_list。同时收集 fclose/close 调用点构建 close_list。对每个 alloc 点，记录目标变量名和文件/行号。

关键鉴别：每个 fopen/open/socket 调用都创建一个需要后续释放的资源。malloc/free 属于 memory-leak（CWE-401），不在本 skill 范围。

### Step 2: 证据链构建 (Source→Propagate→Sink)

对每个 alloc 点，追踪资源变量的生命周期：
- Source: fopen(path, "r") / open(path, flags) / socket(AF_INET, SOCK_STREAM, 0) — 创建点
- Propagate: 变量赋值、作为参数传递给其他函数、存入结构体/全局变量
- Sink: fclose(fp) / close(fd) — 释放点，或 return — 泄漏点

### Step 3: 参数审计

对每个 alloc 点所在函数，枚举所有退出路径（return 语句、goto 跳转、函数末尾隐式返回）。逐条路径检查：

1. 正常路径: 是否存在对应 fclose/close？
2. 错误路径 (NULL/负值检查后 return): 是否在 return 前 close？
3. goto cleanup 路径: cleanup 标签是否包含 close？

```c
// BAD: 错误路径泄漏
FILE *fp = fopen(path, "r");
if (!fp) return -1;              // OK: NULL 不需要关闭
FILE *out = fopen(dst, "w");
if (!out) return -1;             // LEAK: fp 未关闭

// BAD: socket 错误路径泄漏
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;         // OK: 无效 fd 不需要关闭
if (bind(sock, ...) < 0) return -1;  // LEAK: sock 未关闭

// GOOD: goto cleanup 统一释放
FILE *fp = fopen(path, "r");
if (!fp) return -1;
if (do_work(fp) < 0) goto cleanup;
fclose(fp);
return 0;
cleanup:
    fclose(fp);
    return -1;
```

### Step 4: 跨函数补证 (max depth 1)

当 alloc 变量作为参数传递给其他函数时，追踪被调用函数内部是否负责关闭该资源。深度限制 1 层。

见 `references/cross-function.md`。

### Step 5: 5 轮反思

1. 是否所有退出路径都覆盖了？特别注意中间 return 语句（非函数末尾 return）。
2. 资源是否通过返回值传递给了调用者（ownership transfer）？若是，检查调用者是否负责关闭。
3. 资源是否存储在全局/静态变量中？若是，检查是否有模块级清理机制。
4. C++ 代码是否使用了 RAII（std::ifstream/std::ofstream）？RAII 对象不报告泄漏。
5. 是否存在 `dup()`/`dup2()` 后关闭新 fd 而非原始 fd？dup 创建的是独立 fd，不构成泄漏。

## 参考文件

- [规则模式](./references/rule.md) — 脆弱 vs 安全代码模式
- [例外规则](./references/exceptions.md) — 误报抑制规则
- [跨函数追踪](./references/cross-function.md) — 跨函数资源追踪 (max depth 1)
- [误报策略](./references/false-positive.md) — 误报抑制策略
