---
detector: resource.file-double-close
description: Detects double-close vulnerabilities where a file handle is closed more than once
severity: medium
cwe: CWE-675
cvss: 5.5
language: [c, cpp]
tags: [resource, file, double-close, fd, use-after-free]
precision: high
confidence: dynamic
target_functions: [fclose]
match_patterns: [同一 fd 变量在函数内出现 >=2 次 close(fd) 调用（不在互斥分支中）, goto cleanup 路径：正常路径已 close(fd)，错误路径 goto cleanup 再次 close(fd), 跨函数：callee close(fd) 后 caller 也 close(fd)]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

同一文件描述符（fd）或 `FILE*` 指针被 `close()`/`fclose()` 关闭两次或以上，映射 CWE-675（Multiple Operations on Resource in Single-Operation Context）。第一次关闭后 fd 值被 OS 回收，可被其他线程的 `open()`/`socket()`/`accept()` 立即复用分配。第二次 `close()` 将关闭一个不相关的文件/连接，后果包括：(a) 数据丢失——正在写入的文件被意外关闭；(b) 连接中断——活跃的网络连接被关闭；(c) 无声数据损坏——应用程序无感知地继续操作已被其他线程重新分配的 fd。多线程环境下，fd 复用窗口极短（微秒级），漏洞触发具备间歇性与低可复现性。

## 检测逻辑 (Detection Logic)

### Step 1 — 定位所有 close 调用

在函数体内搜索 `close(fd)` 和 `fclose(fp)` 调用，记录每次调用的 fd/`FILE*` 变量和行号。

### Step 2 — 构建 close 操作序列

对每个 fd/`FILE*` 变量，按控制流顺序列出所有对该变量的 `close()` 调用。识别是否存在任意执行路径上同一变量被 close 两次或以上。

### Step 3 — 分析 goto/cleanup 路径

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

// BAD: 循环中重复 close
for (i = 0; i < n; i++) {
    fd = open_files[i];
    close(fd);                       // 如果 open_files 有重复 fd，重复关闭
}

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
    close(fd1);                      // 关闭 fd1
} else {
    close(fd2);                      // 关闭 fd2（不同变量，非重复）
}
```

### Step 4 — 跨函数双重关闭

检查 fd 是否被传递给多个函数且多个函数都尝试 close 同一 fd。如果调用链上出现 "callee closes → caller also closes" 模式，报告重复关闭。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：包含两次 `close()` 调用及中间代码的函数体片段，标注 fd/`FILE*` 变量名和两次 close 的行号
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：两次 close 的行号、fd 变量名是否相同、两次 close 之间 fd 值是否可能被重新赋值或由其他线程创建的新 fd 复用
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：fd 变量的完整生命周期——创建（open/socket/accept）→ 第一次 close → 可能的重新赋值/复用 → 第二次 close
      → `findings.evidence.data_flow_path`
- [ ] **call_stack**：当两次 close 发生在不同函数中时（跨函数重复关闭），追踪完整调用链
      → `findings.evidence.call_stack`

### 可选收集 (MAY)
- [ ] **variable_state**：fd 变量在两次 close 之间的值变化（是否被置为 -1 或重新赋值），以及多线程场景下 fd 被复用的可能性
      → `findings.evidence.variable_state`
- [ ] **sanitizer_analysis**：AddressSanitizer (ASan) 或其他运行时检测报告（如有）
      → `findings.evidence.sanitizer_analysis`

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| close 后立即设 fd=-1 / fp=NULL 并检查后再 close | 哨兵值保护：`fd = -1; if (fd >= 0) close(fd);` 等价于无操作 | 两次 close 之间存在 `fd = -1` 或 `fp = NULL` 赋值，且第二次 close 前检查哨兵值 |
| 不同分支 close 不同 fd 变量（非同一变量） | 两个 `close()` 操作的是不同的变量（`close(fd1)` vs `close(fd2)`），即使变量值相同也无双重关闭语义 | 确认两次 close 的目标变量名不同 |
| dup()/dup2() 创建的新 fd | `dup(fd)` 产生新的 fd 值，关闭新 fd 不构成对原始 fd 的重复关闭 | 第二次 close 操作的是 `dup()` 的返回值而非原始 fd |
| fd 在不同 scope 重新赋值（如循环体中 `fd = next_fd()`） | 同一变量名在不同时刻持有不同 fd 值，每次 close 关闭的是不同的活动文件描述符 | 两次 close 之间存在对该变量的重新赋值（非 close 的哨兵赋值） |
| test/ 目录或 *_test.c 文件 | 测试代码中资源管理通常不严格，且不参与生产运行 | 文件路径匹配 test/ 或 *_test.c 模式 |

## 修复指引 (Remediation Guidance)

1. **首选**：每次 `close(fd)` 后立即执行 `fd = -1;`（对 `FILE*` 执行 `fp = NULL;`），在 cleanup 处使用 `if (fd >= 0) close(fd);` 哨兵检查。这是最简洁的防御性编程模式。
2. **次选**：重构代码使 fd 的 close 点唯一——所有退出路径汇聚到函数尾部 single close 点，通过 goto cleanup 实现。
3. **最低要求**：在 cleanup/错误处理路径的 close 调用前添加哨兵检查 `if (fd >= 0)`。不做代码结构改造，仅加防御检查。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
同一 fd 变量在函数内出现 >=2 次 close(fd) 调用（不在互斥分支中）
                                 # → MUST: code_context（两次 close 位置 + 中间代码）
                                 # → SHOULD: data_flow_path（fd 创建→close→close）

goto cleanup 路径：正常路径已 close(fd)，错误路径 goto cleanup 再次 close(fd)
                                 # → MUST: judgment_rationale（两条到第二次 close 的路径）
                                 # → SHOULD: data_flow_path

跨函数：callee close(fd) 后 caller 也 close(fd)
                                 # → MUST: call_stack（双函数 close 追踪）
                                 # → SHOULD: variable_state（fd 值是否在中间变化）

# === EXCLUDE (不报告) ===
→ close(fd) 后紧接 fd = -1，且后续 close 前检查 if (fd >= 0)     # 哨兵保护
→ 两次 close 操作不同变量名（close(fd1); close(fd2);）            # 不同资源
→ 第二次 close 操作的是 dup()/dup2() 产生的新 fd                  # 独立文件描述符
→ 两次 close 之间变量被重新赋值（非哨兵赋值）                      # 变量指向新资源
→ 位于 test/ 或 *_test.c / *_mock.c 文件                          # 测试辅助代码
```
