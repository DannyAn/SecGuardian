# TASK-004: Restructure secreview + secaudit skill files (6 files)

> **Feature**: FEATURE-002 Contract Implementation
> **隶属 Task**: 4 / 5
> **文件**: skills/secreview/{cpp,go,java,python,js}/SKILL.md (5 files) + skills/secaudit/SKILL.md (1 file)
> **模式**: Review Focus / Engine Instructions 分区 + 合约引用

## 目标

在 6 个 skill 文件中增加架构分区，不删除任何内容。

## 具体要求

### secreview skills (5 files)

分区标题（H2）：
```
## 🎯 Review Focus（Skill 层职责）
  (原有: Difference from secguard, Reference Resources)

## ⚙️ Engine Instructions（Engine 层职责，当前由 LLM 代行）
  (原有: Execution Phases 1-5)

## 📄 Output Protocol
  (原有: Output Completeness Requirements)
```

### secaudit SKILL.md (1 file)

分区标题（H2）：
```
## 🎯 Audit Domain Selection（Skill 层职责）
  (原有: 何时使用、分析方法参考、--focus 单项模式)

## ⚙️ Engine Instructions（Engine 层职责，当前由 LLM 代行）
  (原有: 工作流 Phase 1-12、汇总报告)
```

### 合约引用

- Engine Instructions 分区 → `internal/engine/engine_contract.md`
- Output 分区 → `internal/output/output_contract.md`

### 不做的

- ❌ 不删除任何内容
- ❌ 不改行为

## 验证

- `grep "Review Focus\|Engine Instructions\|Audit Domain Selection\|Output Protocol"` 各文件 >= 对应的分区数
- `grep "engine_contract.md\|output_contract.md"` 各文件 >= 1
- self-check 通过
