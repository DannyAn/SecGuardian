# ADR-006: SECGUARDIAN_HOME 替代多路径搜索

> **Feature**: FEATURE-004-deployment-home-path
> **日期**: 2026-07-04
> **状态**: 已采纳

## 决策

使用 SECGUARDIAN_HOME 环境变量替代多路径搜索循环。

## 备选方案

| 方案 | 已否决原因 |
|------|-----------|
| A. 保留多路径搜索 | 80 条硬编码路径，维护负担高 |
| B. 符号链接到固定路径 | 需要 root/sudo，跨平台不可行 |
| C. 项目级 SECGUARDIAN_HOME 文件 | AI 跨项目时失效 |
| D. ✅ SECGUARDIAN_HOME env var | deploy.sh 写入一次，命令引用一次，bash 默认值支持 dev 回退 |
