# TASK-003: Skills I/O Optimization (5 secguard skill files)

> **Feature**: FEATURE-004

## 目标

优化 skills/secguard/{go,java,python,js,cpp}/SKILL.md 中的 I/O 操作：
1. 源文件读取改为 index 驱动（读 index.json 符号表后按需读代码段）
2. 检测器加载改为 language-index.md 批量加载 + 按需加载详情

## 改动

每个 skill 文件：
- 删除「逐文件读取全部源文件」的指令
- 增加「使用 index.json symbols 定位检测目标，只读取相关代码段」的指令
- 删除「逐个加载 knowledge/guard-rules/ 检测器」的指令
- 增加「加载 knowledge/language-index.md 获取检测器清单」的指令
- 删除「逐条写入 finding 文件」的指令

## 验证

- deploy.sh all 正常
- go-vuln-demo 扫描时 shell command 数减少
