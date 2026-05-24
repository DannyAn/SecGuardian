---
category: concept
threat_type: race_condition
severity: medium
cwe: CWE-367
owasp: A01:2021 - Broken Access Control
---

# TOCTOU / 竞态条件 (Time-of-Check Time-of-Use)

程序在"检查条件"和"使用资源"之间存在时间差，攻击者利用这个窗口改变系统状态。

## 检测策略

### 核心原则
**检查和使用之间的操作必须原子化。**

1. **文件系统 TOCTOU**
   - `exists()` / `isFile()` 后接 `open()` / `read()` / `delete()`
   - 权限检查后接文件操作
   - 符号链接在检查和使用之间被替换

2. **权限检查 TOCTOU**
   - 认证检查后，实际操作前，会话状态可能变化
   - 用户权限查询后、操作执行前的窗口

3. **数据库竞态**
   - SELECT 后 UPDATE 未加锁
   - 计数器更新非原子（read + increment + write）

### 误报排除
- 使用文件描述符而非路径操作（fstat → fd 操作）
- 数据库事务 + 行锁 / 乐观锁
- 原子操作（O_CREAT|O_EXCL, rename, link）
- 单进程 / 单线程保证

## 修复指引

1. **文件操作**：使用文件描述符（fd），避免路径操作
2. **数据库**：使用事务 + 行锁 或 `UPDATE ... WHERE version = ?`
3. **权限检查**：检查后立即使用，或在操作内部再次验证
