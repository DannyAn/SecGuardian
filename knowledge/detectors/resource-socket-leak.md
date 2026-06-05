---
detector: resource-socket-leak
severity: medium
cwe: CWE-772
language: [c, cpp]
tags: [resource, socket, leak, network]
---

# Socket 资源泄漏 (Socket Leak)

## Indexer Input

- `symbols.functions`: 定位包含 `socket()`/`accept()` 调用的函数
- `call_graph.edges`: 追踪 accept 返回的 fd 传递给哪些函数（如 `handle(fd)`），验证被调用函数内部是否 close fd
- 执行方式：符号表找 socket/accept → 精准读取 → 如 fd 传递给其他函数，查调用图定位被调用函数后读取验证，**不逐文件全文扫描**

## 威胁定义

`socket()`/`accept()` 创建的 fd 未关闭。长时间运行的服务耗尽文件描述符后无法接受新连接（DoS）。

## 检测逻辑

```c
// BAD: socket 未关闭
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return;
// ... use sock ...
// sock leaks!

// BAD: accept 的 client fd 泄漏
int client = accept(server_fd, ...);
handle(client);                  // handle() 未 close, fd 泄漏

// GOOD: 显式关闭
close(sock);
```

## 修复指引

每次 `socket()`/`accept()` 必须有对应 `close()`

## 检测模式汇总

```
socket\(.*\).*\n(?!.*close)      # socket() 后函数内无 close()
accept\(.*\).*\n(?!.*close)      # accept() 后函数内无 close()
```
