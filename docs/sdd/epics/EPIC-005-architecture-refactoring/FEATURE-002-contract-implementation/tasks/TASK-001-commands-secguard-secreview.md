# TASK-001: Restructure commands/secguard.md + commands/secreview.md

> **Feature**: FEATURE-002 Contract Implementation
> **隶属 Task**: 1 / 5
> **文件**: commands/secguard.md (594→~610行), commands/secreview.md (327→~340行)
> **模式**: Command Layer / Engine Layer / Output Layer 分组 + 合约引用

## 目标

在两个 command 文件中增加架构分层标记，不删除任何内容。

## 具体要求

### 1. 增加分组标题

将现有 section 归入以下分组（H2 标题）：

```
## ⚙️ Command Layer — 参数解析 + 调度 + 输出路径
  (原有: 使用方式、输出路径约定、命名空间)

## 🛠️ Engine Layer — 执行逻辑（当前由 LLM prompt 代行）
  (原有: 派发规则与执行步骤、前置检查、Step 1-5、输出结构化 findings)

## 📄 Output Layer — 输出格式（参见 internal/output/output_contract.md）
  (原有: 输出、输出文件列表)
```

### 2. Engine Layer 分组下增加合约引用

在每个 Engine Layer 分组起始处添加注释：

```
以下内容属于 Engine 职责（参见 internal/engine/engine_contract.md）。
当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。
```

### 3. Output Layer 分组下增加合约引用

```
以下输出格式遵循 internal/output/output_contract.md。
```

### 4. 不做的

- ❌ 不删除任何现有内容
- ❌ 不改现有 section 内部的措辞
- ❌ 不改命令行为

## 验证

- `grep "^##.*Command Layer\|^##.*Engine Layer\|^##.*Output Layer"` 各文件 >= 3
- `grep "engine_contract.md"` 各文件 >= 1
- self-check 通过
