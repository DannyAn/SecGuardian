---
category: concept
threat_type: injection
severity: critical
cwe: CWE-77
owasp: A03:2021 - Injection
---

# 命令注入 (Command Injection)

攻击者通过用户输入拼接系统命令，导致服务器执行恶意的操作系统命令。

## 检测策略

### 核心原则
**用户输入不得直接拼接到系统命令中。** 检测时关注以下模式：

1. **命令执行函数 + 用户输入**
   - 搜索命令执行 API（exec、system、popen、subprocess、Runtime.exec）的参数
   - 检查参数中是否存在字符串拼接或插值

2. **Shell 解释器调用**
   - 关注显式调用 shell（sh -c、bash -c、cmd /c）的场景
   - Shell 元字符过滤不完整

3. **脚本引擎注入**
   - eval 类函数参数包含用户输入

### 误报排除
- 参数数组形式调用（非 shell 模式）
- 硬编码命令 + 白名单参数
- 沙箱执行环境

## 修复指引

1. **首选**：使用 API 而非命令执行
2. **次选**：参数数组形式调用，绕过 shell 解析
3. **不得已时**：严格白名单 + shell 元字符转义
