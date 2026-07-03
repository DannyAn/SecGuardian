# ADR — Detector Quality Architecture Decisions

> **Feature**: FEATURE-002-detector-quality
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: 统一检测器模板（precision + confidence 双元数据）

**日期**: 2026-06-11
**状态**: ✅ Accepted

### Decision

每个 detector 文件统一为 7 章节模板，新增两个元数据字段：

| 字段 | 类型 | 含义 |
|------|------|------|
| `precision` | `very-high`/`high`/`medium`/`low` | 检测器真阳性率（静态，基于检测模式特化程度） |
| `confidence` | `dynamic` | AI 扫描时根据证据完整度动态判定（不由人赋值） |

### Reason

- **CodeQL** 的 `@precision` 是静态属性，由 GitHub 员工手动赋值 → 我们借鉴但新增 dynamic confidence
- **Semgrep** 的 `confidence` 是规则级静态字段 → 我们将其设为 `dynamic`，让 AI 每次扫描实时计算
- **无竞品**在检测器文档中嵌入"证据收集指引"章节 → AI Agent 原生 SAST 的独特优势

### Rejected Alternatives

- **复用 CodeQL 的 precision 定义**：CodeQL 只有 precision 没有 confidence，无法表达"同一条规则在不同代码上下文中的把握度差异"
- **confidence 设为静态值**：失去了 AI Agent 动态评估的核心差异化能力

### Consequences

- precision 决定证据收集的最低门槛（very-high 需要 ≥3 MUST 项，low 只需 ≥1）
- confidence 由 AI 在每次扫描中根据证据实际收集情况动态计算
- 67 个 detector 全部需要添加 frontmatter 元数据

---

## ADR-002: MUST/SHOULD/MAY 三级证据体系

**日期**: 2026-06-11
**状态**: ✅ Accepted

### Decision

证据收集分三级，对标 SARIF `threadFlowLocation.importance`：

| 级别 | 语义 | SARIF 对标 | 缺失后果 |
|------|------|-----------|---------|
| **MUST** | 没有这项证据，finding 不成立 | `essential` | 不报告 |
| **SHOULD** | 增强可复现性和审计追溯 | `important` | 降 confidence 一级 |
| **MAY** | 深度取证，高严重度建议 | `attachments` | 不影响 confidence |

### Reason

- 借鉴 **ZEROFalse** (北大, 2025) 的"证据门控推理"：无充分证据 → 不报告
- 解决当前 67 个检测器"无一包含证据收集指引"的系统性空白
- 分级体系让 AI Agent 知道什么证据是底线、什么是加分项

### Rejected Alternatives

- **只有 MUST/OPTIONAL 两级**：不够细，"建议收集"和"完全可选"应该区分
- **四级体系（MUST/SHOULD/MAY/NICE_TO_HAVE）**：过度设计，MAY 已覆盖 NICE_TO_HAVE

### Consequences

- `findings-schema.json` 需新增 `call_stack`、`variable_state`、`sanitizer_analysis` 三个 evidence 子字段
- 每个 detector 的证据收集指引章节需按三级组织
