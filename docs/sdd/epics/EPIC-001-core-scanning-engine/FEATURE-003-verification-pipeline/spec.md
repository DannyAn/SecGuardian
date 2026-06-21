# Verification Pipeline — 三轮验证消减系统

> **Feature**: FEATURE-003-verification-pipeline
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: 📋 Spec (v2 — 基于端到端数据反推修正)
> **日期**: 2026-06-17
> **作者**: JonyAn + Claude Opus 4.8
> **范围**: AI Agent 扫描层 — 三轮验证协议 + 渲染器增强

**目标**: 在 Detector 产出 Finding 后插入三轮独立验证——每轮有 Detector 做不到的增量价值——最大化降低误报。保持 Detector 现有分析深度不变，不丢弃已有高质量数据。

---

## 1. 背景与动机

### 1.1 当前痛点

生产环境一次扫描产生 74 条告警（28 High + 46 Medium），用户看到后直接崩溃：

```
✅ secguard 安全扫描已完成

扫描文件    294
检测器      19/19 完成
总问题      74
Critical    0
High        28
Medium      46
```

问题根因：**Detector 产出 Finding 后直接推给用户，无独立验证环节**。74 条 Finding 的 `confidence` 全部是 `"high"`——AI 从未被 challenge，自己判自己永远是满分。

### 1.2 端到端数据反推（2026-06-17 实测）

对 python-vuln-demo 的 3 文件/295 行扫描，产出 17 条 Finding，实测发现：

- **Detector 产出质量不低**: 每条 Finding 已含 `data_flow_path`（source→propagation→sink）、`judgment_rationale`（CWE 映射推理）、`cvss_score`+`cvss_vector`（CVSS 3.1）、`before_code`+`after_code`（具体修复代码）。这不是"浅层模式匹配"。
- **`confidence` 全部是 `high`**: 17/17 条无区分度——AI 从未被 challenge。
- **索引器数据量极小**: 3 文件项目 index.json 仅 2.5KB，call_graph 仅 1 条边。AI Agent 主要靠读源码做分析。
- **P1/P2 冗余**: 原五轮设计的 P1 (Fact Certification) 和 P2 (Flow Certification) 与 Detector 已完成的 `data_flow_path` 和 `judgment_rationale` 高度重叠（80-100%）。

**结论**: 减为三轮——每轮必须是 Detector 做不到的增量分析。

### 1.3 业界对标

| 系统 | 核心技术 | 效果 |
|------|---------|------|
| **ZeroFalse** (Iranmanesh 2025, arXiv:2510.02534) | 证据门禁 + LLM 裁决 | F1=0.912-0.955 |
| **CodeX-Verify** (2025, arXiv:2511.16708) | 4 Agent 并行验证，数学证明多 Agent 优于单 Agent | 72.4% vs 32.8% |
| **Hybrid SAST+LLM** (Agrawal 2025) | Semgrep → Llama 3 两阶段过滤 | 91% FP 消减 |
| **CodeQL** (GitHub) | `@precision` 静态精度分级 | 34% FP rate |

---

## 2. 设计目标

| 目标 | 度量标准 | 当前基线 | 目标值 |
|------|---------|---------|--------|
| 告警收敛率 | (初始Finding - 最终Certified) / 初始Finding | 0% | ≥50% |
| 验证可追溯性 | 每个 Finding 是否可追溯到每轮判定 | 无 | 100% |
| 被抑制告警审计 | 被抑制的 Finding 是否有明确原因 | 无 | 100% dismissed.json |
| 与现有架构兼容 | 是否破坏 index.json / detector / renderer | — | 零破坏 |
| Detector 分析深度 | 是否丢弃现有高质量数据 | — | 零丢弃 |

---

## 3. 需求规格

### REQ-001: Detector 输出保持不变

**优先级**: P0 (约束)

Detector 继续产出完整 Finding（含 severity + CWE + evidence + fix）。不降级为轻量 Claim。现有 67 个 detector 的检测逻辑和输出格式**零变更**。

**理由**: 端到端实测证实 Detector 产出已含 data_flow_path、judgment_rationale、CVSS 评分——这些是后续验证轮的输入资产，不应丢弃。

**验证标准**: `knowledge/guard-rules/*.md` 零改动。

### REQ-002: 三轮验证管道

**优先级**: P0

在 Detector 扫描和渲染器之间，插入三轮独立验证：

```
P1: Semantic Verification → 检查项目安全框架是否已天然消除风险
P2: Counter-Evidence Hunt → 主动搜索证明漏洞不成立的证据
P3: Adjudication Court   → 三方 Agent 合议最终裁决
```

每轮有 Detector 做不到的增量价值：

| 轮次 | Detector 为什么做不到 |
|------|---------------------|
| P1 Semantic | Detector 只分析单文件单函数，不做跨文件安全框架扫描 |
| P2 Counter-Evidence | Detector 是"找漏洞"的，不会主动找"证明安全"的证据 |
| P3 Court | Detector 是"检察官"，没有独立裁决者 |

**验证标准**: 每轮有独立 prompt 模板，每轮产出结构化 verdict + reason。

### REQ-003: 证据门禁机制

**优先级**: P0

每轮 Agent prompt 严格限制推理范围为指定的代码片段和 index.json 数据。P3 Judge 禁止访问源码——只能基于 Court Record 裁决。

**验证标准**: 所有 prompt 模板包含显式的"你只能使用以下数据"约束块。

### REQ-004: 裁决法庭

**优先级**: P1

P3 实现三方 Agent 合议：
- **Prosecutor**: 基于 P1-P2 的 Court Record + 原始 Finding，论证漏洞成立
- **Defender**: 基于同一 Court Record，论证漏洞不成立
- **Judge**: 禁止访问源码，仅基于 Court Record + 双方论证，做出最终裁决

**验证标准**: Judge 的裁决理由可被人类审计。

### REQ-005: 审计追踪

**优先级**: P1

新增输出文件：
- `dismissed.json` — 被抑制的 Finding + 抑制原因 + 抑制轮次
- `verification-audit.json` — 完整验证链 + 每轮收敛统计

**验证标准**: 任何被抑制的 Finding 可在 10 秒内定位到"哪一轮、什么原因"。

### REQ-006: 渲染器增强

**优先级**: P2

- `report.md` 增加"验证漏斗"章节
- `summary.json` 增加 `findings_total`, `dismissed_by_round` 字段
- `status.json` CI 门禁增加 confidence 加权选项

### REQ-007: index.json 保持不变

**优先级**: P0 (约束)

`internal/` 目录零改动。

---

## 4. 设计方案

### 4.1 核心架构变更

```
当前架构:
  Tree-sitter Indexer → Detector → Finding[] → Renderer → 用户

新架构:
  Tree-sitter Indexer → Detector → Finding[] (74 条, 保持现有质量)
                                       ↓
                              ┌─ P1: Semantic Verification ─┐
                              │   (框架已消除 → 抑制)        │
                              │       ↓                     │
                              │  P2: Counter-Evidence Hunt ─┤
                              │   (有反证 → 抑制)            │
                              │       ↓                     │
                              │  P3: Adjudication Court ────┘
                              │   (三方合议 → 最终裁决)
                              └─────────┬───────────────────┘
                                        ↓
                              Certified Finding[] + Dismissed[]
                                        ↓
                              Renderer → 用户
```

### 4.2 Detector 输出 — 保持不变

Detector 继续输出当前格式的 Finding（含四段式 + sarif_specific）。这是验证管道的输入，不降级、不丢弃。

对于验证管道，每个 Finding 贡献：
- `data_flow_path` → P2 Counter-Evidence 的搜索起点
- `evidence.code_context` → Court Record 的代码事实
- `sarif_specific.confidence` → 作为 `confidence_initial`，与 P3 `confidence_certified` 对比

### 4.3 每轮验证详设

#### P1: Semantic Verification（语义验证）

**职责**: Detector 只分析单文件单函数——它不知道项目有个 `SafeCopy` 包装类已经保证了 bounds check。P1 构建项目的**安全语义画像**，找出 Detector 视野之外的保护层。

**为什么 Detector 做不到**: Detector 加载的是单个检测器 Markdown + 目标代码片段。它没有跨文件扫描项目所有 types/functions 去构建安全框架视图。P1 利用 index.json 的全局符号表做这件事。

**数据来源**: index.json `types` + `functions`（全局视图）+ 对应函数源码。

**动态构建 Project Security Profile**:
1. 扫描所有 types，识别安全包装命名模式（SafeXxx, XxxGuard, XxxWrapper, ValidatedXxx）
2. 扫描所有 functions，识别安全工厂/校验方法（CreateSafeXxx, ValidateXxx, SanitizeXxx）
3. 对每个候选安全类型/方法，阅读其源码确定语义保证

**裁决逻辑**:
- `no_exemption`: 项目安全框架未覆盖此风险
- `exempted`: 项目安全框架已消除此风险 → Finding 抑制
- `uncertain`: 安全包装存在但不完全覆盖 → 保留，标记 `r1_flag`

#### P2: Counter-Evidence Hunt（反证搜寻）

**职责**: Detector 是"找漏洞"的——它在找证据证明代码有问题。P2 反过来——主动搜索代码中证明漏洞**不成立**的证据。这是 Detector 的盲区。

**为什么 Detector 做不到**: Detector 的 prompt 结构是"找 X 模式的漏洞"，不是"找证明这段代码安全的证据"。认知方向相反。

**数据来源**: index.json `lock_graph` + `alloc_free` + Finding 的 `data_flow_path`。

**按 Finding 类型定制的搜索清单**:

| Finding 类型 | 搜索的反证 |
|-------------|-----------|
| 内存安全 | RAII 包装、unique_ptr/shared_ptr、显式 bounds check、上层 size validation |
| 注入 | Prepared Statement、输入转义、白名单校验、ORM 框架 |
| 并发 | lock_guard/scoped_lock、std::atomic、happens-before 同步原语 |
| 加密 | 高层加密库封装 (libsodium, Fernet)、KMS 密钥管理 |

**裁决逻辑**:
- `counter_evidence_found`: 找到明确反证 → Finding 抑制
- `counter_evidence_not_found`: 未找到 → Finding 保留

#### P3: Adjudication Court（裁决法庭）

**职责**: 独立裁决。Detector 是检察官（举证有漏洞），P2 Defense Agent 是辩护律师（举证安全），P3 Judge 是法官（基于双方证据裁决）。

**Court Record 结构**:

```json
{
  "finding_id": "H-SQLI-webapp-L47",
  "finding_summary": {
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "title": "SQL injection via f-string query construction",
    "data_flow_path": ["request.args.get('username') → f-string → cursor.execute(query)"],
    "detector_confidence": "high"
  },
  "r1_semantic": {
    "verdict": "no_exemption",
    "reason": "Project has no ORM, no PreparedStatement wrapper, no query builder"
  },
  "r2_counter": {
    "verdict": "counter_evidence_not_found",
    "search_summary": "No parameterized query, no input escaping, no whitelist validation found in or near get_user()"
  }
}
```

**Prosecutor + Defender 并行发言** — 两个 Agent 基于同一 Court Record，不允许访问源码。

**Judge 裁决标准**:
- `confirmed`: 两轮验证未发现问题 + Prosecutor 论证有力 + Defender 无法有效反驳
- `suspected`: 验证链有薄弱环节 → 需人工确认
- `dismissed`: P1 或 P2 发现问题，或 Defender 提供了决定性反证

**Judge 约束**: 禁止访问源码。仅基于 Court Record + 双方陈述裁决。

### 4.4 收敛预期

基于业界的收敛比例估算，结合当前 Detector 质量（`precision: high/very-high`）：

```
74 条 Finding (初始, Detector 直接输出)
  → P1 Semantic:  ~52 条 (剔除 ~22 条框架已消除)
  → P2 Counter:   ~35 条 (剔除 ~17 条有反证)
  → P3 Court:     ~25-30 条 Certified Finding
     ├── confirmed:  ~18 条 (需要关注的)
     └── suspected:  ~10 条 (需人工确认)
```

### 4.5 集成方式

三轮验证作为 `/secguard` 命令的新增 Step 3.5：

```
Step 1: secguardian-index --health
Step 2: secguardian-index --path ./src --output index.json
Step 3: Detector 扫描 → 输出 findings.json + findings/ (不变)
Step 3.5: ★ 三轮验证管道 → 输出 dismissed.json + verification-audit.json
Step 4: render-report.py --findings-dir findings/ (适配新输出)
```

### 4.6 输出文件变更

| 文件 | v5.0 (当前) | v6.0 (三轮验证后) | 变更 |
|------|-----------|-------------------|------|
| `findings.json` | AI 产出 74 条 Finding | 不变 — Detector 输出格式零变更 | 无 |
| `findings/` | 按 detector 分类的 Finding 文件 | 不变 | 无 |
| `dismissed.json` | 不存在 | 新增 — 被抑制的 Finding + 原因 + 轮次 | 新增 |
| `verification-audit.json` | 不存在 | 新增 — 完整验证链 + 每轮统计 | 新增 |
| `report.md` | 展示 74 条告警 | 增加"验证漏斗"章节 | 增强 |
| `results.sarif` | `properties.confidence` | 增加 `suppressions` 节点 | 增强 |
| `summary.json` | 当前统计 | 增加 `findings_total`, `dismissed_by_round` | 增强 |

---

## 5. 风险与约束

### 5.1 已知限制

| 限制 | 影响 | 缓解措施 |
|------|------|---------|
| **无 CFG/SSA** | P2 Counter-Evidence 的数据流路径验证依赖 AI 推理 | Court Record 包含 Detector 的 data_flow_path + P2 的搜索结果，Jude 可交叉验证 |
| **JS 无 Tree-sitter** | JavaScript 项目缺少 AST 级符号表 | P1 Semantic 的 types 扫描降级为正则解析器输出 |
| **跨平台 regex 回退** | 非 darwin-arm64 符号表精度降低 | AI Agent 在 P1 中直接读源码补偿 |
| **Token 消耗** | 74 条 Finding × 3 轮验证 = ~220+ AI 调用 | 每轮只读必要代码片段；P3 Court 不访问源码 |

### 5.2 不做什么 (Non-Goals)

- ❌ 不改变 Detector 输出格式（REQ-001）
- ❌ 不在索引器中添加 CFG/SSA
- ❌ 不改变 index.json 数据结构（REQ-007）
- ❌ 不改变 MUST/SHOULD/MAY 证据体系
- ❌ 不引入 SMT Solver

### 5.3 五轮→三轮修正记录

原设计为五轮（P1 Fact → P2 Flow → P3 Semantic → P4 Counter-Evidence → P5 Court），经端到端实测数据反推后修正为三轮：

| 砍掉的轮次 | 原因 |
|-----------|------|
| P1 Fact Certification | Detector 的 `judgment_rationale` 已确认代码事实存在；80-100% 重叠 |
| P2 Flow Certification | Detector 的 `data_flow_path` 已追踪 source→sink；100% 重叠 |

保留的三轮每轮都有 Detector 做不到的增量价值。

---

## 6. 参考来源

| 来源 | 借鉴要点 |
|------|---------|
| **ZeroFalse** (Iranmanesh et al., 2025, arXiv:2510.02534) | 证据门禁 prompt 设计、Confidence 校准 |
| **CodeX-Verify** (2025, arXiv:2511.16708) | 多 Agent 专业化分工、互信息子模性证明 |
| **ECVA** (Architecture Baseline v1.0, 2026) | Evidence-Centric 哲学、Adjudication Court 设计 |
| **FEATURE-002-detector-quality** (SecGuardian) | MUST/SHOULD/MAY 证据体系、precision + confidence 双元数据 |
| **端到端实测** (python-vuln-demo, 2026-06-17) | Detector 分析深度确认、P1/P2 冗余判定、3 轮修正决策 |
