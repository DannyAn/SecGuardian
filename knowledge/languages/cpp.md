---
category: language
languages: [c, cpp, c++]
frameworks: [Qt, Boost, POCO, Win32 API, POSIX API]
---

# C/C++ 语言安全画像

C/C++ 的内存安全特性、危险函数清单、未定义行为和编译器安全选项。

## 危险函数清单

### 缓冲区溢出 (内存拷贝)
| 函数 | 风险 | C11 安全替代 (推荐) | POSIX 替代 |
|------|------|---------------------|-----------|
| `strcpy(dst, src)` | 无边界检查 | `strcpy_s(dst, dsize, src)` | `strncpy(dst, src, n)` + 手动截断 |
| `strcat(dst, src)` | 无边界检查 | `strcat_s(dst, dsize, src)` | `strncat(dst, src, n)` |
| `sprintf(buf, fmt, ...)` | 无边界检查 | `sprintf_s(buf, dsize, fmt, ...)` | `snprintf(buf, n, fmt, ...)` |
| `gets(buf)` | 完全无法安全使用 | `gets_s(buf, n)` | `fgets(buf, n, stdin)` |
| `scanf("%s", buf)` | 无长度限制 | `scanf_s("%s", buf, dsize)` | `scanf("%Ns", buf)` 指定宽度 |
| `vsprintf(buf, fmt, ...)` | 无边界检查 | `vsprintf_s(buf, dsize, fmt, ...)` | `vsnprintf(buf, n, fmt, ...)` |
| `memcpy(dst, src, n)` | n 来自不可信源 | `memcpy_s(dst, dsize, src, n)` | 验证 n ≤ dst 大小 |
| `memmove(dst, src, n)` | 同上 | `memmove_s(dst, dsize, src, n)` | 同上 |
| `strncpy(dst, src, n)` | 不保证 null 终止 | `strncpy_s(dst, dsize, src, n)` | 手动追加 `\0` |
| `strtok(str, delim)` | 修改输入 + 不可重入 | `strtok_s(str, delim, &ctx)` | `strtok_r(str, delim, &ctx)` |

#### C11 Annex K `_s` 函数说明

ISO C11 Annex K (ISO/IEC 9899:2011) 定义了一组安全增强函数，特征是 `_s` 后缀。
这是**大厂编程规范中的首选替代方案**（Microsoft 强制要求，Google/Apple 在内部也有类似封装）。

**核心安全特性：**
- **运行时约束处理**：所有 `_s` 函数在参数非法时调用 constraint handler（默认终止程序），不会静默失败
- **禁止空指针**：`dst`/`src` 为 NULL 时触发 handler，而非 UB
- **显式大小参数**：每个 output buffer 都需要传入 `dsize`（以元素计），编译器可静态检查
- **零大小被拒绝**：`dsize=0` 且 `dst!=NULL` 仍触发 handler（防止不小心传递 0 大小）

**常用 _s 函数对照表：**

| 原始函数 | `_s` 版本 | 额外参数 | 关键行为差异 |
|---------|----------|---------|-------------|
| `fopen(path, mode)` | `fopen_s(&f, path, mode)` | 文件指针的地址 | 返回值是 errno_t，且独占/共享模式可配 |
| `scanf(...)` | `scanf_s(...)` | 每个 %s/%c/%[ 后必须跟 dsize | 防止缓冲区溢出 |
| `qsort(base, n, size, cmp)` | `qsort_s(base, n, size, cmp, ctx)` | 额外 context 参数 | 传递上下文给比较函数 |
| `bsearch(key, base, n, size, cmp)` | `bsearch_s(key, base, n, size, cmp, ctx)` | 同上 | 同上 |
| `memset(dst, val, n)` | `memset_s(dst, dsize, val, n)` | dsize | 防止跨边界写入；编译器不得优化掉 |
| `wcsncpy(dst, src, n)` | `wcsncpy_s(dst, dsize, src, n)` | dsize | 宽字符版本 |

**检测时的处理原则：**
- 如果代码使用了 `xxx_s(dst, dsize, ...)` 且 `dsize` 正确（`sizeof(dst)` 或显式长度），则视为 **安全替代，不应报告为漏洞**
- 如果 `dsize` 使用了 `_TRUNCATE` 宏，需额外检查是否检查了截断返回值
- 如果代码仅使用 `strncpy` 等 POSIX 替代但未手动 null 终止，仍为风险
### 格式化字符串
| 函数 | 风险 |
|------|------|
| `printf(user_str)` | 格式字符串攻击 — `%n` 写入任意地址 |
| `fprintf(f, user_str)` | 同上 |
| `syslog(LOG_ERR, user_str)` | 同上 |
| `snprintf(buf, n, user_str)` | 同上（虽然限制了输出，但 `%n` 仍危险） |

### 命令执行
| 函数 | 风险 | 替代 |
|------|------|------|
| `system(user_cmd)` | Shell 注入 | `execve` 系列（不经过 shell） |
| `popen(user_cmd, "r")` | Shell 注入 | `fork+execve` |
| `execle`/`execlp` 路径受控 | 路径劫持 | 使用绝对路径 |

### 整数安全
| 模式 | 风险 |
|------|------|
| `size_t len + offset` | 整数溢出 wrap-around |
| `malloc(user_size)` | 大小为 0 或溢出 |
| `int * signed 比较 unsigned` | 符号转换导致检查绕过 |
| `size_t < 0` 检查 | 对无符号类型无意义 |
| `new int[n]` n 来自外部 | 分配过量内存 |

### 内存管理
| 模式 | 风险 |
|------|------|
| `malloc` 后未检查 NULL | 空指针解引用 |
| `free(ptr)` 后继续使用 ptr | Use-After-Free |
| `free(ptr)` 两次 | Double Free |
| 异常路径未释放资源 | 内存泄露 |
| C++ `new` 后异常未 `delete` | 泄露/不匹配 |

### 自定义分配器 (Custom Allocator) 识别

在纳入式开发（如内核、嵌入式、游戏引擎）中，直接使用 `malloc`/`free` 很少见。
大厂项目通常会定义自己的分配器包装，以便于审计、追踪和替换。检测时必须能识别这些模式。

**常见命名模式（任一种都应识别为分配/释放函数）：**
```
分配函数:  xxx_malloc, xxx_alloc, xxx_new, xxx_create, ALLOC_xxx, pool_alloc
释放函数:  xxx_free, xxx_delete, xxx_destroy, xxx_release, FREE_xxx, pool_free
重分配:    xxx_realloc, xxx_resize
```

**典型自定义分配器示例：**

```c
// 模式 1: 前缀包装（最常见）
void* my_malloc(size_t size);
void  my_free(void* ptr);
void* my_realloc(void* ptr, size_t new_size);

// 模式 2: 宏包装
#define MALLOC(s)   mem_pool_alloc(&global_pool, s)
#define FREE(p)     mem_pool_free(&global_pool, p)

// 模式 3: 上下文分配器（arena/zone）
void* zone_alloc(Zone* z, size_t s);
void  zone_free_all(Zone* z);          // 批量释放整个 zone

// 模式 4: 工厂/管理器模式
Object* object_create(Manager* mgr);
void    object_destroy(Object* obj);

// 模式 5: C++ operator new/delete 重载（类级别）
void* operator new(size_t size);
void  operator delete(void* ptr);
```

**检测时的处理原则：**

1. **识别阶段**：扫描目标代码中是否存在 `*_malloc`/`*_alloc`/`*_new`/`*_create`/`ALLOC_*` 和对应的 `*_free`/`*_delete`/`*_destroy`/`*_release`/`FREE_*` 配对
2. **映射阶段**：将自定义函数映射到其语义等价物
   - `xxx_malloc(s)` → 等价于 `malloc(s)`，适用所有 malloc 相关检测器
   - `xxx_free(p)` → 等价于 `free(p)`，适用 UAF/Double Free/Leak 检测器
   - `xxx_realloc(p, s)` → 等价于 `realloc(p, s)`
3. **配对验证**：验证 `xxx_malloc` 只由 `xxx_free` 释放，而非混用 `free()` 或其他变体（mismatched-free 检测器扩展）
4. **统计追踪**：对自定义分配器的返回值检查和生命周期分析与标准函数相同

### 文件操作
| 模式 | 风险 |
|------|------|
| `open(user_path, ...)` 未验证 | 路径穿越 / 符号链接攻击 |
| `access(path, R_OK)` 后 `open(path)` | TOCTOU |
| `chmod` / `chown` 符号链接跟随 | 权限变更到错误文件 |
| `tmpfile()` / `tmpnam()` | 竞态条件 / 可预测文件名 |

### 进程/权限
| 模式 | 风险 |
|------|------|
| `setuid(0)` 未检查失败 | 权限维持失败未发现 |
| fork 后文件描述符未关闭 | fd 泄露到子进程 |
| 信号处理器中调用非异步安全函数 | 未定义行为 |

## 编译器安全

### 应启用的标志
```
-fstack-protector-strong   # Stack canary
-fPIE -pie                 # ASLR
-Wall -Wextra -Werror      # 编译时警告
-D_FORTIFY_SOURCE=2        # 加固内存函数
-Wformat -Wformat-security  # 格式字符串检查
-Wl,-z,relro -Wl,-z,now    # Full RELRO
-fno-omit-frame-pointer     # 便于调试
```

### C++ 特有问题
- RAII 违反（资源未绑定生命周期）
- 虚函数表覆盖（vtable 劫持）
- 异常抛出时的资源泄露
- `reinterpret_cast` 绕过类型安全
- Lambda 捕获引用悬空

## 检测优先级

1. `strcpy` / `strcat` / `sprintf` / `gets` → Critical
2. `printf(user_input)` → Critical
3. `system(user_input)` → Critical
4. `free(p)` 后使用 → Critical
5. `malloc(size)` 整数溢出 → High
6. TOCTOU `access+open` → High
7. 未启用栈保护 → Medium
