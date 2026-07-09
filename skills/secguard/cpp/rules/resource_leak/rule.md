---
name: secguard-cpp-resource_leak
description: "Detects file descriptor and socket descriptor resource management errors including resource leaks (file handles/sockets not closed on all exit paths), double-close, and use-after-close in C/C++ code"
category: language-specific
language: cpp
topic: [io]
skill_id: resource.leak
signal_filter: resource.leak*
signal_source: call_sites[cat="io"]
severity: high
cwe: [CWE-404, CWE-672, CWE-675, CWE-772, CWE-775]
---

# resource_leak 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `resource.leak` |
| signal_filter | `resource.leak*`（供 `secguard ./src c resource.leak` 过滤匹配） |
| signal_source | `call_sites[cat="io"]` |
| 默认严重度 | High |

---

## Scenario 1: 资源泄漏（文件描述符/Socket）

### 威胁定义

**文件句柄泄漏**：`fopen()`/`open()`/`openat()`/`freopen()`/`tmpfile()` 返回的文件句柄未在函数退出前关闭。长时间运行的服务会耗尽文件描述符，导致无法打开新文件或接受新连接（DoS）。`malloc` 未 `free` 属于 `memory.memory-leak`（CWE-401），不在本检测器覆盖范围。

**Socket 泄漏**：`socket()`/`accept()` 创建的文件描述符（fd）在函数所有退出路径上未被 `close()` 释放。对于长时间运行的网络服务（daemon），每个泄漏的 socket fd 永久占据一个文件描述符槽位，累积至 `ulimit -n` 上限后，进程无法接受新连接，造成拒绝服务（DoS）。与一般内存泄漏不同，fd 泄漏无法被 GC 回收，且进程重启前不可恢复。

### 检测逻辑

**Step 1: 定位所有分配点**

在函数体内搜索 `fopen()`/`open()`/`openat()`/`freopen()`/`tmpfile()`/`socket()`/`accept()` 调用，记录每个调用点的赋值目标和行号。

```c
// 文件句柄分配
FILE* fp = fopen(path, "r");        // 需要 fclose
int fd = open(path, flags);          // 需要 close
int fd = openat(dirfd, path, flags);
FILE* fp = freopen(path, mode, stream);
FILE* fp = tmpfile();

// Socket 分配
int server_fd = socket(AF_INET, SOCK_STREAM, 0);   // 需要 close
int client_fd = accept(server_fd, ...);              // 需要 close
```

**Step 2: 枚举所有退出路径**

对每个 fd/`FILE*` 变量，从创建点到函数出口枚举所有可能的退出路径：`return`、函数末尾隐式返回、`break`/`continue`（在循环内）、`goto` 跳转到函数尾部 label，以及异常传播路径（C++ `throw` 或错误返回）。

**Step 3: 逐路径验证 close()**

检查每条退出路径上是否存在对该资源的 `close()`/`fclose()` 调用。如果存在至少一条退出路径缺少 `close()`，则该资源泄漏成立。

```c
// BAD: 错误路径泄漏
FILE* fp = fopen(path, "r");
if (!fp) return NULL;

FILE* out = fopen(dst, "w");
if (!out) {
    // fp 已打开但未关闭 → 泄漏
    return NULL;
}
fclose(fp);
fclose(out);

// BAD: socket bind 失败后 sock 泄漏
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;
if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    // sock 未关闭 → 泄漏
    return -1;
}
close(sock);

// BAD: 多层嵌套错误路径
int fd1 = open(path1, O_RDONLY);
if (fd1 < 0) return -1;
int fd2 = open(path2, O_RDONLY);
if (fd2 < 0) {
    close(fd1);
    return -1;
}
int fd3 = open(path3, O_RDONLY);
if (fd3 < 0) {
    close(fd1);
    close(fd2);
    // 但如果忘记某个 close，就是泄漏
    return -1;
}
close(fd1); close(fd2); close(fd3);

// BAD: 循环内出错时跳过关闭
for (int i = 0; i < n; i++) {
    int fd = open(files[i], O_RDONLY);
    if (fd < 0) continue;               // OK: 无效 fd
    int ret = process_file(fd);
    if (ret < 0) {
        // fd 未关闭 → 泄漏（累积）
        continue;
    }
    close(fd);
}

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

**Step 4: 跨函数 fd 追踪**

当 fd 作为参数传递给其他函数时，追踪被调用函数内部是否负责关闭该资源。若被调用函数文档/约定表明其拥有 fd 的所有权并负责关闭，则不报告泄漏。

```c
// BAD: handle_client 内部未关闭 fd
int client = accept(server_fd, (struct sockaddr*)&addr, &len);
if (client < 0) continue;
handle_client(client);       // handle_client 内部无 close(fd) → 泄漏

// BAD: accept() 的 client fd 在错误路径上泄漏
int client = accept(server_fd, (struct sockaddr*)&addr, &len);
if (client < 0) return -1;
if (error_condition) return -1;  // client fd 泄漏
close(client);                     // 仅正常路径关闭
```

### 检测模式

```
# MATCH（触发检测）
fopen\s*\(.*\)(?!.*fclose)       # fopen 无对应 fclose
open\s*\(.*\)(?!.*close\s*\()    # open 无对应 close
socket() 后函数内非全部路径有 close(fd)
accept() 后函数内非全部路径有 close(client_fd)
socket()/accept() 返回值跨函数传递，被调用函数未关闭

# EXCLUDE（不报告）
→ fclose|close\s*\(                              # 存在对应关闭调用
→ std::ifstream|std::ofstream|std::fstream        # C++ RAII
→ return\s+fp|return\s+fd|\*\w+\s*=\s*fp          # 指针传出/全局赋值
→ fopen.*==\s*NULL|fopen.*!\s*\w+\).*return       # NULL 检查后立即返回
→ 所有退出路径均存在 close()（含 goto cleanup）   # 已正确释放
→ return fd 将所有权转移给调用方                    # 所有权移交
→ fd 存入全局存储且有注册/释放机制                  # 资源池模式
→ socket()/accept() 返回 < 0 后直接 return          # 无效 fd 无需关闭
→ 短生命周期 CLI 程序（非 daemon/服务器循环）       # 进程退出即回收
→ 通过封装库 API 管理 socket（libuv/boost.asio）   # 库内部管理
→ 位于 test/ 或 *_test.c 文件                      # 测试辅助代码
```

### 修复指引

1. **C 代码**：采用 `goto cleanup` 模式，将所有退出路径汇聚到函数尾部统一释放标签。在 cleanup 处使用 `if (fd >= 0) close(fd)` 确保安全
2. **C++ 代码**：使用 RAII 封装（`std::fstream`、`std::unique_ptr<int, SocketDeleter>` 等自定义删除器）
3. **多层资源分配**：从最内层开始逐层回滚关闭已打开资源
4. **所有权移交**：明确文档化谁负责关闭（调用方或被调用方），并在代码注释中标注

---

## Scenario 2: 双重关闭（Double Close）

### 威胁定义

同一文件描述符（fd）或 `FILE*` 指针被 `close()`/`fclose()` 关闭两次或以上，映射 CWE-675（Multiple Operations on Resource in Single-Operation Context）。第一次关闭后 fd 值被 OS 回收，可被其他线程的 `open()`/`socket()`/`accept()` 立即复用分配。第二次 `close()` 将关闭一个不相关的文件/连接，后果包括：(a) 数据丢失——正在写入的文件被意外关闭；(b) 连接中断——活跃的网络连接被关闭；(c) 无声数据损坏——应用程序无感知地继续操作已被其他线程重新分配的 fd。多线程环境下，fd 复用窗口极短（微秒级），漏洞触发具备间歇性与低可复现性。

### 检测逻辑

**Step 1: 定位所有 close 调用**

在函数体内搜索 `close(fd)` 和 `fclose(fp)` 调用，记录每次调用的 fd/`FILE*` 变量和行号。

**Step 2: 构建 close 操作序列**

对每个 fd/`FILE*` 变量，按控制流顺序列出所有对该变量的 `close()` 调用。识别是否存在任意执行路径上同一变量被 close 两次或以上。

**Step 3: 分析 goto/cleanup 路径**

特别关注 `goto cleanup` 模式：如果 cleanup label 包含 close 且正常路径已经 close 过，则 goto cleanup 会触发二次关闭。

```c
// BAD: 同一函数内直接两次 close
close(fd);
// ... intervening code ...
close(fd);                           // DOUBLE CLOSE! fd 可能已被复用

// BAD: goto cleanup 导致重复关闭
fclose(fp);
if (error) goto cleanup;
// ...
cleanup:
    fclose(fp);                      // fp 已被关闭！重复操作

// BAD: 条件路径中重复 close
if (condition) {
    close(fd);
}
close(fd);                           // 条件为真时 fd 被关闭两次

// GOOD: close 后立即置哨兵值并检查
close(fd);
fd = -1;
if (fd >= 0) close(fd);              // 哨兵保护：不执行

// GOOD: cleanup 处检查哨兵值
fclose(fp);
fp = NULL;
// ...
cleanup:
    if (fp) fclose(fp);              // NULL 检查防止重复关闭

// GOOD: 不同条件分支 close 不同 fd
if (condition) {
    close(fd1);
} else {
    close(fd2);
}
```

**Step 4: 跨函数双重关闭**

检查 fd 是否被传递给多个函数且多个函数都尝试 close 同一 fd。如果调用链上出现 "callee closes → caller also closes" 模式，报告重复关闭。

### 检测模式

```
# MATCH（触发检测）
同一 fd 变量在函数内出现 >=2 次 close(fd) 调用（不在互斥分支中）
goto cleanup 路径：正常路径已 close(fd)，错误路径 goto cleanup 再次 close(fd)
跨函数：callee close(fd) 后 caller 也 close(fd)

# EXCLUDE（不报告）
→ close(fd) 后紧接 fd = -1，且后续 close 前检查 if (fd >= 0)    # 哨兵保护
→ 两次 close 操作不同变量名（close(fd1); close(fd2);）           # 不同资源
→ 第二次 close 操作的是 dup()/dup2() 产生的新 fd                  # 独立文件描述符
→ 两次 close 之间变量被重新赋值（非哨兵赋值）                      # 变量指向新资源
→ 位于 test/ 或 *_test.c / *_mock.c 文件                          # 测试辅助代码
```

### 修复指引

1. **首选**：每次 `close(fd)` 后立即执行 `fd = -1;`（对 `FILE*` 执行 `fp = NULL;`），在 cleanup 处使用 `if (fd >= 0) close(fd);` 哨兵检查
2. **次选**：重构代码使 fd 的 close 点唯一——所有退出路径汇聚到函数尾部 single close 点，通过 goto cleanup 实现
3. **最低要求**：在 cleanup/错误处理路径的 close 调用前添加哨兵检查 `if (fd >= 0)`

---

## Scenario 3: 关闭后使用（Use After Close）

### 威胁定义

文件描述符（fd）或 `FILE*` 指针在 `close()`/`fclose()` 被释放后仍然被后续代码引用——包括读写操作、状态查询、或作为参数传递给其他函数，映射 CWE-672（Operation on a Resource after Expiration or Release）。释放后的 fd 值在进程 fd 表中成为空洞，随时可被其他线程的 `open()`/`socket()`/`accept()` 重新分配。后续对该 fd 的 `read()`/`write()`/`ioctl()` 等操作将作用于新分配的文件/连接而非原始目标，后果包括：(a) 数据写入错误文件/连接 → 数据泄漏或损坏；(b) 读取到不属于本模块的数据 → 信息泄露；(c) 状态操作（如 `fstat`/`fcntl`）返回错误文件的信息。多线程环境下，fd 复用窗口是不可预测的竞态窗口，漏洞表现为间歇性、低复现性的数据损坏，调试极度困难。

### 检测逻辑

**Step 1: 定位 close 调用及其后的 fd 引用**

在函数体内搜索 `close(fd)` / `fclose(fp)` 调用，标记 close 的行号。然后从 close 语句之后继续向下扫描（线性阅读控制流），查找对同一 fd/`FILE*` 变量的任何引用——包括 `read()`、`write()`、`ioctl()`、`fcntl()`、`send()`、`recv()`、`fstat()`、`select()`、`poll()`、`epoll_ctl()` 等所有以 fd 为参数的系统调用，以及 `fprintf()`、`fread()`、`fwrite()`、`fseek()` 等以 `FILE*` 为参数的库函数。

**Step 2: 控制流分析**

分析 close 之后的所有可达路径。如果任一可达路径上存在对同一 fd 的访问，触发检测。特别关注：
- 条件分支中 close 后另一分支继续使用 fd
- goto 跳转后 close 分支与使用分支交错
- 循环中 close 后 continue 回到循环头再次使用

```c
// BAD: close 后直接写入
close(fd);
write(fd, buf, len);                 // USE-AFTER-CLOSE! fd 可能已被复用

// BAD: fclose 后 fprintf
fclose(fp);
fprintf(fp, "log: %s", msg);         // USE-AFTER-CLOSE! fp 已无效

// BAD: 条件分支中 close 后另一分支使用
if (error) {
    close(fd);
} else {
    // ... more work ...
}
write(fd, buf, len);                 // error 为真时：use-after-close

// BAD: close 后 ioctl/fcntl 操作
close(fd);
int flags = fcntl(fd, F_GETFL);      // USE-AFTER-CLOSE!

// BAD: close 后 select/poll 监听
close(fd);
FD_SET(fd, &readfds);                // USE-AFTER-CLOSE!

// GOOD: close 后直接 return，无后续使用
close(fd);
return 0;

// GOOD: close 前完成所有操作，close 是最后一步
write(fd, buf, len);
fsync(fd);
close(fd);                           // close 是 fd 的最后一次引用

// GOOD: close 后置哨兵值，不再使用
close(fd);
fd = -1;                             // 防御：后续代码不会误用
```

**Step 3: 跨函数 close-then-use**

当 fd 作为参数传递时，如果 callee 内部 close 了 fd 但 caller 在调用后继续使用同一 fd，触发检测。

```c
void process_and_close(int fd) {
    write(fd, buf, len);
    close(fd);                       // callee 关闭了 fd
}

void caller() {
    int fd = open("file", O_RDWR);
    process_and_close(fd);
    write(fd, "more data", 9);       // USE-AFTER-CLOSE! fd 已在 callee 中关闭
}
```

### 检测模式

```
# MATCH（触发检测）
close(fd) 后出现 write/read/send/recv/ioctl/fcntl/fstat/select/poll/epoll_ctl 等以 fd 为参数的操作
fclose(fp) 后出现 fprintf/fread/fwrite/fseek/fgets/fputs 等以 fp 为参数的操作
跨函数 close-then-use：callee close(fd) → caller 继续使用同一 fd

# EXCLUDE（不报告）
→ close(fd) 后 fd = -1 或 fd 被重新赋值为新 open/socket 返回值   # 哨兵值/重新初始化
→ close(fd) 后仅执行 if (fd >= 0) 哨兵检查，无实际 I/O            # 防御性哨兵检查
→ 后续使用的是 dup()/dup2() 产生的新 fd 变量                      # 独立文件描述符
→ close(fd) 后直接 return/exit，无后续可达代码行                  # 无可达 use 路径
→ 位于 test/ 或 *_test.c / *_mock.c 文件                         # 测试代码
```

### 修复指引

1. **首选**：将 `close(fd)` 移动到 fd 被最后一次使用之后，确保 close 是 fd 的最后一次引用。如果跨函数 hold fd，在调用链的最末端执行 close
2. **次选**：close 后立即执行 `fd = -1;`（对 `FILE*` 执行 `fp = NULL;`），并在所有后续使用前添加有效性检查 `if (fd >= 0)`。对于 C++，采用 RAII 封装在析构函数中关闭
3. **最低要求**：在 close 后到函数末尾之间不编写任何引用该 fd 的代码。如确实需要，将 close 移到函数最末尾

---

## 调查建议

### 安全变体参数审计

> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。


> 参考 [false-positive.md](references/false-positive.md) 确认抑制模式。







---

## 取证证据收集指引

### 必须收集（MUST）

- [ ] **code_context**：危险操作（fopen/open/socket/accept/close/fclose）所在函数完整代码，标注关键行号
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：资源分配、使用与释放的完整分析，按 Scenario 具体化：
  - S1: 缺少 close 的退出路径清单
  - S2: 两次 close 的行号、fd 变量名、控制流路径
  - S3: close 行号与后续 use 行号、use 操作类型、潜在后果
      → `findings.evidence.judgment_rationale`

### 建议收集（SHOULD）

- [ ] **data_flow_path**：fd/`FILE*` 变量从创建（open/socket/accept）到最终引用的完整数据流路径
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当 close 和引用发生在不同函数中时，追踪完整调用链
      → `findings.evidence.call_stack`

### 可选收集（MAY）

- [ ] **variable_state**：fd 变量在关键操作之间的值变化（是否被置为 -1 或重新赋值），多线程环境下 fd 被复用的可能性
      → `findings.evidence.variable_state`
- [ ] **process_lifecycle**：进程生命周期分析（daemon/长连接 vs 短生命周期 CLI 工具）
      → `findings.evidence.process_lifecycle`
- [ ] **sanitizer_analysis**：AddressSanitizer (ASan) 或其他运行时检测报告（如有）
      → `findings.evidence.sanitizer_analysis`

---

## 输出格式

每个 finding 遵循三段式证据链：

```json
{
  "evidence_chain": {
    "source": {"description": "fopen(path, \"r\") 创建文件句柄 fp", "file": "src/reader.c", "line": 42},
    "propagate": {"description": "fp 传递到下游函数 process_data", "file": "src/reader.c", "line": 45},
    "sink": {"description": "错误路径 return -1 前未 fclose(fp) 导致泄漏", "file": "src/reader.c", "line": 48}
  },
  "scenario": "Scenario 1: 资源泄漏",
  "references_applied": ["exceptions.md", "cross-function.md", "false-positive.md"]
}
```

对于 Scenario 2（双重关闭）：

```json
{
  "evidence_chain": {
    "source": {"description": "第一次 close(fd) 位于行号 50", "file": "src/network.c", "line": 50},
    "propagate": {"description": "控制流路径：正常路径 → goto cleanup → 第二次 close", "file": "src/network.c", "line": "50-68"},
    "sink": {"description": "第二次 close(fd) 重复关闭同一 fd", "file": "src/network.c", "line": 68}
  },
  "scenario": "Scenario 2: 双重关闭",
  "references_applied": ["false-positive.md"]
}
```

对于 Scenario 3（关闭后使用）：

```json
{
  "evidence_chain": {
    "source": {"description": "close(fd) 位于行号 30", "file": "src/io.c", "line": 30},
    "propagate": {"description": "close 后 fd 未置 -1，后续分支继续引用", "file": "src/io.c", "line": "30-35"},
    "sink": {"description": "write(fd, buf, len) 在 close 后使用同一 fd", "file": "src/io.c", "line": 35}
  },
  "scenario": "Scenario 3: 关闭后使用",
  "references_applied": ["false-positive.md", "cross-function.md"]
}
```
