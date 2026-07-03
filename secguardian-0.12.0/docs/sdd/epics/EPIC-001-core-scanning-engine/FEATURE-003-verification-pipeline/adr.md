# ADR — Verification Pipeline Architecture Decisions

> **Feature**: FEATURE-003-verification-pipeline
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: Detector 输出保持不变

**日期**: 2026-06-17
**状态**: ✅ Accepted (v2 修正)

### Decision

Detector 继续产出完整 Finding（含 severity + CWE + evidence + fix）。不降级为轻量 Claim。

### Reason

- **端到端实测证据**: python-vuln-demo 的 17 条 Finding 已含 `data_flow_path`（source→propagation→sink）、`judgment_rationale`、`cvss_score`+`cvss_vector`、`before_code`+`after_code`。这是 Detector 已完成的高质量分析，不应丢弃。
- **原 Claim 设计的错误假设**: 假设 Detector 产出的是"浅层模式匹配"——实测证明并非如此。Detector 已经做了从代码读取→语义分析→CWE 映射→CVSS 评分→修复代码生成的完整推理链。
- **67 个 detector 零变更**: 保持向后兼容，降低实施风险。
- **ECVA 原则 1 的务实解读**: "Detector cannot emit Findings" 在 ECVA 参考架构的语境下是指传统 SAST 的模式匹配输出。SecGuardian 的 Detector 是 AI Agent，它产出的 Finding 已经包含深度证据——这不是传统 SAST 的裸 pattern match。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **降级为 Claim** | 丢弃 data_flow_path、CVSS 评分、修复代码等已有分析资产；67 个 detector 需全部修改输出格式 |
| **Finding + Claim 双输出** | 增加复杂度，两套结构需维护一致性 |

### Consequences

- `knowledge/guard-rules/*.md` 零改动
- `knowledge/protocols/findings-schema.json` 无需新增 Claim schema
- 验证管道直接消费现有 Finding 结构

---

## ADR-002: 三轮顺序验证管道

**日期**: 2026-06-17
**状态**: ✅ Accepted (v2 修正 — 原 5 轮减为 3 轮)

### Decision

验证管道为三轮顺序执行：P1 Semantic Verification → P2 Counter-Evidence Hunt → P3 Adjudication Court。

### Reason

- **端到端实测发现 P1/P2 冗余**: 原设计的 P1 (Fact Certification) 与 Detector 的 `judgment_rationale` 80% 重叠；原 P2 (Flow Certification) 与 Detector 的 `data_flow_path` 100% 重叠。这两轮不提供增量价值。
- **保留的三轮每轮都有 Detector 做不到的事**:
  - P1 Semantic: Detector 分析单文件单函数，不做跨文件安全框架扫描
  - P2 Counter-Evidence: Detector 是"找漏洞"，不会主动找"证明安全"的证据
  - P3 Court: Detector 是"检察官"，没有独立裁决者
- **Token 经济性**: 5 轮 370+ AI 调用 → 3 轮 ~220+ AI 调用，减少约 40%

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **原 5 轮设计** | P1 Fact/P2 Flow 与 Detector 已有分析重叠 80-100%，冗余 |
| **2 轮设计 (Semantic + Court)** | Counter-Evidence Hunt 是 ECVA Phase 5 的独立价值——主动找反证 vs 被动验证 |
| **并行三轮** | P2 的搜索清单依赖 P1 的 Security Profile 结论；P3 依赖 P1+P2 的完整 Court Record |

### Consequences

- 3 个 prompt 模板（原 5 个），维护成本更低
- P1 Semantic 的 Security Profile 是全局构建一次、所有 Finding 复用，不按 Finding 数线性放大
- P3 Court 不访问源码，token 消耗远低于 P1/P2

---

## ADR-003: Judge 禁止访问源码

**日期**: 2026-06-17
**状态**: ✅ Accepted

### Decision

P3 Adjudication Court 的 Judge Agent 禁止访问源代码。Judge 只能基于 Court Record（Finding 摘要 + P1 + P2 verdict）、Prosecutor Statement 和 Defender Statement 做出裁决。

Prosecutor 和 Defender 也只能基于 Court Record 论证，不允许访问源码。

### Reason

- **ECVA 原则**: "Judge Agent 禁止访问源码。仅允许访问 Fact Graph + Flow Graph + Semantic Result."
- **防止偏见**: Judge 如果能看到源码，就会形成自己的独立判断，不再依赖证据链
- **可审计性**: Judge 的裁决理由中引用的每条事实必须能追溯到 Court Record 中的具体条目
- **Token 效率**: P3 完全不加载源代码文件

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **Judge 可以访问源码以验证可疑点** | 破坏证据门禁；Judge 形成独立判断可能与 P1-P2 结论冲突 |
| **三方都能访问源码，独立判断后投票** | 三个 Agent 可能得出三种不同的事实认定——"噪音"而非"验证" |

### Consequences

- Court Record 的信息密度必须足够高（P1 的 semantic 结论 + P2 的搜索摘要 + 原始 Finding 摘要）
- P3 执行完全不需要加载源代码，token 消耗最低

---

## ADR-004: index.json 保持不变

**日期**: 2026-06-17
**状态**: ✅ Accepted

### Decision

不扩展 `internal/` Go 索引器。当前 index.json (symbols + call_graph + alloc_free + lock_graph) 已提供三轮验证所需的全部导航数据。

### Reason

- **量化分析**: 3 文件项目 index.json 仅 2.5KB。对于 294 文件项目约 400-600KB——足够作为导航地图。
- **AI Agent 直接读源码**: Detector 的高质量产出证明了 AI Agent 主要靠读源码而非依赖 index.json。P1/P2 同理。
- **避免过度工程化**: 构建完整 Fact Graph 需要 3.5x 数据膨胀，但新增的标注信息 AI Agent 可通过读源码自行推断。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **在 Go 索引器中构建完整 Fact Graph** | 3.5x 数据膨胀，source/sink/sanitizer 标注可能与 AI 判断冲突 |
| **新增 Python 预处理脚本** | 引入新依赖，维护负担 |

### Consequences

- `internal/` 目录零改动
- P1 的 Security Profile 构建由 AI Agent 完成（依赖 index.json types + functions 做导航）
