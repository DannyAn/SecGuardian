# TASK-007: Create engineering-principles.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 7 / 7
> **Added**: Round 1 review

## 目标

创建 `docs/architecture/engineering-principles.md`，反过度设计约束。

## 内容要求

必须包含以下原则：

1. **EP-1**: 无提前 execution kernel 抽象
2. **EP-2**: 无未实现 runtime
3. **EP-3**: CI/CD 设计基于 artifact
4. **EP-4**: Engine 抽象需 2+ production use cases
5. **EP-5**: Knowledge 是 Markdown，不是 DSL
6. **EP-6**: 单管线，多个 consumption mode
7. **EP-7**: 文档描述现有系统，而非未来系统

每条原则包含：Statement, Rationale, What to Do Instead, Violation/Non-Violation Example

## 验证

- 文件存在：`docs/architecture/engineering-principles.md`
- 7 条原则全部定义
