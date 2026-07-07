# TASK-008: Cross-Reference Integration — Architecture Docs ↔ Contracts

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 8 / 8
> **来源**: Round 3 review — 架构文档与合约文档相互独立，缺少交叉引用

## 目标

将 3 份 Round 3 合约文档（engine_contract.md, output_contract.md, ci-cd-interface.md）
集成进已有架构文档的引用体系。

## 需要修改的文档

| 文档 | 修改点 | 引用目标 |
|------|--------|---------|
| architecture-vNext.md §7 | 项目映射表新增合约行 | engine_contract.md, output_contract.md, ci-cd-interface.md |
| runtime-model.md §4 | CI 验证层段末添加引用 | ci-cd-interface.md |
| security-engine.md §7 | CI 集成段末添加引用 | engine_contract.md, output_contract.md |
| execution-model-current.md §4 | 输出层段末添加引用 | output_contract.md |
| engineering-principles.md EP-3 | 原则段末添加引用 | ci-cd-interface.md |

## 验证

- 5 个文档均包含对应合约引用
- `grep -c "engine_contract\|output_contract\|ci-cd-interface" docs/architecture/*.md` >= 5
