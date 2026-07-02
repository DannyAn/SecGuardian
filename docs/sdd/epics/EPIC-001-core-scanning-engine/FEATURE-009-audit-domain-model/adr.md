# Architecture Decision Records — FEATURE-009

> **Feature**: FEATURE-009 SecAudit Domain Model

---

## ADR-001: 分析方法降级为 AI 内部推理能力

**日期**: 2026-07-02
**状态**: ✅ Accepted

### Context

Taint Analysis、Attack Surface、Data Flow、Trust Boundary、State Machine 当前作为独立的 skill 和 rule 暴露给用户。用户需要理解这些分析方法才能使用 SecAudit。

### Decision

将这些分析方法从用户入口降级为 AI 内部推理能力：

- 从 skills/secaudit/ 中删除对应 skill 目录
- 从 knowledge/audit-rules/ 中删除对应 rule 文件
- workflow-secaudit 在执行时根据审计领域自动选择推理策略

### Consequences

- 用户只需理解安全领域（Authentication、Cryptography 等），无需理解分析方法
- AI 内部可以自由增加、替换、优化分析方法（Symbolic Execution、CPG、Graph Reasoning），不影响产品接口
- 丢失了用户手动指定分析方法的灵活性，但降低了认知负担

---

## ADR-002: Skills 收敛为单一 AI Workflow

**日期**: 2026-07-02
**状态**: ✅ Accepted

### Context

当前 skills/secaudit/ 下有 18 个 skill 目录：1 workflow + 5 分析方法 + 12 领域。每个 skill 都需要维护 SKILL.md，且大多数内容重复（"加载 xxx.md → 分析 → 输出"）。

### Decision

SecAudit 的 skills 仅保留 workflow-secaudit。所有的审计域检测由 workflow 自动调度执行：

- 删除 15 个独立 skill 目录（5 分析方法 + 12 领域）
- workflow-secaudit/SKILL.md 承担所有入口职责
- 知识加载路径从 `skills/secaudit/{domain}/SKILL.md` 改为从 `knowledge/audit-rules/{domain}.md` 直接加载

### Consequences

- 技能数量从 28 降为 13（secaudit: 1, secguard: 5, secreview: 5 + 2 通用）
- 维护成本显著降低
- workflow-secaudit 需要知道如何映射 domain 到对应知识文件

---

## ADR-003: knowledge/audit-rules/ 保持 13 个 Domain 文件

**日期**: 2026-07-02
**状态**: ✅ Accepted

### Context

删除 5 个分析方法文件后 knowledge/audit-rules/ 剩下 12 个 domain 文件。用户明确列出了 12 个域，其中 Information Exposure 无对应文件。

### Decision

- 保留全部 12 个现有 domain 文件（含 http-security-headers.md）
- 新增 information-exposure.md 补齐用户列出的域
- 最终 13 个 domain 文件

否决的方案：

| 方案 | 否决原因 |
|------|---------|
| 删除 http-security-headers.md | 已有内容和引用，删除破坏向后兼容 |
| 不新增 information-exposure.md | 用户明确列出，缺失影响领域模型完整性 |

### Consequences

- knowledge/audit-rules/ 文件数从 17 调整为 13（-5 +1）
- manifest.json 和相关计数需要更新
- 无向后兼容问题（skill 目录删除不影响已部署的扫描结果）
SPEC_EOF
echo "Created adr.md"