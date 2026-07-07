# TASK-006: Create execution-model-current.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 6 / 7
> **Added**: Round 1 review

## 目标

创建 `docs/architecture/execution-model-current.md`，当前唯一执行路径文档。

## 内容要求

文档必须包含：

1. **The One Pipeline** — 从 trigger 到 output 的完整路径
2. **Stage Details** — 每个阶段的输入/输出/约束
3. **What This Pipeline Is NOT** — 不是 SAST、不是双运行时、不是 engine
4. **Pipeline Boundaries** — 每个阶段的边界

## 核心约束

- 不允许 dual runtime 表达
- 不允许 CI-as-runtime 框架
- 只描述当前系统

## 验证

- 文件存在：`docs/architecture/execution-model-current.md`
- 无 dual runtime 语言
