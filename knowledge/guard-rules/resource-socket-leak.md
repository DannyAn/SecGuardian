---
detector: resource.socket-leak
description: Detects socket descriptor leaks where network connections are not properly cleaned up
severity: medium
cwe: CWE-772
cvss: 5.5
language: [c, cpp]
tags: [resource, socket, leak, network, fd, file-descriptor]
precision: high
confidence: dynamic
target_functions: [accept, bind, handle_client, listen, socket]
match_patterns: [socket(AF_INET, SOCK_STREAM, 0) 后函数内非全部路径有 close(fd), accept(server_fd, ...) 后函数内非全部路径有 close(client_fd), socket()/accept() 返回值赋给变量后跨函数传递，被调用函数未关闭]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

`socket()`/`accept()` 创建的文件描述符（fd）在函数所有退出路径上未被 `close()` 释放，映射 CWE-772（Missing Release of Resource after Effective Lifetime）。对于长时间运行的网络服务（daemon），每个泄漏的 socket fd 永久占据一个文件描述符槽位，累积至 `ulimit -n` 上限后，进程无法接受新连接，造成拒绝服务（DoS）。与一般内存泄漏不同，fd 泄漏无法被 GC 回收，且进程重启前不可恢复。

## 检测逻辑 (Detection Logic)

### Step 1 — 定位 socket/accept 点

在函数体内搜索 `socket()` 和 `accept()` 调用，记录每个调用点创建的新 fd（赋值目标变量）。

```c
// 每个 socket()/accept() 赋值点都是检测起点
int server_fd = socket(AF_INET, SOCK_STREAM, 0);   // 起点 1
int client_fd = accept(server_fd, ...);              // 起点 2
```

### Step 2 — 枚举所有退出路径

对每个 fd 变量，从创建点到函数出口枚举所有可能的退出路径：`return`、函数末尾隐式返回、`break`/`continue`（在循环内）、`goto` 跳转到函数尾部 label，以及异常传播路径（C++ `throw` 或错误返回）。

### Step 3 — 逐路径验证 close()

检查每条退出路径上是否存在对该 fd 的 `close(fd)` 调用（含 `shutdown(fd, SHUT_RDWR)` 后接 `close()`）。如果存在至少一条退出路径缺少 `close()`，则该 fd 泄漏成立。

```c
// BAD: accept() 返回的 client fd 在错误路径上泄漏
int client = accept(server_fd, (struct sockaddr*)&addr, &len);
if (client < 0) {
    return -1;                       // server_fd 在此路径未关闭 → 泄漏
}
if (error_condition) {
    return -1;                       // client fd 在此路径未关闭 → 泄漏
}
// ... use client ...
close(client);                       // 仅正常路径关闭

// BAD: socket() 创建后只有部分路径关闭
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;
if (bind(sock, ...) < 0) return -1; // sock 泄漏！
close(sock);

// BAD: accept 的 client fd 传递给 handler 但 handler 未关闭
int client = accept(server_fd, ...);
handle_client(client);               // handle_client() 内部未 close → 泄漏

// GOOD: 所有路径均释放
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;
if (bind(sock, ...) < 0) {
    close(sock);                     // 错误路径关闭
    return -1;
}
close(sock);                         // 正常路径关闭
return 0;

// GOOD: goto cleanup 统一释放
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;
if (bind(sock, ...) < 0) goto cleanup;
if (listen(sock, 5) < 0) goto cleanup;
// ... use sock ...
cleanup:
    close(sock);
    return ret;
```

### Step 4 — 跨函数 fd 追踪

当 fd 作为参数传递给其他函数时，追踪被调用函数内部是否关闭该 fd。若被调用函数文档/约定表明其拥有 fd 的所有权并负责关闭，则不报告泄漏。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含 `socket()`/`accept()` 调用的完整函数体源码，并标注每一条退出路径（return/goto/throw/函数尾）的 `close()` 状态（已关闭/未关闭/不适用）
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：具体列出缺少 `close()` 的退出路径（行号 + 退出方式），说明为何该路径构成泄漏
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：fd 变量的创建 → 使用（bind/listen/read/write）→ 各退出路径的完整数据流，标注每条路径的 close 状态
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当 fd 跨函数传递（如 `handle_client(client_fd)`）时，追踪被调用函数内部是否释放，记录调用链
      → `findings.evidence.call_stack`

### 可选收集 (MAY)
- [ ] **variable_state**：fd 变量当前值、是否有效（≥0）、是否被重新赋值或别名引用
      → `findings.evidence.variable_state`
- [ ] **process_lifecycle**：进程生命周期分析（daemon/长连接 vs 短生命周期命令行工具），评估泄漏影响严重程度
      → `findings.evidence.process_lifecycle`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 所有权移交 — fd 通过返回值返回给调用方 | `return sock;` 将 fd 所有权转移给上层调用者，本函数不再负责关闭 | 调用方存在对应的 `close()`，或函数文档声明调用者负责关闭 |
| 资源池/全局存储 — fd 存入全局数组并由专用清理函数释放 | fd 生命周期超出单个函数范围，由模块级 `cleanup_all()` 统一管理 | 存在注册/释放机制（如 `register_fd(sock)` + `release_all_fds()`） |
| goto cleanup 统一释放 — 所有退出路径最终汇聚到 cleanup label 执行 close | 代码使用了 `goto cleanup` 惯用法，cleanup 处包含 `if (fd >= 0) close(fd)` | verify: 所有跳转到 cleanup 的 goto 均位于 close 之前，且无跳过 cleanup 的路径 |
| fd < 0 无效 — socket()/accept() 返回 -1 且函数立即返回错误 | 无效 fd 无需关闭，`close(-1)` 本身也是错误操作（EBADF） | 调用后立即检查 `if (fd < 0) return err;` |
| 短生命周期程序 — main() 退出时 OS 自动回收所有 fd | 对于短生命周期 CLI 工具，进程退出时内核隐式关闭所有 fd，泄漏无实际危害 | 程序非 daemon/服务器，运行时间 < 几秒且不循环创建 socket |
| 宏/内联函数内 close — 看似无 close，实则由宏展开执行 | `SAFE_CLOSE(fd)` 等自定义宏内部调用 `close()`，需要展开宏定义确认 | 宏定义中明确包含 `close()` 调用 |
| stdin/stdout/stderr — fd 0/1/2 的 socket 特殊场景 | 标准 I/O 描述符由运行时管理，不需要应用程序显式关闭 | 确认为 fd 0/1/2 且非 `socket()`/`accept()` 直接创建 |
| 封装库内部管理 — 高级网络库（libuv/boost.asio）内部分配 fd 并通过自身 API 释放 | 库框架通过 RAII 或事件循环管理 fd 生命周期，应用层无需直接 close | 确认使用了封装库且通过库 API 操作 socket |

## 修复指引 (Remediation Guidance)

1. **首选**：采用 `goto cleanup` 模式，将所有退出路径汇聚到函数尾部的统一释放标签。在 cleanup 处使用 `if (fd >= 0) close(fd); fd = -1;` 确保幂等安全。
2. **次选**：对每个 `socket()`/`accept()` 调用点，在直接下方的每个 `return`/`goto` 前插入 `close(fd)`。适用于函数较小、退出路径 ≤ 3 条的简单场景。
3. **最低要求**：如使用 C++，采用 RAII 封装（自定义 `SocketHandle` 类在析构函数中 `close()`，或使用 `std::unique_ptr<int, SocketDeleter>`）。如使用高级网络库，优先使用库提供的连接管理 API，避免裸 fd 操作。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
socket(AF_INET, SOCK_STREAM, 0) 后函数内非全部路径有 close(fd)
                                 # → MUST: code_context（完整函数 + 退出路径 close 标注）
                                 # → SHOULD: data_flow_path（创建→使用→退出）

accept(server_fd, ...) 后函数内非全部路径有 close(client_fd)
                                 # → MUST: judgment_rationale（具体泄漏路径行号）
                                 # → SHOULD: call_stack（跨函数 fd 传递追踪）

socket()/accept() 返回值赋给变量后跨函数传递，被调用函数未关闭
                                 # → MUST: call_stack + 被调用函数分析
                                 # → SHOULD: data_flow_path

# === EXCLUDE (不报告) ===
→ 所有退出路径均存在 close()（含 goto cleanup 汇聚）  # 资源已正确释放
→ return fd 将所有权转移给调用方                      # 所有权移交，非泄漏
→ fd 存入全局存储且有注册/释放机制                    # 资源池模式
→ socket()/accept() 返回 < 0 后直接 return             # 无效 fd，无需关闭
→ 位于 test/ 或 *_test.c 文件                         # 测试辅助代码
→ 短生命周期 CLI 程序（非 daemon/服务器循环）          # 进程退出即回收
→ 通过封装库 API 管理 socket（libuv/boost.asio）       # 库内部管理生命周期
```
