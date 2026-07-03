# Architecture Decision Records — FEATURE-008

> **Feature**: FEATURE-008 Audit Framework
> **Context**: 根据 ChatGPT 建议，将 SecAudit 从 18 个平铺 skill 升级为 Rule Pack + Framework 架构

---

## ADR-001: 以 `audit-framework/` 作为框架根目录

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

ChatGPT 建议增加 `audit-framework/` 根目录。需要决定该目录的位置和命名。

### Decision

在项目根目录创建 `audit-framework/`，而非放入 `internal/` 或 `knowledge/` 或 `skills/`。

理由：
1. Rule Pack 是**产品级资产**，不是内部实现细节（`internal/` 不合适）
2. Rule Pack 是**知识文件**，不是 AI Agent 的 skill 指令（`skills/` 不合适）
3. 它是一个独立的架构层次——类似于 `scripts/`、`examples/`、`docs/` 的根级目录

### Consequences

- `audit-framework/` 与 `skills/`、`knowledge/`、`commands/` 平级
- 部署时 rule pack 作为独立单元被打包，而非 skill 的附属物
- 未来可以有 `audit-framework/rulepacks/company-redline/` 独立安装

---

## ADR-002: 规则文件从 `knowledge/` 迁移到 `rulepacks/`

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

当前审计规则文件在 `knowledge/audit-rules/*.md`。ChatGPT 建议放入 `audit-framework/rulepacks/<name>/rules/`。

### Decision

**MVP 阶段不移除旧文件**，而是：
1. 创建 `audit-framework/rulepacks/secguardian/rules/`，将规则文件从 `knowledge/audit-rules/` **复制**过去
2. 更新所有 `skills/secaudit/*/SKILL.md` 引用指向新路径
3. `knowledge/audit-rules/` 标记为 legacy，但不移除（保持 self-check 兼容）

**未来**：当所有 skill 文件更新完毕且 self-check 验证新路径后，逐步弃用 `knowledge/audit-rules/`。

### Consequences

- `knowledge/audit-rules/` 和 `audit-framework/rulepacks/secguardian/rules/` 短期内内容重复
- self-check 需要验证新路径（本次不修改 self-check 脚本，仅验证新增结构）
- `skill/secaudit/*/SKILL.md` 中的引用路径需要更新

---

## ADR-003: pack.json 格式

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

需要一个机器可读的清单文件来描述 rule pack 的组成和标准映射。

### Decision

使用 JSON 格式，字段如下：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | ✅ | Rule pack 唯一标识 |
| `version` | string | ✅ | semver 版本号 |
| `title` | string | ✅ | 人类可读标题 |
| `description` | string | ✅ | 用途描述 |
| `standards` | object | ✅ | 覆盖的标准映射（如 `{"owasp-asvs": ["V2","V3"]}`） |
| `rules` | array | ✅ | 规则列表，每项含 `id`, `title`, `file`, `severity`, `standards` |

否决的方案：

| 方案 | 否决原因 |
|------|---------|
| YAML | AI Agent 解析 YAML 不如 JSON 可靠（缩进敏感），JSON 在任何语言中都有高质量 parser |
| TOML | 简单的 key-value 是够用，但需要表达嵌套的 standards mapping，TOML 嵌套语法不直观 |
| Markdown frontmatter | 只能放在单文件中，无法表达 rule pack 级别的 metadata |

### Consequences

- `pack.json` 是 AI Agent 加载 rule pack 的唯一入口
- 规则文件保持 Markdown 格式（AI Agent 的最自然的阅读格式）
- 后续可开发 `pack.json --validate` CLI 验证规则完整性

---

## ADR-004: CLI 使用 `--rulepack` 而非子命令

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

ChatGPT 建议 `/secaudit --rulepack owasp-asvs`。有两种实现方式：`--rulepack` 参数或子命令 `/secaudit owasp-asvs`。

### Decision

使用 `--rulepack` 参数：

```
/secaudit --rulepack secguardian                          ← 默认
/secaudit --rulepack company-redline-v3 ./src python       ← 企业基线
/secaudit --rulepack owasp-asvs ./src java                 ← OWASP ASVS
/secaudit --rulepack pci-dss ./src java --sarif            ← 组合选项
```

理由：
1. **兼容**：`--rulepack` 是附加参数，不影响 `path` 和 `language` 等现有参数
2. **可选**：省略 `--rulepack` 时使用默认 `secguardian`，不破坏现有工作流
3. **可组合**：`--rulepack` 可以和 `--sarif` 等已有参数自由组合

### Consequences

- AI Agent 需要先解析 `--rulepack`，加载对应 pack.json，再执行审计
- 当前已有的工作流 `./secaudit <skill> <path>` 仍然有效
- `--rulepack` 和 skill 名可以同时使用（`--rulepack secguardian --skill cryptography`）

---

## ADR-005: AI Agent 作为执行引擎

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

ChatGPT 建议 `engine/` 作为框架核心。目前框架的"执行引擎"是 AI Agent 本身（加载 Markdown skill → 分析代码 → 输出 findings）。

### Decision

MVP 阶段：`engine/` 作为**文档化的执行规范**，而非独立可执行程序：

- `engine/README.md` 定义：AI Agent 执行 rule pack 的标准流程
- 流程：加载 `pack.json` → 解析 rules → 按顺序执行 rules → 汇总 findings → 输出 report
- 不编写独立的 engine 二进制（未来可以抽象为独立引擎）

**未来**：当需要独立于 AI Agent 运行（如 CI/CD 预检查）时，可以将 engine 实现为 Go module 或 Python 库。

### Consequences

- MVP 阶段不需要任何 Go 或 Python 代码变更
- engine 的行为完全由 AI Agent 的 prompt 指令定义
- `templates/` 和 `reporters/` 同样保持文档化规范，等待未来实现
