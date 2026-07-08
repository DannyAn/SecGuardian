---
detector: review.cpp
type: review-rule
language: cpp
max_severity: Critical
cwe: CWE-000
anti_pattern_count: 14
---

# C/C++ 安全反模式检测矩阵

代码审查中需要关注的 C/C++ 特有安全反模式及具体检测规则。

## 内存管理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `new`/`delete` 与 `malloc`/`free` 混用 | `malloc\(` 与 `delete\s` 在同一函数；`new\s` 与 `free\(` 在同一函数 | Critical |
| `delete` 数组用 `delete` 非 `delete[]` | `(new\s+\w+\[\|new\s+\w+<\w+>\[)` 但 `delete\s+(?!\[\])` | Critical |
| 异常路径未释放资源 | `(malloc\|new)\s[^;]*;[^}]*throw[^}]*(?!(free\|delete))` | High |
| 裸指针管理所有权 | 成员变量为 `\w+\*\s+\w+` 且类无析构函数/`unique_ptr` | High |
| 构造函数中 `new` 异常不安全 | `new\s` 在构造函数中，且无 try-catch 包装 | Medium |

## 类型安全反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| C 风格 cast `(Type)val` | `\([a-zA-Z_]\w*\**\s*\)\s*\w` 在 .cpp 文件中 | Medium |
| `reinterpret_cast` 非必要使用 | `reinterpret_cast<` 且非与 C API/硬件寄存器交互 | Medium |
| `const_cast` 修改 const 对象 | `const_cast<` 且该对象原本声明为 `const` | High |
| 函数指针 cast 不兼容签名 | `reinterpret_cast<.*\(\*\)` 或 `\(.*\(\*\)\(` | High |

## 并发反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `volatile` 用作同步 | `volatile\s+\w+` 在多线程上下文中（非 MMIO） | High |
| 无锁数据结构手写 | `std::atomic.*(compare_exchange\|fetch_add)` + 自定义循环 | Medium |
| 析构函数中访问静态对象 | `~\w+\(\)[^}]*\w+::\w+\(\)` 调用静态对象方法 | Medium |
| mutex lock 后异常未解锁 | `\.lock\(\)[^}]*throw` 无 `unlock` (应用 `lock_guard`) | High |

## 错误处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 返回值忽略 | `\w+\([^)]*\)\s*;` 返回 `int`/`errno_t` 且返回值未被赋值/检查 | High |
| assert 用于安全检查 | `assert\(` 含 `ptr\|!= NULL\|>=` 非调试断言 | Medium |
| `__FILE__`/`__LINE__` 暴露到输出 | `printf.*__FILE__\|fprintf.*__LINE__` 在非 DEBUG 条件编译中 | Medium |
| errno 未检查 | `\w+\([^)]*\);\s*\n(?!.*errno)` 调用可能设置 errno 的函数 | Medium |

## 未定义行为

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 有符号整数溢出 | `INT_MAX\|INT_MIN` 运算无溢出检查 | High |
| 重叠内存 `memcpy` | `memcpy\([^,]*,[^,]*,[^)]*\)` 且源/目标区域可能重叠 | High |
| 移位超出范围 | `<<\s*(31\|63)` 或 `>>\s*` 负数移位 | Medium |
| 空指针成员函数调用 | `\w+->\w+\(\)` 前无空指针检查 | High |
