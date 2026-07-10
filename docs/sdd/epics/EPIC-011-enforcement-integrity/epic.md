# EPIC-011: Enforcement Integrity — 从 Paper Compliance 到 Structural Enforcement

> **Status**: Inception（FEATURE-001 设计四环就绪，待评审）
> **创建**: 2026-07-10
> **来源**: 2026-07-10 深度架构 + 逻辑检视（5 个对抗性 agent + 抽检验证）
> **前任上下文**: EPIC-009（prescreener，检出为死代码）、EPIC-010（Investigation Engine，仍 Inception）

---

## 1. 北极星

> 我们不是 SAST，但要能检查出 SAST 能检查出的所有问题，同时利用 LLM 的优势解决 SAST 做不到的问题——我们是超越 SAST 的顶尖解决方案供应商。**AI 辅助下的超越 SAST，不是纯 SAST。**

两根不可拆分的支柱，且都必须**可结构证明**，而非叙事声称：

1. **SAST recall 对等** — SAST 能检的全部必须能检（召回基线，不能因 LLM 偷懒/批处理抑制而漏检）。**引擎保证 recall 下限，LLM 不可抑制已发现的结构信号。**
2. **LLM 语义差异化** — 利用 LLM 做 SAST 做不到的语义/上下文/跨函数推理检测。**LLM 在引擎提供的 CFG/可达性事实之上做语义判断，而非空想。**

EPIC-011 的全部意义：让这两根支柱从"声称"变成"可被引擎与数据证明"。

### 架构愿景（2026-07-10 升级）

```
源码
  ↓
Tree-sitter 纯 Go CST（打败 AST：鲁棒解析 + 统一多语言 + 全位置）
  ↓
引擎层：Symbols + CFG + Alloc/Free + Lock + Signals   ← 结构化 recall 基线（Pillar 0）
  ↓                                          ↘
AI Investigator（语义差异化，超越 SAST）        Enforcement Gate（Pillar A：结构校验）
  ↓                                          ↙
Findings → Verification Oracle（Pillar B：ground-truth recall/precision）
```

三根支柱：
- **Pillar 0（引擎 recall 基线）**：Tree-sitter 纯 Go 主干 + CFG 构建。引擎找到的结构信号是 recall 下限，LLM 不可抑制。
- **Pillar A（强制层）**：语义不变量下沉到编译 chokepoint，LLM 不可绕过。
- **Pillar B（验证回路）**：ground-truth oracle 闭合反馈，让"超越 SAST"可证明。

**"打败 AST"的真正含义**：当前 CGO/正则双解析器里的正则回退是"比 AST 更差"的近似——它恰恰背离了"Tree-sitter 打败 AST"的初衷。真正实现该目标的是迁移到**纯 Go Tree-sitter**（go-tree-sitter v0.23+ 已无 CGO，5 语言语法库均纯 Go），一举消灭双解析器非等价（F5）根因，全平台同一行为，且 CFG 构建不再受限于"正则路径无函数体边界"。

### 跨切设计约束：生产规模 + LLM 上下文预算（2026-07-10 第二轮提醒）

> **这是一等约束，所有 Feature 都必须满足，不可事后补。**

1. **生产规模** — 实际扫描过 684 个 C 源文件的生产仓库。Tree-sitter 索引 + CFG 必须按此规模设计：
   - 索引按文件流式（已是），CFG 按函数构建（per-function，规模可控）。
   - index.json 体积必须受控：684 文件 + CFG 约 13MB+，**不可全量加载给 LLM**。CFG/信号按需查询或分片序列化（ADR-104）。
   - 索引时延：CFG 构建增量成本必须 O(函数数)，不引入全程序分析。

2. **LLM 上下文预算** — 绝不一股脑把海量信号/index 喂给 LLM 一起跑。检测能力会失真，LLM 面对一堆信息会不知所措。**这正是 v0.18.0 生产 1358 信号→0 findings（batch-suppression）的根因。**
   - 工作分区：按 signal/function/file 切分调查任务，每分区有界 token 预算，BATCH_SIZE 上限。
   - 每条 signal 的调查上下文 = 该 signal + 其 CFG 切片 + 调用图邻域（1-2 跳）+ 源码窗口（N 行）+ 相关 rule，**由引擎组装**，不超预算。
   - 强制层校验：无调查上下文超预算、信号按有界批处理、覆盖下限按批核算。

**F8 的结构性修复**：覆盖下限（Pillar A）只是兜底；真正的结构性修复是**上下文预算分区**（FEATURE-006）——让 LLM 永远只面对有界、相关的上下文，从根因消除 batch-suppression。

---

## 2. 问题陈述

2026-07-10 深度检视发现 **14 条致命/严重问题**（见检视报告），横跨 7 个主题。**5 个对抗性 agent 彼此不知对方结论，却独立收敛到同一根因**——这是结论可信度的强信号。

**根因：强制力倒置。** 硬保证全住在 LLM 可选择性忽略的 Markdown 里（"不可跳过"/"阻塞门"/"禁止"），唯一编译层 chokepoint（`record-finding.py` / `render-report.py` / `indexer`）只强制结构不变量、从不强制语义正确性；叠加一套从不把检测器输出与 ground truth 比对的验证体系，系统**没有能发现功能回归的反馈回路**。

后果：历史教训（batch-suppression 1358→0、answer-card bypass）反复"复发"——它们从未被结构性修复，只是被重新描述成更多 Markdown 文字。这直接破坏北极星的两根支柱：
- **SAST recall 对等被破坏**：F5/F6 索引器跨平台构建失明、F3/F8 LLM 可抑制已发现的信号
- **"超越 SAST"不可证明**：F4 验证剧场，无 recall/precision 度量

---

## 3. 根因分析（5-Why）

| 层 | 问 | 答 |
|----|----|----|
| 1 | 为何历史教训复发？ | 修复方式是加更多 Markdown 协议文字 |
| 2 | 为何加 Markdown 不生效？ | LLM 可选择性忽略文本，无运行时强制 |
| 3 | 为何无运行时强制？ | 唯一编译 chokepoint 只校验结构（字段非空），不校验语义（Q-matrix 一致性、信号覆盖率、anchor 真实性）|
| 4 | 为何没发现这个问题？ | 验证体系从不把检测器输出与 ground truth 比对（循环验证/伪造 finding）|
| 5 | 为何验证体系如此？ | 项目把"AI 自评"当成了"系统验证"，混淆了 LLM 自我汇报与引擎强制 |

---

## 4. Feature 分解

| # | Feature | 修复的致命项 | 优先 | 设计状态 |
|---|---------|------------|------|---------|
| 1 | **Structural Enforcement Layer + Verification Oracle**（Pillar A+B）| F1,F2,F3,F4,F8,F11,F12,F13 | P0 | ✅ 四环就绪 |
| 2 | **Tree-sitter Primary + CFG Construction**（Pillar 0）| F5,F6 + 架构升级 | P0 | ✅ 四环 + 实现启动 |
| 6 | **Context-Budget Partitioning**（F8 结构性修复）| F8 根因 + 规模约束 | P0 | Spec 纲要（本文 §7）|
| 3 | Rule Q-Matrix Normalization | F7,F14 | P1 | Spec 纲要（本文 §7）|
| 4 | Finding Identity v2 | F9 | P1 | Spec 纲要（本文 §7）|
| 5 | Protocol Single-Source & Drift Elimination | F10 | P1 | Spec 纲要（本文 §7）|

FEATURE-001 是架构脊柱：**Pillar A 强制层**（把语义不变量下沉到编译 chokepoint）+ **Pillar B 验证回路**（ground-truth oracle 闭合反馈）。附其完整设计四环。FEATURE-002..005 在 §7 给出 Spec 纲要，待 FEATURE-001 落地后展开四环。

---

## 5. 里程碑

| 里程碑 | 内容 | 证明 |
|--------|------|------|
| M0 | 设计四环就绪（本提交） | 本 Epic + FEATURE-001 四件套 |
| M1 | FEATURE-001 Pillar A（强制层）| `verification-gate.py` 接入 `record-finding.py`，CI gate 修复，信号覆盖下限生效 |
| M2 | FEATURE-001 Pillar B（验证回路）| ground-truth oracle 接入 e2e，杀 `verify-lang-pipeline.sh` 伪造 |
| M3 | FEATURE-002 索引器等价 | 双解析器等价测试 + EndLine/S3/Go-sink 修复 |
| M4 | FEATURE-003..005 规则/身份/协议 | Q-matrix 60 规则统一、identity v2、命令单源 |
| M5 | 回归验证 | 生产项目 recall 度量 > EPIC-009 基线；0 finding 不再 = PASSED |

---

## 6. 成功标准（可结构证明）

| 指标 | 当前 | 目标 | 证明方式 |
|------|------|------|---------|
| 0 finding 是否可能 PASSED | 是（100/100）| 否（信号覆盖下限拦截）| `verification-gate.py` 拒绝低覆盖扫描 |
| CI Critical 是否能绕过 | 能（exit 0 + severity 绕过）| 不能（exit 1 + 枚举强校验）| `render-report.py --ci` 真退出码 |
| recall 是否可度量 | 否（无 ground truth 比对）| 是（oracle 输出 recall/precision）| `expected-results.json` diff |
| 双解析器是否等价 | 否（跨平台失明）| 是（等价测试守卫）| dual-parser equivalence test |
| Q-matrix 极性是否正确 | 否（判决反转）| 是（60 规则统一）| rule Q-matrix audit |
| Finding 身份是否稳定 | 否（含行号，漂移即坏）| 是（函数符号+代码哈希）| delta 重命名不噪声 |
| 命令是否单源 | 否（三份发散+部署第四份过时）| 是（单源生成+一致性校验）| cross-platform consistency check 真执行 |

---

## 7. 后续 Feature Spec 纲要

### FEATURE-002: Tree-sitter Primary + CFG Construction（F5, F6 + 架构升级）★
> 升级（2026-07-10）：从"修双解析器等价"升级为"Tree-sitter 纯 Go 主干 + CFG 构建"。这是"打败 AST"与"CFG 不可忽视"两大用户指令的落点，与 FEATURE-001 并列 P0 双脊柱。完整四环见该 Feature 包。

- **问题**：正则回退路径 `EndLine==StartLine` 致调用图/alloc-free/S8-S10 系统性失效；S3 `Declarations` 从未填充致 prescreener 死代码（CGO 测试已红）；正则路径缺 Go 专属 sink；**当前架构完全无 CFG/DFG（AGENTS.md 能力边界显式标注 ❌）**，使可达性/必经路径分析不可能，LLM 只能空想控制流。
- **方案**：
  - (a) **迁移纯 Go Tree-sitter**：用 `github.com/tree-sitter/go-tree-sitter`（v0.23+，无 CGO）+ 纯 Go 语法库替换当前 CGO 绑定；**删除 `parser_re.go` 正则回退**，全平台单解析器路径，从根因消灭 F5。CGO 不再是构建前提，跨平台二进制与 darwin-arm64 行为一致。
  - (b) **CFG 构建**：新增 `internal/indexer/cfg.go`，基于 CST 按函数构建控制流图（基本块 + 控制边：if/else/for/while/switch/try/return/break/continue/throw）。产出 `cfg` 字段加入 `AnalysisContext`。
  - (c) **可达性/必经性 API**：提供 `IsReachable(from, to)`、`Dominates(check, use)` 查询，供检测器与 AI Investigator 调用——例如"NULL 检查是否支配解引用点"成为引擎事实而非 LLM 猜测。
  - (d) 填充 S3 Declarations 并接通 prescreener（或随正则回退一并废弃，转为 Tree-sitter 单路径的确定性安全标签）。
  - (e) `dual_parser_equivalence_test.go` 在迁移完成后转为 `parser_regression_test.go`（单解析器，守卫不回归）。
- **不做什么**：本 Feature 不做完整 DFG/污点传播（留待后续 Feature，依赖 CFG 先落地）；不改检测器语义（CFG 作为新证据源接入，由 FEATURE-003 Q-matrix 消费）。
- **为何是 P0**：无 CFG，"降低误报"与"结构化 recall"都缺地基；正则回退不除，"打败 AST"是空话。这是 Pillar 0 的全部。

### FEATURE-003: Rule Q-Matrix Normalization（F7, F14）
- **问题**：Q1/Q2 极性与"三绿灯/三红灯"协议矛盾致判决反转；60 规则仅 cpp 15 条有 Q-matrix，其余 45 条无定义无 fallback；null_dereference 对 assert 自相矛盾；cgo_memory EXCLUDE 过度抑制 UAF；Python 规则深度仅 cpp 1/5。
- **方案**：(a) 统一 Q-matrix 语义：Q1=缺陷真实性、Q2=可利用性、Q3=缓解存在性，三问 Yes/No 极性一致化，重写判定矩阵；(b) 定义无 Q-matrix 规则的 fallback（强制 Investigator 补齐三问）；(c) 60 规则全量部署 Q-matrix；(d) 修 assert 矛盾与 cgo EXCLUDE；(e) Python 规则补判定矩阵与多行正则。

### FEATURE-004: Finding Identity v2（F9）
- **问题**：fingerprint/delta key 含行号，行号漂移破坏 delta 与 SARIF tracking；同行同类多漏洞被合并丢弃；"最高严重度合并"协议从未实现。
- **方案**：身份键改为 `sha(canonical_anchor:detector:cwe)`，`canonical_anchor = function_symbol + normalized_code_hash`（归一化去空白/去行号）；同 anchor 多 finding 按 max-severity 合并；delta 基于新键。

### FEATURE-005: Protocol Single-Source & Drift Elimination（F10, F1, F12, F13, F11）
- **问题**：三份 secguard.md 发散 + 部署副本第四种过时；claude 副本 Steps 4-8 截断；report.md §3 渲染 bug；ci-check §6 死代码；diff_parser.go 死代码却文档化。
- **方案**：(a) 命令模板单源化（一份 canonical + 平台适配层），构建期生成三平台副本；(b) 修 `ci-check.sh:168` 的 `exit $ERRORS` 位置使 §6 真执行；(c) 修 `render-report.py:424-432` detail block 入循环；(d) `render-report.py --ci` 真退出码（与 FEATURE-001 Pillar A 共担）；(e) diff_parser.go：要么接入 CLI，要么删除文档。
- **进度（2026-07-10）**：F12 渲染 bug 已修（detail block 入循环）；F13 ci-check §6 已修（exit 移到末尾）；F2 CI exit code 已修（与 FEATURE-001 共担）；F1 命令截断、F10 单源、F11 diff 接入待办。

### FEATURE-006: Context-Budget Partitioning（F8 结构性修复 + 规模约束）★
> 2026-07-10 第二轮提醒落点。F8 覆盖下限（FEATURE-001）只是兜底；本 Feature 是 batch-suppression 的**结构性治本**——让 LLM 永远只面对有界、相关的上下文。

- **问题**：v0.18.0 生产 1358 信号→0 findings 的根因是 LLM 被海量信息淹没（batch-suppression）。当前 dispatch 把全量 signals/index 喂给 LLM，LLM 面对一堆信息不知所措，检测能力失真。生产规模 684+ C 文件使该问题加剧。
- **方案**：
  - (a) **信号分区调度**：Dispatcher 按 signal 切分调查任务，BATCH_SIZE 上限（如 ≤20 signal/批），每批独立调查，绝不全量。
  - (b) **有界调查上下文**：每条 signal 的上下文由引擎组装 = signal + CFG 切片（该函数 + 支配/可达相关块）+ 调用图邻域（1-2 跳）+ 源码窗口（±N 行）+ 相关 rule.md，token 预算硬上限（如 ≤8K tokens/signal）。
  - (c) **index 分片查询**：index.json 不可全量加载给 LLM；提供按 file/function/signal 的查询接口（或分片 manifest），LLM 按需取相关切片。
  - (d) **预算强制**：强制层（FEATURE-001 gate）校验每批调查上下文不超预算、信号按有界批处理、覆盖下限按批核算（已处理 signal / 总 signal）。
  - (e) **CFG 按需切片**：CFG 不全量序列化进喂给 LLM 的上下文；调查某 signal 时只取其所在函数的 CFG + 支配/可达子图。
- **不做什么**：不做全程序 LLM 推理；不做无界批处理；不把 index.json 整体喂 LLM。
- **为何 P0**：无此 Feature，batch-suppression 在生产规模下必然复发，支柱 1（recall 对等）不可实现。这是"超越 SAST"在生产规模下成立的必要条件。

---

## 8. 风险与约束

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| verification-gate.py 过严，误杀合法 finding | 中 | 高 | gate 失败走"降级为需人工复核"而非直接丢弃，并写 audit log |
| ground-truth oracle 的 expected-results 本身有误 | 中 | 高 | expected-results 由独立人工标注 + 双人复核，且 oracle 报告 mismatch 时人工仲裁 |
| 双解析器等价测试 fixture 不代表真实分布 | 中 | 中 | fixture 取自 examples/ + 历史生产扫描样本，持续扩充 |
| 强制层增加扫描时延 | 低 | 中 | gate 仅做 O(1) 结构校验 + index.json 查表，不做 AST 重解析 |

## 9. 与既有 Epic 的关系

- **EPIC-009**：其 prescreener 在 EPIC-011 FEATURE-002 中被修复（接通 S3）或正式废弃。Epic 概述文件为空的问题一并补齐。
- **EPIC-010**：Investigation Engine 的 Hypothesis/Investigator/Judge 管线依赖 EPIC-011 的强制层才有意义——否则 Judge 仍是 LLM 自评。EPIC-011 是 EPIC-010 落地的前置条件，但独立成 Epic 以免污染其 Inception 状态。
