# TASK-003: Restructure secguard skill files (5 files)

> **Feature**: FEATURE-002 Contract Implementation
> **隶属 Task**: 3 / 5
> **文件**: skills/secguard/{cpp,go,java,python,js}/SKILL.md (5 files)
> **模式**: Detector Selection / Engine Instructions 分区 + 合约引用

## 目标

在 5 个 secguard SKILL.md 中增加架构分区，不删除任何内容。

## 具体要求

### 1. 分区标题（H2）

```
## 🎯 Detector Selection（Skill 层职责）
  (原有: 可用检测器 / 检查优先级 / 框架覆盖)

## ⚙️ Engine Instructions（Engine 层职责，当前由 LLM 代行）
  (原有: 执行流程 / Phase 1-5 / 输出协议 / 错误处理)
```

### 2. Detector Selection 分区内容

- cpp: 将现有的 "可用检测器" 和 Phase 2 的语言上下文（2.1-2.6）移入此分区
- go/java/python/js: 将现有的 "检查优先级" 和 "框架覆盖" 移入此分区
- 内容不变，只调整位置

### 3. Engine Instructions 分区内容

- cpp: Phase 1, 3, 4, 5（Phase 2 的语言上下文已移到 Detector Selection）
- go/java/python/js: 执行流程的其余部分
- 内容不变，只调整位置

### 4. 合约引用

Engine Instructions 分区起始处添加：
```
以下执行指令描述了检测器的运行方式。这些指令属于 Engine 职责
（参见 internal/engine/engine_contract.md）。当前由 LLM prompt 代行。
```

输出相关内容引用 output_contract.md：
```
输出格式参见 internal/output/output_contract.md。
```

### 5. 不做的

- ❌ 不删除任何检测器内容
- ❌ 不改检测器选择规则
- ❌ 不改执行指令内容

## 验证

- `grep "Detector Selection\|Engine Instructions"` 各文件 >= 2
- `grep "engine_contract.md\|output_contract.md"` 各文件 >= 1
- self-check 通过
