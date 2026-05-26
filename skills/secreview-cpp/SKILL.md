---
name: secreview-cpp
description: 对 C/C++ 代码进行通用安全规范检视，关注内存安全和未定义行为规范
category: language-specific
language: cpp
topic: [memory, concurrency, system, crypto]
---


# secreview-cpp

对 C/C++ 代码进行通用安全规范检视，关注内存安全、未定义行为和系统安全最佳实践。

## 检视范围

### 语义层面
- 内存操作函数是否使用了安全替代品
- 格式字符串是否使用字面量
- 整数运算是否有溢出防护
- 资源管理是否遵循 RAII（C++）

### 规范合规
- 是否启用了编译器安全标志（`-fstack-protector`, `-D_FORTIFY_SOURCE=2`）
- 信号处理器是否仅调用异步安全函数
- setuid 程序是否遵循最小权限
- 临时文件是否安全创建

### 反模式识别
- C 风格 cast 在 C++ 代码中使用（应使用 `static_cast` 等）
- 裸指针管理资源（应使用 `std::unique_ptr`）
- `reinterpret_cast` 滥用
- 虚函数在构造函数/析构函数中调用
- 异常安全违反（析构函数抛出异常）
- `new`/`delete` 与 `malloc`/`free` 混用

## 与 secguard-cpp 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
