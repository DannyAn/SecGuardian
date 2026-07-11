# SecGuardian 能力栈索引（Capability Stacks）

> **目的**：逐命令记录每个产品已建成的"超越 SAST"能力栈，作为活索引累积。每完成一个命令的能力栈，在此追加一节。
>
> **伴生文档**：[`Root-Technology-Report.md`](Root-Technology-Report.md)（根技术总览 + 他司对比）、[`sdd/epics/EPIC-011-enforcement-integrity/`](sdd/epics/EPIC-011-enforcement-integrity/)（设计四环）。
>
> **维护规则**：能力栈每落地一项，更新对应命令节的状态（✅/🔄/🔲）+ 证据。新命令能力栈建起时追加新节。

---

## 状态总览

| 命令 | 能力栈状态 | 核心 |
|------|-----------|------|
| `/secguard` | ✅ **已成型** | Tree-sitter+CFG+DFG污点 + per-rule隔离 + 引擎强制 + oracle |
| `/secaudit` | 🔲 待建（扁平 rule，待对齐 secguard 文件夹模型 + 隔离调度）| — |
| `/secreview` | 🔲 待建 | — |
| `/secfix` | 🔲 待建 | — |

---

## `/secguard` — 安全加固检视（能力栈已成型）

> **建成日期**：2026-07-10（EPIC-011）· **平台**：Claude Code / OpenCode / Gemini CLI 三平台一致

```
Tree-sitter CST（打败 AST：鲁棒解析 + 统一多语言 + 全位置）
  ↓
CFG（per-function 控制流图 + IsReachable + Dominates 支配树）
  + DFG/污点（S12 TaintFlow：Source→Sink，intra-procedural v1）
  ↓
信号矩阵 S1-S12
  S1 CallSites / S2 StringLiterals / S3 Declarations / S4 ValueConstants
  S5 Imports / S6 ConfigPatterns / S7 ControlFlow / S8 PointerValidations
  S9 StructInits / S10 VariableWrites
  S11 SuspiciousExpression（assignment_in_condition / operator_precedence /
     signed_unsigned_compare / suspicious_boolean）
  S12 TaintFlow（Source→Sink 污点传播）
  + Prescreener（确定性 safe-variant 过滤，降噪）
  ↓
per-rule 隔离调度（ADR-006：partition-signals.py 引擎预过滤 + 有界 batch +
  统一串行内联，三平台一致；Claude 可选 Agent 隔离增强）
  ↓
Investigation Pipeline（Hypothesis → Investigator → Counter Evidence →
  Judge+Q-matrix → Record，三平台恢复，单一真理源 dispatch-protocol.md）
  ↓
引擎强制（record-finding anchor + verification-gate 签名 + coverage-gate
  反 batch-suppression + render-report confirmed-才计入-CI）
  ↓
验证（verify-recall oracle：recall/precision 可度量）
```

### 已建成能力（✅ 可复现证据）
| 能力 | 证据 | 复现 |
|------|------|------|
| Tree-sitter 真解析 5 语言 | 索引器 | `secguardian-index --path examples/cpp-vuln-demo/src --lang c` |
| CFG + 支配查询 | 4 单测 + 110 CFGs 实测 | `go test -tags cgo -run TestCFG ./parser/` |
| DFG/污点 Source→Sink | 4 单测 + cpp-vuln-demo 10 真实流 | 索引 cpp-vuln-demo 看 `taint_flows` |
| S3 Declarations + prescreener | SafeCount 0→8 | 索引输出 "Prescreener: 8 safe filtered" |
| S11 语义模式（4 类） | 4 单测 | `go test -tags cgo -run TestS11 ./parser/` |
| per-rule 隔离调度 | partition self-test + 16 rules/21 batches | `partition-signals.py --self-test` |
| 三平台 pipeline 一致 | Step4/partition/协议引用/coverage-gate 各 1 | self-check §14 |
| 调度模式自适应 | ≤8 batch 串行内联，>8 Agent 可选 | CHANGE-003 |
| CI 门禁真退出 | e2e §6 断言进程 exit 1 | `bash scripts/e2e-verify.sh` |
| coverage-gate 反 batch-suppression | e2e §15 BLOCKED | `coverage-gate.py --self-test` |
| verification-gate 反旁路 | e2e §16 bad-anchor 排除 | `verification-gate.py --self-test` |
| oracle recall/precision | e2e §14 | `verify-recall.py --self-test` |

### 诚实待补（🔄/🔲）
- 🔄 inter-procedural 污点 / 路径敏感 / 别名（M2 增量，跨函数 Source→Sink）
- 🔲 F7 Q-matrix 极性修复 + 60 规则全覆盖（FEATURE-003，让 verification-gate Q-matrix 真校验）
- 🔲 ground truth 补全（oracle precision 可信）
- 🔲 F5 zig cc 跨平台 tree-sitter 唯一解析器
- 🔲 JS tree-sitter（当前正则）

---

## `/secaudit` — 发布安全审计（能力栈待建）

> **当前状态**：扁平 rule（一 .md 捆一域），全 rule 一锅端喂 LLM（ADR-006 关切 #2）。**待对齐 secguard 文件夹模型 + per-rule 隔离调度 + 引擎强制**。

🔲 待建能力栈（规划对齐 secguard）：
- [ ] rule 结构迁移：扁平 `rules/{domain}.md` → 文件夹 `rules/{detector}/rule.md`（自包含 + signal_source）
- [ ] 引擎预过滤 + per-rule 隔离调度（复用 partition-signals.py + dispatch-protocol.md）
- [ ] 引擎强制接入（coverage-gate / verification-gate / oracle）
- [ ] 13 审计域（OWASP ASVS）能力栈文档化

---

## `/secreview` — PR 安全审查（能力栈待建）

🔲 待建：
- [ ] diff 范围索引（F11：diff_parser 接入 CLI，当前全量）
- [ ] 5 语言 review 规则能力栈
- [ ] per-rule 隔离 + 引擎强制

---

## `/secfix` — 修复（能力栈待建）

🔲 待建：
- [ ] findings → unified diff patch 生成能力栈
