---
detector: resource-socket-leak
severity: medium
cwe: CWE-772
language: [c, cpp]
tags: [resource, socket, leak, network]
---

# Socket 资源泄漏 (Socket Leak)

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
