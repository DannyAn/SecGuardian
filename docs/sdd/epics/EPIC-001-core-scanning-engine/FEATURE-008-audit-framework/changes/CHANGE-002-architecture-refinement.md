# CHANGE-002: Audit Framework 架构职责收敛

> **Feature**: FEATURE-008-audit-framework
> **日期**: 2026-07-02 (updated 22:00)
> **类型**: 架构职责优化 (Architecture Refinement)
> **原则**: 防止知识重复，职责清晰分离

## Reason

### 问题

FEATURE-008 MVP 在 `audit-framework/rulepacks/secguardian/rules/` 下创建了 17 个规则文件，与 `knowledge/audit-rules/` 完全重复。这导致：

1. **双重维护**：每次修改规则需要同步两个位置，diff 表明两个目录的文件内容完全相同
2. **职责混淆**：`audit-framework/` 本该是 Audit Execution Framework，却变成了规则容器
3. **违反 SSOT**：`knowledge/` 是声明的唯一安全知识源，但 `audit-framework/rulepacks/` 打破了这一原则
4. **扩展困难**：新增企业安全规范（OWASP ASVS、PCI DSS、CIS Benchmark）会进一步加剧重复

### SDD 原则引用

> **Knowledge 是唯一知识源**（Single Source of Truth）：任何地方不得复制规则。
> **Audit Framework 不拥有 Rule**：Framework 只描述"如何审计"，不拥有"审计什么"。

## Change

### What changed

| 之前 (FEATURE-008 MVP) | 之后 (Architecture Refinement) |
|------------------------|-------------------------------|
| `audit-framework/rulepacks/secguardian/rules/*.md` (17 个重复规则) | 删除，仅 `knowledge/audit-rules/*.md` 一份规则 |
| `audit-framework/rulepacks/secguardian/pack.json` (规则索引清单) | 删除，rules 无 pack 索引（future: 可在 knowledge/ 下重建） |
| `audit-framework/rulepacks/README.md` (如何编写 Rule Pack) | 删除，Rule Pack 概念不再属于 audit-framework |
| `audit-framework/README.md` (框架 + rulepack 混合描述) | 重写为 Audit Execution Framework 纯定位 |
| 框架设计文档 (architecture/workflow/evidence/report-schema) | 新增 4 个设计文档 |
| `audit-framework/engine/README.md` (引用 rulepacks 路径) | 更新指向 `knowledge/audit-rules/` |
| `commands/secaudit.md` (引用 audit-framework/rulepacks/) | 更新路径指向 `knowledge/audit-rules/` |

### What stayed

| 文件 | 说明 |
|------|------|
| `audit-framework/templates/README.md` | 报告模板设计文档，无规则知识 |
| `audit-framework/reporters/README.md` | 输出格式扩展点，无规则知识 |
| `knowledge/audit-rules/*.md` | 唯一规则源，未修改 |
| `skills/secaudit/*/SKILL.md` | AI Workflow，未修改 |

### What was kept open

- `knowledge/audit-rules/pack.json`（future: 可以在 knowledge/ 下增加规则索引，本次不做）
- Rule Pack 作为概念并未消亡——但属于框架设计文档，而非规则集合

## Rationale

四个模块在重构后的职责边界：

| 模块 | 职责 | 拥有什么 |
|------|------|---------|
| `commands/` | 用户入口（Entry Point） | CLI 定义、参数解析 |
| `skills/` | AI Workflow | Prompt、推理流程、context gathering |
| `knowledge/` | 安全知识库（唯一知识源） | Rules、Standards、Protocols、Threat Catalog |
| `audit-framework/` | 审计执行框架 | 架构设计、工作流描述、报告模式 |

关系：

```
knowledge/  (Security Knowledge Repository — 唯一知识源)
    ▲
    │  消费
audit-framework/  (Audit Execution Framework — 如何审计)
    ▲
    │  执行
skills/  (AI Workflow — AI 如何思考)
    ▲
    │  调度
commands/  (Entry Point — 用户入口)
```

## Impact

- **知识去重**：17 个规则文件的唯一副本在 `knowledge/audit-rules/`，不再交叉维护
- **框架净化**：`audit-framework/` 从 ~1.2MB（含规则）降为 ~30KB（纯框架设计文档）
- **未来扩展**：新增企业安全规范（OWASP ASVS、PCI DSS 等）只需在 `knowledge/` 下加规则，不涉及框架变更
- **向后兼容**：`commands/secaudit.md` 中的路径引用已更新，skill 加载路径不受影响

### 追加变更 (2026-07-02 22:00)

| 修改项 | 变更 |
|--------|------|
| `audit-framework/` 目录本身 | **从根级移至 `docs/audit-framework/`** — 框架设计文档不属于根级目录 |
| `commands/secaudit.md` 中的 `--rulepack` 参数 | **移除** — 入口统一为 `secaudit <path> <lang>`，与 `/secguard`、`/secreview` 一致 |
| `commands/secaudit.md` Step 3 | **简化** — 移除 rulepack 加载步骤，改为加载 `knowledge/audit-rules/` |
| `README.md`（根级） | **更新** — 移除 `--rulepack` 示例和 `rulepacks/` 目录树 |
