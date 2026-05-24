---
category: concept
threat_type: memory
severity: critical
cwe: CWE-120
owasp: N/A (Language specific)
---

# 缓冲区溢出 (Buffer Overflow)

程序向缓冲区写入超出其容量的数据，覆盖相邻内存，可能导致代码执行或程序崩溃。主要影响 C/C++，其他语言通过 FFI/cgo 间接影响。

## 检测策略

### 核心原则
**内存操作必须边界检查。** 检测以下高危函数和模式：

1. **不安全的字符串函数**
   - `strcpy` / `strcat` / `sprintf` / `gets` — 不检查边界
   - `scanf("%s")` 无长度限制
   - 手工循环复制字符串无边界检查

2. **不安全的格式化**
   - `printf(user_input)` — 格式字符串攻击
   - `sprintf` 变体 — 缓冲区大小不足

3. **内存拷贝未验证大小**
   - `memcpy` / `memmove` / `bcopy` — dest 大小 < count
   - 外部输入的 size 参数直接用于分配或拷贝

4. **数组越界**
   - 循环边界由外部输入控制
   - 索引值未经范围检查直接用于数组访问

### 误报排除
- 编译器/静态分析已验证的固定长度
- 使用安全替代品（strncpy + 手动截断、snprintf）
- Rust/Safe Rust、Memory-safe 语言的内置边界检查

## 修复指引

1. **首选**：使用安全语言（Rust, Go, Java）重写风险模块
2. **次选**：使用 C++ 安全容器（std::string, std::vector）
3. **C 语言必要**：用安全版本（strncpy, snprintf）+ 静态分析 + fuzzing
