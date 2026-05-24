---
category: concept
threat_type: traversal
severity: high
cwe: CWE-22
owasp: A01:2021 - Broken Access Control
---

# 路径穿越 (Path Traversal)

攻击者使用 `../` 等特殊字符突破预期的文件目录边界，读取或写入任意文件。

## 检测策略

### 核心原则
**文件路径操作中，用户输入不得直接影响路径解析结果。**

1. **读取路径可控**
   - 文件读取 API（open、read、FileInputStream）参数包含用户输入
   - 用户可控的文件名直接拼接到基础路径后

2. **写入路径可控**
   - 文件上传路径、导出路径包含用户输入
   - 压缩包解压目标路径未校验（Zip Slip）

3. **路径解析函数绕过**
   - 先拼接后调用 `realpath`/`getCanonicalPath`（时序问题）
   - 符号链接未做限制

### 误报排除
- 用户输入仅用作 key 查找映射表
- 先获取规范路径再与白名单比较
- 文件操作限制在 chroot/sandbox

## 修复指引

1. **首选**：不直接用用户输入做文件名，使用 UUID/哈希映射
2. **次选**：获取规范路径后验证父目录匹配
3. **Zip Slip**：解压前验证每个条目的规范路径
