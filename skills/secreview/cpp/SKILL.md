---
name: secreview-cpp
description: 对 C/C++ 代码进行通用安全规范检视，关注内存安全和未定义行为规范。当用户请求C/C++代码规范检视、C++反模式识别、内存安全规范审查、C++最佳实践审计时使用。
category: language-specific
language: cpp
topic: [memory, concurrency, system, crypto]
---

# 安全规范检视 — C/C++

对 C/C++ 代码进行通用安全规范检视，关注内存安全、未定义行为和系统安全最佳实践。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 执行流程

### Phase 1: 加载上下文

1. 读取 `index.json`，获取 `files`、`symbols.functions`、`call_graph.edges`
2. 加载 `knowledge/languages/cpp.md` 获取 C/C++ 安全陷阱清单
3. 加载 `references/cpp-security-cheatsheet.md` 获取 SEI CERT C/C++ 规范映射

### Phase 2: 语义层面检视

逐函数按以下维度审查：

| # | 检查项 | 检测方法 | 示例：不合规 |
|---|--------|---------|-------------|
| 1 | 内存操作安全 | 搜索 `strcpy`/`strcat`/`sprintf`/`gets` → 是否可用安全替代 | `strcpy(buf, src);` → 应使用 `strncpy` |
| 2 | 格式字符串 | 搜索 `printf(`/`fprintf(` → 首个参数是否为字面量 | `printf(userInput);` → 应为 `printf("%s", userInput);` |
| 3 | 整数溢出 | 搜索 `malloc(`/`calloc(` → 乘法运算有无溢出检查 | `malloc(n * sizeof(T))` → 应检查 `n > SIZE_MAX / sizeof(T)` |
| 4 | RAII 合规 (C++) | 搜索 `new`/`delete` → 是否可用 `std::unique_ptr`/`std::vector` | `T* p = new T(); ... delete p;` → 应使用智能指针 |
| 5 | 数组边界 | 搜索 `arr[`/`ptr[` → 索引值有无范围校验 | `buf[i]` 未校验 `i < sizeof(buf)` |

### Phase 3: 规范合规检视

| # | 检查项 | 检测方法 | 修复指引 |
|---|--------|---------|---------|
| 1 | 编译器安全标志 | 检查 Makefile/CMakeLists.txt 编译选项 | 添加 `-fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIE -pie` |
| 2 | 信号安全 | 搜索 `signal(` → handler 内是否仅调用异步安全函数 | 信号 handler 仅设置 `volatile sig_atomic_t` 标志位 |
| 3 | setuid 安全 | 搜索 `setuid(`/`setgid(` → 是否尽早 drop privilege | fork 后立即 `setuid()`，exec 前降至最小权限 |
| 4 | 临时文件 | 搜索 `tmpfile(`/`tmpnam(`/`mktemp(` → 是否安全创建 | 使用 `mkstemp()` 替代 `tmpnam()`，设置 `umask(077)` |

### Phase 4: 反模式识别

| # | 反模式 | 检测特征 | 修复方案 |
|---|--------|---------|---------|
| 1 | C 风格 cast | C++ 代码中 `(Type)expr` | 替换为 `static_cast<>`/`dynamic_cast<>`/`const_cast<>` |
| 2 | 裸指针所有权 | 函数返回/参数传递 `T*` 且语义为转移所有权 | 使用 `std::unique_ptr<T>` 或 `std::shared_ptr<T>` |
| 3 | reinterpret_cast 滥用 | 非底层 I/O 场景使用 `reinterpret_cast` | 优先使用其他 cast，必要时加注释说明合理性 |
| 4 | 虚函数在 ctor/dtor | 构造函数或析构函数中调用虚函数 | 将初始化逻辑移至 `Init()` 或使用工厂模式 |
| 5 | 析构抛异常 | 析构函数中有 `throw` 或无 `noexcept` | 析构函数必须 `noexcept`，异常就地捕获吞下 |
| 6 | new/delete 混用 malloc/free | 同一对象跨分配释放方式不一致 | 统一使用 new/delete 或 malloc/free，严格配对 |

### Phase 5: 输出

按 `knowledge/protocols/scan-output.md` 生成报告，格式为 `report.md` + `results.sarif` + `summary.json`。

每个发现记录：

- 文件路径 + 行号 + 函数名（来自 index.json）
- 不合规描述 + 违反的规范条目
- 修复建议（含代码 before/after）

## 与 secguard-cpp 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
| 覆盖 | CWE Top 25 + 60 检测器 | SEI CERT + MISRA + 最佳实践 |

## 参考资源

- `references/cpp-security-cheatsheet.md` — C/C++ 安全速查表
- `knowledge/standards/sei-cert-c.md` — SEI CERT C 编码标准映射
- `knowledge/standards/sei-cert-cpp.md` — SEI CERT C++ 编码标准映射

## 输出完整性要求

> **输出协议**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。
>
> Command 层 Step 4b 质量门禁强制检查每个检出的四段式完整性：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 违规代码行
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（指出违反的安全编码规范条款）
> 3. **⚠️ Impact** — 不合规可能导致的安全风险 + 适用攻击场景
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + SEI CERT/OWASP 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注关联代码位置，`fixes` 包含 before/after 替换。
