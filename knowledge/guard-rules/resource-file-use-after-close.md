---
detector: resource.file-use-after-close
severity: high
cwe: CWE-672
language: [c, cpp]
tags: [resource, file, use-after-close, fd, dangling-pointer]
precision: very-high
confidence: dynamic
---

# 文件句柄释放后使用 (File Descriptor Use-After-Close)

## 威胁定义 (Threat Definition)

文件描述符（fd）或 `FILE*` 指针在 `close()`/`fclose()` 被释放后仍然被后续代码引用——包括读写操作、状态查询、或作为参数传递给其他函数，映射 CWE-672（Operation on a Resource after Expiration or Release）。释放后的 fd 值在进程 fd 表中成为空洞，随时可被其他线程的 `open()`/`socket()`/`accept()` 重新分配。后续对该 fd 的 `read()`/`write()`/`ioctl()` 等操作将作用于新分配的文件/连接而非原始目标，后果包括：(a) 数据写入错误文件/连接 → 数据泄漏或损坏；(b) 读取到不属于本模块的数据 → 信息泄露；(c) 状态操作（如 `fstat`/`fcntl`）返回错误文件的信息。多线程环境下，fd 复用窗口是不可预测的竞态窗口，漏洞表现为间歇性、低复现性的数据损坏，调试极度困难。

## 检测逻辑 (Detection Logic)

### Step 1 — 定位 close 调用及其后的 fd 引用

在函数体内搜索 `close(fd)` / `fclose(fp)` 调用，标记 close 的行号。然后从 close 语句之后继续向下扫描（线性阅读控制流），查找对同一 fd/`FILE*` 变量的任何引用——包括 `read()`、`write()`、`ioctl()`、`fcntl()`、`send()`、`recv()`、`fstat()`、`select()`、`poll()`、`epoll_ctl()` 等所有以 fd 为参数的系统调用，以及 `fprintf()`、`fread()`、`fwrite()`、`fseek()` 等以 `FILE*` 为参数的库函数。

### Step 2 — 控制流分析

分析 close 之后的所有可达路径。如果任一可达路径上存在对同一 fd 的访问，触发检测。特别关注：
- 条件分支中 close 后另一分支继续使用 fd
- goto 跳转后 close 分支与使用分支交错
- 循环中 close 后 continue 回到循环头再次使用

```c
// BAD: close 后直接写入
close(fd);
write(fd, buf, len);                 // USE-AFTER-CLOSE! fd 可能已被复用
                                     // 数据写入错误文件

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
int flags = fcntl(fd, F_GETFL);      // USE-AFTER-CLOSE! 操作可能作用于新 fd

// BAD: close 后 select/poll/epoll 监听
close(fd);
FD_SET(fd, &readfds);                // USE-AFTER-CLOSE! 监听了错误的 fd

// BAD: 循环中 close 后继续使用
for (int i = 0; i < nfds; i++) {
    close(fds[i]);
    // ... 后续代码引用 fds[i] ...
}

// GOOD: close 后立即置哨兵值且不再使用
close(fd);
fd = -1;                             // 防御：后续代码不会误用

// GOOD: close 后直接 return，无后续使用
close(fd);
return 0;                            // 函数结束，无 use-after-close

// GOOD: close 前完成所有操作，close 是最后一步
write(fd, buf, len);
fsync(fd);
close(fd);                           // close 是 fd 的最后一次引用
```

### Step 3 — 跨函数 close-then-use

当 fd 作为参数传递时，如果 callee 内部 close 了 fd 但 caller 在调用后继续使用同一 fd，触发检测。

```c
void process_and_close(int fd) {
    write(fd, buf, len);
    close(fd);                       // callee 关闭了 fd
}

void caller() {
    int fd = open("file", O_RDWR);
    process_and_close(fd);
    write(fd, "more data", 9);       // USE-AFTER-CLOSE! fd 已在 process_and_close 中关闭
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：close 语句及其后使用同一 fd 的语句所在函数体，标注 close 行号和后续 use 行号
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：close 之后对 fd 执行的具体操作类型（read/write/ioctl/fcntl/select/fstat/fprintf 等）、行号、是否位于条件分支内，以及该操作的潜在后果（数据写入错误文件/信息泄露/状态混乱）
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：fd 变量从创建（open/socket/accept）→ 使用 → close → 后续误用的完整数据流路径
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当 close 和 use 发生在不同函数中时，追踪完整调用链（caller→callee→caller）
      → `findings.evidence.call_stack`

### 可选收集 (MAY)
- [ ] **variable_state**：fd 变量在 close 前后的值、是否在多线程环境中存在 fd 复用的竞态条件
      → `findings.evidence.variable_state`
- [ ] **sanitizer_analysis**：AddressSanitizer (ASan) 的 heap-use-after-free 检测或 Valgrind 的 invalid file descriptor 警告（如有）
      → `findings.evidence.sanitizer_analysis`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| dup()/dup2() 创建新 fd 后使用新 fd | `new_fd = dup(old_fd); close(old_fd);` 后使用 `new_fd` 是合法操作——新旧 fd 引用同一文件但独立 | 后续使用的是 `dup()` 的返回值（新变量名），而非被 close 的原始 fd 变量 |
| close 后立即 return，无后续使用 | `close(fd); return 0;` 控制流在 close 后直接结束，不存在 use-after-close 窗口 | close 语句后第一个可达语句是 return 或函数末尾 |
| close 后 fd 被重新赋值（如循环中 open 新 fd 赋给同一变量） | `close(fd); fd = open("new", ...);` 变量被赋予新有效 fd，后续操作针对新资源 | 两次操作之间存在对该 fd 变量的重新赋值（赋值为新 open/socket 返回值） |
| close 后仅用于 NULL/哨兵值检查，不执行实际 I/O 操作 | `close(fd); fd = -1; if (fd >= 0) { ... }` 中的检查是防御性代码，不执行实际 I/O | 后续引用为哨兵值比较（`if (fd >= 0)`、`if (fp)`），不传递给 I/O 函数 |
| 位于 test/ 或 *_test.c / *_mock.c 文件 | 测试/模拟代码中资源管理模式可能有意不严格，但不参与生产运行 | 文件路径匹配 test/ 或测试文件命名模式 |

## 修复指引 (Remediation Guidance)

1. **首选**：将 `close(fd)` 移动到 fd 被最后一次使用之后，确保 close 是 fd 的最后一次引用。如果跨函数 hold fd，在调用链的最末端执行 close。
2. **次选**：close 后立即执行 `fd = -1;`（对 `FILE*` 执行 `fp = NULL;`），并在所有后续使用前添加有效性检查 `if (fd >= 0)`。对于 C++，采用 RAII 封装在析构函数中关闭。
3. **最低要求**：在 close 后到函数末尾之间不编写任何引用该 fd 的代码。如确实需要，将 close 移到函数最末尾。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
close(fd) 后出现 write/read/send/recv/ioctl/fcntl/fstat/select/poll/epoll_ctl 等以 fd 为参数的操作
                                 # → MUST: code_context（close 行号 + use 行号）
                                 # → SHOULD: data_flow_path（fd 全生命周期路径）

fclose(fp) 后出现 fprintf/fread/fwrite/fseek/fgets/fputs 等以 fp 为参数的操作
                                 # → MUST: judgment_rationale（use 操作类型 + 后果）
                                 # → SHOULD: data_flow_path

跨函数 close-then-use：callee close(fd) → caller 继续使用同一 fd
                                 # → MUST: call_stack（close 方 + use 方）
                                 # → SHOULD: variable_state

# === EXCLUDE (不报告) ===
→ close(fd) 后 fd = -1 或 fd 被重新赋值为新 open/socket 返回值   # 哨兵值/重新初始化
→ close(fd) 后仅执行 if (fd >= 0) 哨兵检查，无实际 I/O            # 防御性哨兵检查
→ 后续使用的是 dup()/dup2() 产生的新 fd 变量                      # 独立文件描述符
→ close(fd) 后直接 return/exit，无后续可达代码行                  # 无可达 use 路径
→ 位于 test/ 或 *_test.c / *_mock.c 文件                        # 测试代码
```
