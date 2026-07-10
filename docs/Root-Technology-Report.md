# SecGuardian 核心根技术报告

> **目的**：书面、诚实地记录 SecGuardian 每个命令背后的**根检测技术**，使人类能够：
> 1. 知道"背后用什么根技术"——不再黑箱，能帮上力
> 2. 与他司 SAST 的问题检出能力做横向对比
> 3. 理解"我们检出超过他们"是**架构与算法**超过，而非营销话术
>
> **诚实原则**：本报告区分「已实现」「进行中」「规划中」「已知缺口」。不重蹈旧版覆辙——旧版扫 examples"检出问题"实为读注释的假框架，生产零检出。本报告只写真实存在的能力。
>
> **版本**：v0.19.0-dev（EPIC-011 重构进行中） · **日期**：2026-07-10

---

## 一、定位：AI 辅助下的超越 SAST

SecGuardian **不是纯 SAST，也不是纯 LLM**。它是两层协作：

```
引擎层（确定性，保证 recall 下限）  +  AI 层（语义，提供超越 SAST 的差异化）
   Tree-sitter CST + CFG + 信号矩阵         LLM 在引擎事实之上做语义判断
   ↓ recall 对等：SAST 能检的都检            ↓ 超越 SAST：SAST 检不到的也能检
   强制层（不可绕过）  →  验证层（可证明 recall/precision）
```

**两根支柱**（都必须可结构证明，非叙事声称）：
1. **SAST recall 对等** — 引擎找到的结构信号是 recall 下限，LLM 不可抑制
2. **LLM 语义差异化** — LLM 在 CFG/可达性等引擎事实之上做 SAST 做不到的语义/跨函数推理

---

## 二、根技术栈总览

### 引擎层（Go 编译原生代码，`internal/`）

| 根技术 | 实现 | 状态 | 说明 |
|--------|------|------|------|
| **Tree-sitter CST 解析** | `parser_ts.go`（CGO）| ✅ 已实现 | C/C++/Go/Java/Python 真实 AST；鲁棒解析（容错不完整代码）、统一多语言、全位置。这是"打败 AST"的基础——比传统正则/AST SAST 更鲁棒、更统一 |
| 正则回退解析 | `parser_re.go`（!CGO）| ⚠️ 已知缺口（F5）| 跨平台构建用；`EndLine==StartLine` 致调用图/信号系统性失效。**规划**：zig cc 交叉编译使 tree-sitter 全平台唯一，删除正则回退 |
| **符号表** | `indexer.ExtractSymbols` | ✅ | 函数/变量/类型 + 文件+行号范围 + 可见性 + OOP receiver 类型推断 |
| **调用图** | `BuildCallGraphV2`（库 sink 调用点）+ V1（文本近似回退）| ✅ 部分 | V2 基于已知库函数 sink；V1 文本近似有短名假边。**规划**：CFG 落地后做精确过程间可达性 |
| **Alloc/Free 配对** | `MatchAllocFree` | ✅ 文本近似 | 同函数 scope 内 malloc/free 配对；不追踪具体变量（无 DFG）|
| **锁使用记录** | `BuildLockGraph` | ⚠️ 弱 | 仅记录 lock/unlock 行号，不配对、不过滤注释。**已知缺口**待修 |
| **信号矩阵 S1-S12** | `parser/types.go` + 提取器 | ✅ 已实现 | S1 CallSites / S2 StringLiterals / **S3 Declarations**（F6 修复后活）/ S4 ValueConstants / S5 Imports（F6 修复）/ S6 ConfigPatterns / S7 ControlFlowSignals / S8 PointerValidations / S9 StructInits / S10 VariableWrites / **S11 SuspiciousExpression**（assignment_in_condition/operator_precedence/signed_unsigned_compare/suspicious_boolean）/ **S12 TaintFlow**（Source→Sink 污点传播，M2）|
| **CFG 控制流图**（EPIC-011）| `parser/cfg.go` | ✅ 已实现（v1）| per-function 基本块 + 控制边（if/for/while/return/break/continue/throw）+ `IsReachable` + `Dominates`（迭代支配树）。switch/try 保守处理标 `Incomplete` |
| **Prescreener** | `indexer.Prescreener` | ✅ 已修复（F6）| 确定性 safe-variant 过滤（strcpy_s/memcpy_s/snprintf 等）；F6 修复前是死代码（SafeCount 恒 0），现已生效（cpp-vuln-demo 实测过滤 8.6%）|

### AI 层（Markdown 知识 + LLM 推理）

| 根技术 | 实现 | 状态 | 说明 |
|--------|------|------|------|
| **Investigation Pipeline** | `commands/*/secguard.md` Steps 4-8 | ⚠️ 部分实现 | Signal→Hypothesis→Investigator→Counter Evidence→Judge（Fact-Anchor Q1-Q2-Q3）。**F1**：Claude 主平台命令文件曾截断缺 Steps 4-8（待恢复）；**F3**：当前步骤是 LLM 自我汇报，引擎未强制（verification-gate.py 规划中）|
| **检测器知识库** | `skills/secguard/{lang}/rules/` | ✅ 60 检测器 | cpp 15 / java 10 / python 11 / go 10 / js 13。每条含 danger/safe/FP 模式 + Q-matrix（cpp 全覆盖，**F7**：其余 45 条待补 + 极性矛盾待修）|
| **LLM 语义判断** | LLM 在引擎事实之上 | ✅ | LLM 消费 CFG 可达性/支配性、信号上下文、源码窗口做语义判断，而非空想 |
| **上下文预算分区**（EPIC-011 FEATURE-006）| 规划中 | 🔲 规划 | 信号分区调度（BATCH_SIZE 上限）+ 有界调查上下文。**这是根治 batch-suppression（生产 1358→0）的关键**，尚未实现 |

### 强制层（EPIC-011 Pillar A，编译 chokepoint）

| 根技术 | 实现 | 状态 | 说明 |
|--------|------|------|------|
| **Anchor 交叉校验** | `record-finding.py` | ✅ | finding 的 file+line 必须在 index.json 中存在；**新**：function 从 index 自动回填（修 function=N/A）|
| **severity 规范化** | `record-finding.py` + `render-report.py` | ✅ 已修复（F2）| 枚举强校验 + 别名映射，堵大小写/枚举绕过 CI 门禁 |
| **CI 门禁真退出码** | `render-report.py --ci` | ✅ 已修复（F2）| Critical→进程 exit 1（旧版只 print，门禁装饰性）|
| **verification-gate.py**（per-finding 语义门）| `scripts/verification-gate.py` | ✅ 已实现（TASK-004/005）| post-scan 审计：anchor+severity 校验 + gate_signature；render-report 读 gate-audit.json，**confirmed 才计入 CI，needs_review 排除**——堵死绕过 recorder 写假 finding 的旁路（F3 输出侧根治）。Q-matrix/工件校验留 stub（待 FEATURE-003）|
| **coverage-gate.py**（信号覆盖门禁）| `scripts/coverage-gate.py` | ✅ 已实现（TASK-007）| **F8 结构性修复**：scan 级 `(findings+dismissed_with_reason)/signals` 覆盖率；signals>0 且 0 investigated 且无 dismissed → BLOCKED + exit 1。根治 batch-suppression（生产 1358→0）。e2e §15 验证 |

### 验证层（EPIC-011 Pillar B，可证明）

| 根技术 | 实现 | 状态 | 说明 |
|--------|------|------|------|
| **Ground-truth oracle** | `verify-recall.py` | ✅ v1 | 读 expected-results.json 与实际 finding，按 (file,line/function) 匹配，输出 recall/precision/F1。self-test 确定性数学绿；已接入 e2e §14 |
| **循环验证消除** | 替换 `verify-lang-pipeline.sh` 伪造 | 🔲 规划 | 旧验证伪造 finding 冒充"全管线通过"（F4）；oracle 替代中 |
| **ground truth 补全** | 人工标注 | 🔲 规划 | 当前 expected-results 不完整（未覆盖所有漏洞文件），precision 虚低。需补全才能可信度量 |

### 输出层

| 根技术 | 实现 | 状态 |
|--------|------|------|
| Findings schema v5.0（4 段：location/evidence/impact/fix）| `findings-schema.json` | ✅ |
| SARIF 2.1.0 | `render-report.py` | ✅ |
| 评分（指数衰减）+ 等级 | `render-report.py` | ✅（**F-indexer**：exec/dashboard 公式不一致待修）|
| CI 门禁 | `render-report.py --ci` | ✅ 已修复（F2）|
| Delta 增量对比 | `render-report.py` | ⚠️ F9：fingerprint 含行号，行号漂移破坏 delta，待 v2 |

---

## 三、各命令的根技术映射

### `/secguard` — 安全加固检视（全量扫描）
```
源码 → Tree-sitter CST → 符号表 + 调用图 + Alloc/Free + 锁图 + 信号矩阵 S1-S11 + CFG
    → Prescreener（确定性 safe-variant 过滤，降低噪声）
    → partition-signals.py（per-rule 信号分组 + 有界 batch，平台无关产物）  ← ADR-006
    → per (rule, batch) 一个隔离 LLM 任务（Claude=Agent 子代理 / OpenCode=串行）
        ├─ 引擎事实：CFG IsReachable/Dominates、信号上下文、源码窗口
        └─ LLM 语义判断：每任务只面对一条 rule + 其预过滤信号，不淹没
    → 强制层（record-finding anchor + verification-gate 签名 + coverage-gate 覆盖下限）
    → findings → render-report（confirmed 才计入 CI；report.md + SARIF）
    → oracle（recall/precision 度量）
```
**根技术**：Tree-sitter CST + CFG + 信号矩阵 S1-S11 + Prescreener + **per-rule 隔离调度（ADR-006）** + LLM Investigation + 强制层（coverage/verification-gate）+ oracle

> **调度架构（ADR-006，超越 SAST 的关键）**：per-rule 隔离任务 + 引擎预过滤。传统 SAST 用刚性规则全扫；纯 AI SAST 把所有 rule 一股脑喂 LLM（不逐个跑、结果漂移）。SecGuardian 引擎预过滤使每 rule 任务只收其相关信号——per-rule 隔离既给质量（LLM 聚焦一条 rule）又可负担（不重扫全库，根治旧 30-skill 慢）。这是"超越 SAST"的调度层差异化。

### `/secaudit` — 发布安全审计（深度）
```
源码 → 索引器（同上）→ 13 审计域（OWASP ASVS 映射）→ 每域 LLM 审计 → findings → 报告
```
**根技术**：Tree-sitter 索引 + OWASP ASVS 域规则 + LLM 深度审计 + 4 段质量门禁

### `/secreview` — PR 安全审查
```
git diff → 索引器（变更文件）→ 5 语言 review 规则 → 每文件 LLM review → findings
```
**根技术**：Tree-sitter 索引 + PR diff 范围（**F11**：diff_parser 未接入 CLI，当前全量）+ 5 语言 review 规则
**已知缺口**：增量扫描未真生效（diff_parser.go 死代码）

### `/secfix` — 修复
```
findings → LLM 生成 unified diff patch
```
**根技术**：findings → LLM 补丁生成

---

## 四、与他司 SAST 的根技术对比

| 根技术维度 | 传统 SAST（如 Coverity/Fortify/CodeQL）| 他司 AI SAST | **SecGuardian** |
|-----------|--------------------------------------|-------------|----------------|
| 解析 | AST（编译器前端或正则）| 多为正则/AST | **Tree-sitter CST**（鲁棒、容错、统一多语言）✅ 领先 |
| 控制流 | CFG ✅ | 多无 | CFG v1 ✅（刚落地，DFG 待补）|
| 数据流/污点 | DFG + 污点传播 ✅ | 多无 | **✅ intra-procedural v1**（S12 TaintFlow：return/arg-tainted 源 + 赋值传播 + sink 检测；cpp-vuln-demo 实测 10 真实流。inter-procedural/路径敏感/别名 = 后续）|
| 规则模型 | 刚性规则 + 查询语言（CodeQL）| AI 提示 | **引擎事实 + LLM 语义**（混合）✅ 差异化 |
| 误报控制 | 数据流约束（但仍高 FP）| LLM 判断（不可控）| **CFG 支配性 + Q-matrix + Counter Evidence**（规划强制）|
| 召回保证 | 引擎保证（但受规则覆盖限制）| LLM 自由（不可保证）| **引擎 recall 下限 + prescreener + [规划] 覆盖门禁**|
| 上下文管理 | 全程序分析（慢但全）| 一股脑喂 LLM（失真）| **[规划] 上下文预算分区**——根治 batch-suppression |
| 可证明性 | 规则集 + 误报率 | 黑箱 | **Ground-truth oracle**（recall/precision 可度量）✅ 领先 |
| 语义意图 | 无 | LLM（但无引擎事实）| **LLM 在 CFG/信号事实之上**✅ 差异化 |
| 跨函数推理 | 数据流可达 | LLM（不可靠）| CFG + 调用图（进行中）|

### 我们领先在哪（可书面主张）
1. **Tree-sitter CST > AST**：鲁棒解析容错不完整代码、统一 5 语言、全位置——比正则/AST SAST 更稳
2. **引擎 recall 下限 + LLM 语义差异化**：传统 SAST 有 recall 无语义；纯 AI SAST 有语义无 recall 保证。我们两者兼有
3. **Ground-truth oracle**：recall/precision 可度量、可对比——他司多为黑箱或自报
4. **CFG 事实喂 LLM**：LLM 不再空想控制流，误报结构性下降

### 我们目前落后/待补（诚实）
1. **DFG/污点传播**——intra-procedural v1 已落地（S12 TaintFlow，cpp-vuln-demo 实测 10 真实流）；**inter-procedural（跨函数）/路径敏感/别名分析**仍待补（后续 M2 增量）
2. **CFG/强制层/分区尚在进行中**——架构已定，实现未全
3. **双解析器非等价**（F5）——跨平台构建用正则回退，待 zig cc 迁移
4. **JS 用正则**（非 tree-sitter）
5. **ground truth 不完整**——oracle precision 暂不可信

---

## 五、可信度证据（非声称，可复现）

| 主张 | 证据 | 复现命令 |
|------|------|---------|
| Tree-sitter 真解析 5 语言 | 索引器实测 | `secguardian-index --path examples/cpp-vuln-demo/src --lang c` |
| CFG 真构建 + 支配查询 | 单测 + 实测 110 CFGs | `go test -tags cgo -run TestCFG ./parser/` |
| Prescreener 真过滤 | SafeCount 0→8 | 索引 cpp-vuln-demo 看 "Prescreener: 8 safe filtered" |
| CI 门禁真退出 | e2e §6 断言进程 exit 1 | `bash scripts/e2e-verify.sh` |
| 覆盖门禁真拦截 batch-suppression | e2e §15 断言 BLOCKED exit 1 | `python3 scripts/coverage-gate.py --self-test` |
| Oracle 真度量 | recall/precision 输出 | `python3 scripts/verify-recall.py --self-test` |
| 无验证伪造 | oracle 替代 verify-lang-pipeline 伪造 | e2e §14 |

---

## 六、与旧版的根本区别（回应"框架全是假的"）

| 维度 | 旧版（v0.18 及前）| 本版（EPIC-011 重构）|
|------|------------------|---------------------|
| examples"检出" | 读注释/答案卡的假检出 | 真索引 + 真信号（CFG/S1-S10）|
| 生产检出 | 0 findings（batch-suppression）| 引擎 recall 下限 + [规划] 分区根治 |
| 验证 | 伪造"全管线通过" | ground-truth oracle 真度量 |
| CI 门禁 | 装饰性（不 exit 1）| 真退出码 |
| 根技术透明 | 黑箱（不知背后用什么）| **本报告**——每项根技术书面化 |
| 强制力 | 全在 Markdown（LLM 可忽略）| 下沉到编译 chokepoint（进行中）|

---

## 七、路线图（朝超越 SAST 演进）

| 里程碑 | 内容 | 状态 |
|--------|------|------|
| M0 | 设计四环 + CFG 主干 + prescreener 修复 + CI/oracle | ✅ 本版 |
| M1 | verification-gate.py（语义门 + 覆盖下限）| 🔲 进行中 |
| M2 | DFG/污点传播（基于 CFG）| 🔄 intra-procedural v1 完成；inter-procedural/路径敏感后续 |
| M3 | 上下文预算分区（FEATURE-006，根治 batch-suppression）| 🔲 规划 |
| M4 | zig cc 全平台 tree-sitter（F5 根治）| 🔲 待环境 |
| M5 | Q-matrix 60 规则统一 + 极性修复（F7）| 🔲 规划 |
| M6 | ground truth 补全 + oracle 硬门禁 | 🔲 规划 |

> **结论**：架构正朝"非 SAST 但超越传统 SAST 检出能力"演进。引擎层（Tree-sitter+CFG+信号）保证 recall 下限，AI 层在引擎事实之上做语义差异化，强制层与验证层让能力可强制、可证明。已落地的部分（CFG/prescreener/CI/oracle）均有可复现证据；进行中与规划中的部分诚实标注。
