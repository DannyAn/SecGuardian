# TASK-002: Restructure commands/secfix.md + commands/secaudit.md

> **Feature**: FEATURE-002 Contract Implementation
> **隶属 Task**: 2 / 5
> **文件**: commands/secfix.md (137→~150行), commands/secaudit.md (313→~330行)
> **模式**: Command Layer / Engine Layer 分组 + 合约引用

## 目标

在两个 command 文件中增加架构分层标记，不删除任何内容。

## 具体要求

### secfix.md

**Command Layer 分组**（H2）：
- Usage: 扫描来源选择逻辑
- Key Principles
- Workflow Integration

**Engine Layer 分组**（H2 + 合约引用）：
- How It Works（执行逻辑）
- Implementation（补丁生成细节）
- Output / Patch Format / Metadata Format

### secaudit.md

**Command Layer 分组**（H2）：
- Usage
- Output Path Convention（从 输出路径约定）
- Available Audit Domains（从 可用审计域）

**Engine Layer 分组**（H2 + 合约引用）：
- Audit Framework
- Pre-flight Checklist
- Step 1-5 管线
- Output / Results / Findings

### 2. 合约引用

每个 Engine Layer 分组起始处添加：
```
以下内容属于 Engine 职责（参见 internal/engine/engine_contract.md）。
```

### 3. 不做的

- ❌ 不删除任何现有内容
- ❌ 不改命令行为

## 验证

- `grep "Command Layer\|Engine Layer"` 各文件 >= 2
- `grep "engine_contract.md"` 各文件 >= 1
- self-check 通过
