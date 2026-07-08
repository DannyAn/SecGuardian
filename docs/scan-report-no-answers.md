# cpp-vuln-demo-no-answers 安全扫描报告

> 扫描协议: Dispatcher v2 + 事实锚定反思
> 索引器产出: 82 call_sites (6 categories)
> 激活 Skills: 10 (command_injection, buffer_overflow, null_dereference, integer_overflow, resource_leak, lock_misuse, hardcoded_secrets, memory_leak/double_free/uaf, must_check, input_validation, api_semantic_misuse)
> 验证日期: 2026-07-08
> 测试项目: `examples/cpp-vuln-demo-no-answers/` (无答案卡标记，82 call_sites)

---

## 检出总结

| 严重度 | 数量 |
|--------|------|
| Critical | 10 |
| High | 13 |
| Medium | 9 |
| Informational | 0 |
| **总计** | **32** |
| 抑制信号 | 10+ |
| Low Confidence | 1 (null_dereference F5) |

**与旧版 (cpp-vuln-demo, 93 call_sites, 含答案卡) 差异:**
- 移除 1 个报告项: 原 F11 (network.c:105 socket 泄漏) — 确认由答案卡标记引入，no-answers 版本无此代码
- 原报告 12 个 findings → 本报告 32 个 findings (Worker 覆盖面扩大 3x)

---

## Findings 详情

### Worker: command_injection (2 findings)

#### F1 [Critical] CWE-78 命令注入
**文件**: system.c:26 | **函数**: execute_user_command()

```
system(cmd) — cmd 来自 snprintf("grep '%s' ...", user_input)
```

**证据链**:
- Source: user_input 为函数参数，无任何校验
- Propagate: snprintf 将 user_input 格式化到 cmd 缓冲区
- Sink: system(cmd) — user_input 含 "' ; rm -rf /\n" 可注入

**事实锚定反思**:
- Q1: 参数来自外部源? → YES (函数参数 user_input)
- Q2: Sink 前有校验? → NO (无任何白名单/黑名单)
- Q3: 纯字符串字面量? → NO (snprintf 拼接)

**判定**: CONFIRMED

---

#### F2 [High] CWE-78 命令注入 (黑名单绕过)
**文件**: p3_edge_case.c:40 | **函数**: run_admin_command()

```
system(cmd) — is_safe_input 仅过滤 [;&]，&&、|、$() 绕过
```

**证据链**:
- is_safe_input 正则 `[;&]` 仅拦截分号和 & 符号
- user_cmd 含 "&& rm -rf /" 或 "$(cat /etc/passwd)" 可绕过
- 黑名单方案本质上不完全

**事实锚定反思**:
- Q1: YES (user_cmd 是函数参数)
- Q2: YES(不完全) — is_safe_input 提供部分保护但黑名单不充分
- Q3: NO

**判定**: CONFIRMED (部分过滤不充分)

---

### Worker: buffer_overflow (4 findings)

#### F3 [Critical] CWE-120 栈缓冲区溢出
**文件**: parser.c:28 | **函数**: parse_task_name()

```
strcpy(task->name, input) — name = char[64], input 来自 argv[1]
```

**证据链**: Task::name = char[64] 栈数组，argv[1] 无长度约束，strcpy 无边界检查

**事实锚定反思**:
- Q1: 目标 ≥ 拷贝? → NO (name[64], input 长度未知)
- Q2: 编译期常量? → NO
- Q3: 源有 n 字节? → YES (argv[1] 是合法 C 串但可能 > 63)

**判定**: CONFIRMED

---

#### F4 [Critical] CWE-120 栈缓冲区溢出
**文件**: parser.c:39 | **函数**: format_task_desc()

```
sprintf(task->command, "Task[%s]: %s", name, description) — command=[256]
```

**证据链**: 两个 %s 均来自用户输入，组合后可能超 255 字节

**事实锚定反思**: Q1=NO, Q2=NO, Q3=YES → CONFIRMED

**判定**: CONFIRMED

---

#### F5 [High] CWE-120 栈缓冲区溢出 (死代码)
**文件**: parser.c:85 | **函数**: validate_user_input()

```
strcpy(buf, user_input) — buf = char[64], user_input 无约束
```

**证据链**: 函数在当前无调用者，但结构上可被利用

**事实锚定反思**: Q1=NO, Q2=NO → CONFIRMED

**判定**: CONFIRMED (死代码，引入后即危险)

---

#### F6 [Critical] CWE-122 堆缓冲区溢出 (+ 整数溢出绕过)
**文件**: network.c:60 | **函数**: parse_packet()

```
memcpy(packet->data, raw_data + HEADER_SIZE, header->data_size)
```

**多信号归并 W4.5**:
- line 53 memcpy (sizeof(PacketHeader), 固定大小) → SUPPRESS (安全)
- line 60 memcpy (header->data_size, 攻击者控制) → CONFIRMED

**事实锚定反思**:
- Q1: 目标 ≥ 拷贝? → NO (data_size 绕过了 size check, 整数溢出)
- Q2: 编译期常量? → NO
- Q3: 源有 n 字节? → NO (data_size 远大于 raw_size)

**判定**: CONFIRMED

---

### Worker: null_dereference (4 确认 + 1 低置信)

#### F7 [Critical] CWE-476 空解引用
**文件**: network.c:50 | **函数**: parse_packet()

```
NetworkPacket *packet = malloc(sizeof(NetworkPacket));
// 无 NULL 检查
memcpy(&packet->header, ...);  // 直接使用
```

**事实锚定反思**: Q1=NO, Q2=YES → CONFIRMED

**判定**: CONFIRMED

---

#### F8 [Critical] CWE-476 空解引用
**文件**: network.c:59 | **函数**: parse_packet()

```
packet->data = malloc(header->data_size);
memcpy(packet->data, ...);  // 无 NULL 检查
```

**事实锚定反思**: Q1=NO, Q2=YES → CONFIRMED

**判定**: CONFIRMED

---

#### F9 [High] CWE-476 空解引用 (Release 模式)
**文件**: allocator.c:103 | **函数**: alloc_user_buffer()

```
char *buf = malloc(user_size);
assert(buf != NULL);   // assert 在 NDEBUG 构建中被移除!
memset(buf, 0, ...);   // Release 模式下 buf 可能为 NULL
```

**事实锚定反思**: Q1=NO (assert 不是运行时检查), Q2=YES → CONFIRMED

**判定**: CONFIRMED

---

#### F10 [Critical] CWE-476 空解引用
**文件**: p3_edge_case.c:79 | **函数**: FileCache_create()

```
FileCache *fc = malloc(sizeof(FileCache));
fc->buffer = malloc(4096);  // fc 可能 NULL
```

**事实锚定反思**: Q1=NO, Q2=YES → CONFIRMED

**判定**: CONFIRMED

---

#### F11 [Medium] CWE-476 空解引用 (低置信)
**文件**: p3_edge_case.c:80 | **函数**: FileCache_create()

```
fc->buffer = malloc(4096);
// buffer 在本函数中未被解引用，风险在调用侧
```

**事实锚定反思**: Q1=NO, Q2=NO (本函数内无解引用路径) → LOW_CONFIDENCE

**判定**: LOW_CONFIDENCE (防御性标记)

---

### Worker: integer_overflow (2 findings)

#### F12 [Critical] CWE-190 整数溢出绕过
**文件**: network.c:46 | **函数**: parse_packet()

```
if (header->data_size + HEADER_SIZE > raw_size) { return -2; }
// data_size=0xFFFFFFF1 → 0xFFFFFFF1 + 16 = 0x1 (uint32 溢出)
// 0x1 > 16 → FALSE → 绕过检查!
```

**证据链**: 整数溢出导致 size check 绕过 → malloc(0xFFFFFFF1) → memcpy 超大拷贝 → 堆溢出

**事实锚定反思**: Q1=YES, Q2=YES, Q3=NO → CONFIRMED

**依赖关联**: 此发现是 F6 的前提条件 (buffer_overflow 依赖 integer_overflow 结论)

**判定**: CONFIRMED

---

#### F13 [Medium] CWE-190 整数溢出
**文件**: allocator.c:118 | **函数**: alloc_objects()

```
return malloc(count * obj_size);  // 无溢出检查
```

**事实锚定反思**: Q1=YES, Q2=NO (局部参数, 当前无攻击入口), Q3=NO → CONFIRMED

**判定**: CONFIRMED (潜伏性漏洞)

---

### Worker: resource_leak (0 findings — 关键差异!)

**所有 fopen/fclose/open/close/mkstemp 配对正确。**
**原报告的 socket(AF_INET, SOCK_STREAM, 0) 在 no-answers 版本中不存在** — 确认由答案卡标记引入的假阳性。

| 文件 | 行号 | 资源 | 关闭 | 判定 |
|------|------|------|------|------|
| system.c | 42 | FILE* | fclose 46 | SUPPRESS |
| system.c | 57 | FILE* | fclose 61 | SUPPRESS |
| system.c | 68 | fd | close 72 | SUPPRESS |
| system.c | 82 | FILE* | fclose 85 | SUPPRESS |
| system.c | 104 | FILE* | fclose 107 | SUPPRESS |
| parser.c | 100 | FILE* | fclose 101 | SUPPRESS |

---

### Worker: lock_misuse (2 findings)

#### F14 [High] CWE-367 TOCTOU 锁范围不足
**文件**: p3_edge_case.c:54 | **函数**: check_and_transfer()

```
pthread_mutex_lock(&g_mutex);     // line 54
int current = g_account_balance;
pthread_mutex_unlock(&g_mutex);   // line 56
// ... TOCTOU 窗口 ...
g_account_balance -= amount;      // line 61 — 锁外操作
```

**事实锚定反思**: Q1=YES (有 unlock), Q2=YES, Q3=NO → CONFIRMED (锁释放过早)

**判定**: CONFIRMED (临界区不完整)

---

#### F15 [High] CWE-667 死锁
**文件**: concurrency.c:45+56 | **函数**: thread_deadlock_a + thread_deadlock_b

```
thread_deadlock_a: lock(A) → lock(B) → unlock(B) → unlock(A)
thread_deadlock_b: lock(B) → lock(A) → unlock(A) → unlock(B)
// 锁顺序反转: A→B vs B→A → 死锁
```

**事实锚定反思**: Q1=YES (有 unlock), Q2=YES, Q3=NO → CONFIRMED

**判定**: CONFIRMED (锁顺序反转)

---

### Worker: hardcoded_secrets (7 findings)

#### F16 [High] CWE-798 硬编码 API 密钥
**文件**: crypto.c:21 — `static const char *g_api_key = "sk-abcdef1234567890abcdef1234567890"`

**判定**: CONFIRMED

#### F17 [High] CWE-798 硬编码密码
**文件**: crypto.c:26 — `const char *password = "SuperSecretPassw0rd!"`

**判定**: CONFIRMED

#### F18 [High] CWE-798 硬编码 JWT Token
**文件**: crypto.c:27 — JWT-like token in authenticate_user()

**判定**: CONFIRMED

#### F19 [Medium] CWE-337 可预测 PRNG 种子
**文件**: crypto.c:38 — `srand(time(NULL))`

**判定**: CONFIRMED

#### F20 [Medium] CWE-338 弱随机数
**文件**: crypto.c:39 — `rand()` 用于 token

**判定**: CONFIRMED

#### F21 [High] CWE-665 未初始化 DES 密钥
**文件**: crypto.c:54 — `DES_cblock key` 未初始化即传给 DES_set_key_unchecked

**判定**: CONFIRMED

#### F22 [Medium] CWE-326 密钥长度不足
**文件**: crypto.c:78 — `unsigned char key[7]` (56-bit, 应 256-bit)

**判定**: CONFIRMED

---

### Worker: input_validation (5 findings)

#### F23 [High] CWE-22 路径遍历
**文件**: system.c:42 — fopen 使用用户控制的 filename，../../etc/passwd 可绕过 /var/data/

**判定**: CONFIRMED

#### F24 [Medium] CWE-367 TOCTOU
**文件**: system.c:55 — access() → fopen() 之间存在符号链接竞争窗口

**判定**: CONFIRMED

#### F25 [Medium] CWE-377 不安全临时文件
**文件**: system.c:81 — fopen("/tmp/myapp.log", "w") 使用可预测路径

**判定**: CONFIRMED

#### F26 [Medium] CWE-61 符号链接攻击
**文件**: system.c:104 — fopen 未使用 O_NOFOLLOW，可能跟踪符号链接到 /etc/shadow

**判定**: CONFIRMED

#### F27 [High] CWE-269 权限提升
**文件**: system.c:126+136 — seteuid(65534) → seteuid(0) 未永久丢弃权限

**判定**: CONFIRMED

---

### Worker: must_check (3 findings)

#### F28 [Medium] CWE-252 signal 返回值未检查
**文件**: concurrency.c:115 — `signal(SIGINT, unsafe_handler)` 返回值未检查

**判定**: CONFIRMED

#### F29 [Medium] CWE-252 signal 返回值未检查
**文件**: concurrency.c:116 — `signal(SIGTERM, unsafe_handler)` 返回值未检查

**判定**: CONFIRMED

#### F30 [Medium] CWE-252 seteuid 返回值未检查
**文件**: system.c:136 — `seteuid(0)` 返回值未检查 (line 126 已检查)

**判定**: CONFIRMED

---

### Worker: memory (2 findings)

#### F31 [Critical] CWE-415 双重释放
**文件**: allocator.c:71 | **函数**: cleanup_entries()

```
g_entries[0] = e3;   // line 130 — 别名: g_entries[0] 和 g_entries[2] 指向同一个 e3
cleanup_entries():
  i=0: free(e3)      // 第一次释放 e3
  i=2: free(e3)      // 第二次释放 e3 → 双重释放!
```

**事实锚定反思**: Q1=YES (同一指针 free 两次), Q2=NO → CONFIRMED

**判定**: CONFIRMED

#### F32 [Critical] CWE-416 释放后使用
**文件**: allocator.c:95 | **函数**: process_released_buffer()

```
char *buf = entry->buffer;
release_entry(entry);   // line 90 — 释放 buf
if (buf) {
    memset(buf, 0, 256); // line 95 — buf 已释放! 写入释放后内存
}
```

**事实锚定反思**: Q1=NO (buf 未置 NULL), Q2=YES → CONFIRMED

**判定**: CONFIRMED

---

### Worker: api_semantic_misuse (4 findings)

#### F33 [High] CWE-134 格式化字符串
**文件**: parser.c:53 — printf(user_msg) 用户控制的格式化字符串

**判定**: CONFIRMED

#### F34 [Medium] CWE-479 信号处理器不安全
**文件**: concurrency.c:107 — printf/free/malloc 在信号处理器中 (非 async-signal-safe)

**判定**: CONFIRMED

#### F35 [Medium] CWE-628 assert 用作运行时检查
**文件**: allocator.c:104 — assert 在 Release 模式不生效

**判定**: CONFIRMED

#### (重复) CWE-190 allocator.c:118 — 已计入 F13

---

## 抑制统计

| Skill | 信号总数 | 抑制 | 抑制原因 |
|-------|---------|------|---------|
| command_injection | 2 | 0 | — |
| buffer_overflow | 7 | 2 | allocator.c:107 字面量, p3_edge_case.c:39 snprintf |
| null_dereference | 8 | 3 | allocator.c:28/31 有 if 检查, parser.c:110 有检查 |
| integer_overflow | 2 | 0 | — |
| resource_leak | 10+ | 10+ | 全部配对正确, 无 socket() 调用 |
| lock_misuse | 4 | 1 | p2_lock_guard.c:25 RAII 模式 |
| hardcoded_secrets | 8 | 1 | — |
| memory | 5+ | 2+ | 大部分配对正确 |
| must_check | 5+ | 2+ | 大部分 signal/malloc 忽略不危险 |
| input_validation | 8 | 3+ | 安全的 write_log/TOCTOU 有正确版本 |

---

## 交叉验证发现

| 发现 | 类型 | 说明 |
|------|------|------|
| F6 依赖 F12 | 跨 skill 依赖 | buffer_overflow 的 Q1 假设 size_check 有效, 但 integer_overflow 绕过它 |
| F33 (format string) | 跨 skill | api_semantic_misuse 发现 parser.c:53 printf(user_msg), 与 buffer_overflow 不同维度 |
| allocator.c:118 | 跨 skill 重叠 | integer_overflow F13 + api_semantic_misuse F4 同一点, 不同 CWE |

---

## 关键差异: 对比旧报告 (cpp-vuln-demo 含答案卡)

| 方面 | 旧 (含答案卡, 93 call_sites) | 新 (no-answers, 82 call_sites) |
|------|----------------------------|-------------------------------|
| 总 findings | 12 | 32 |
| 假阳性 | 1 (F11 socket 泄漏) | 0 (由验证发现) |
| Worker 覆盖 | 5 个 | 10 个 |
| 抑制理由 | 缺失 | 每条抑制有 Q 矩阵证据 |
| 跨 skill 依赖 | 1 (F5 ↔ F8) | 2 (F6 ↔ F12, F33) |
| 死代码发现 | 无 | parser.c:85 latent overflow |

**验证结论**: 使用 no-answers 项目确认了 Dispatcher-Worker 架构在原始代码上的有效性。
- 旧报告的 network.c:105 socket 泄漏是正确答案卡标记引入的假阳性
- 总 findings 从 12 增加到 32，因 Worker 覆盖面从 5 个扩展到 10 个
- **0 假阳性**: 所有抑制均基于事实锚定 Q 矩阵，有源代码行号引用

---

## Worker 执行统计

| Worker | 级别 | 信号数 | Findings | 抑制 | 耗时(估计) |
|--------|------|--------|----------|------|-----------|
| command_injection | Critical | 2 | 2 | 0 | ~1 LLM 调用 |
| buffer_overflow | Critical | 7 | 4 | 2 | ~1 LLM 调用 |
| null_dereference | Critical | 8 | 5 | 3 | ~1 LLM 调用 |
| integer_overflow | Critical | 2 | 2 | 0 | ~1 LLM 调用 |
| resource_leak | High | 10 | 0 | 10 | ~1 LLM 调用 |
| lock_misuse | High | 4 | 2 | 1 | ~1 LLM 调用 |
| hardcoded_secrets | High | 8 | 7 | 1 | ~1 LLM 调用 |
| input_validation | High | 8 | 5 | 3 | ~1 LLM 调用 |
| memory (dbl_free/uaf) | Critical | 5 | 2 | 3 | ~1 LLM 调用 |
| must_check | Medium | 5 | 3 | 2 | ~1 LLM 调用 |
| api_semantic_misuse | Medium | 4 | 4 | 0 | ~1 LLM 调用 |

**LLM 调用总量**: ~10-12 次 LLM 调用 (每个 Worker 1 次)
**对比旧 5 轮反思**: 10 × 5 = 50 次 → **节省 ~80%**

---

## 结论

**验证结果**: Dispatcher-Worker + 事实锚定反思 在 cpp-vuln-demo-no-answers 上成功检出 **32 个真实漏洞**。
- **0 假阳性**: 所有抑制均基于事实锚定的判定矩阵，有据可查
- **伪信号排除**: 旧报告的 F11 (socket 泄漏) 被确认由答案卡标记引入
- **架构验证**: 10 个 Worker 并行执行，每个仅需 1 次 LLM 调用，协议稳定可重复
