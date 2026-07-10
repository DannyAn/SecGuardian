# 统一调度协议 — Per-Rule Isolated Dispatch (EPIC-011 ADR-006)

> **状态**: ✅ Accepted (2026-07-10)
> **适用**: `/secguard`（及后续 `/secaudit`、`/secreview` 对齐）
> **平台**: Claude Code / OpenCode / Gemini CLI —— **三平台行为一致，差异隔离于调度原语**

> ⚠️ 本文件是 Investigation Pipeline 的**单一真理源**。三平台命令模板（`commands/{claude,opencode,gemini}/secguard.md`）**引用本文件**，不各自复制 pipeline 内容（避免 F10 漂移）。每平台只额外声明自己的**调度原语**（见 §5）。

---

## 1. 设计目标（回应用户三关切）

| 关切 | 本协议解法 |
|------|-----------|
| 一口气给所有 rule → LLM 不逐个跑、结果漂移 | **per-rule 隔离**：按 partition 计划逐 (rule,batch) 处理，LLM 每次只面对一条 rule + 其有界信号 |
| 海量信息淹没 | **有界 batch**（BATCH_SIZE，默认 20）+ 引擎预过滤 |
| 生产 30-skill 各跑任务 = 慢 | **引擎预过滤**：旧慢在每 skill 重扫全库；现引擎只解析一次，每 rule 任务只收其 `signal_source` 相关信号 |
| Claude vs OpenCode 调度差异踩坑 | **统一串行内联基线**：三平台同模式，差异仅"可选隔离增强"（Claude Agent） |

---

## 2. 统一调度契约（平台无关）

**基线模式：串行内联**（三平台一致）。可选增强：Claude 用 Agent 工具做真隔离（非必需）。

```
Step 2 索引就绪后:
  1. 引擎: partition-signals.py --index index.json --rules-dir <lang>/rules --batch-size 20
     → 产出 partition-plan.json: {rule: [batch1, batch2, ...]}   ← 平台无关产物
  2. for each (rule, batch) in partition-plan:        ← 串行，逐个
       a. 加载 rule.md（Read 工具）
       b. 对该 batch 的每个信号跑 Investigation Pipeline（§3 Steps 4-7）
       c. 命中 → record-finding.py 录入（anchor 强制）
       d. 未命中但需抑制 → 写 dismissed.json（带 reason）
  3. 引擎强制:
       - verification-gate.py --index index.json --scan-dir <scan>  → gate-audit.json
       - coverage-gate.py --index index.json --scan-dir <scan>       → BLOCKED 若 batch-suppression
  4. render-report.py --ci（读 gate-audit，confirmed 才计入 CI）
  5. verify-recall.py（informational recall/precision）
```

**关键：per-rule 纪律由引擎强制，不靠 LLM 自觉。** partition 计划给结构，coverage-gate 核算（partitioned signals vs findings+dismissed），漏跑 rule → signals 未 investigated → BLOCKED。

---

## 3. Investigation Pipeline（共享 Steps 4-8，三平台相同）

### Step 4: Hypothesis Generator `[不可跳过]`
- **产出**: `workers/<rule>/hypotheses.json`
- **输入**: partition 计划中该 rule 的 batch 信号 + index.json 上下文 + rule.md
- **动作**: 对 batch 中每个信号生成 3-5 假设（H1 最可能漏洞 / H2 上下文特定 / H3 缓解存在 / H4 替代类型 / H5 实际安全）
- **禁止**: 直接判定漏洞类型。Signal 是调查起点，非结论。

### Step 5: Investigator `[不可跳过]`
- **产出**: `workers/<rule>/evidence.json`
- **门禁**: hypotheses.json 存在且 ≥3 假设
- **动作**: 针对每假设收集三段式证据链（Source→Propagation→Sink），每项锚定 `file:line+function+variable`。**用引擎事实**：CFG `IsReachable`/`Dominates`、call_graph 邻域、源码窗口。

### Step 6: Counter Evidence (P2) `[强制性阻塞门]`
- **产出**: `workers/<rule>/counter_evidence.json`
- **门禁**: evidence.json 存在
- **动作**: 对每条假设尝试**推翻自己**——找缓解、找安全变体、找不可达。即使全部安全也必须产出（记录"为何安全"）。
- **阻塞**: counter_evidence.json 不存在 → **禁止** record-finding（verification-gate 强制）

### Step 7: Judge + Fact-Anchor Reflection `[不可跳过]`
- **产出**: `workers/<rule>/judge_verdict.json`
- **动作**: 读 evidence + counter_evidence（**不重新调查**），按 rule.md 的 Q-matrix 判决：
  - Q1 缺陷真实？Q2 可利用？Q3 缓解存在？（Q1/Q2 Yes=危险，Q3 Yes=安全）
  - 判决: CONFIRMED / SUPPRESS / suspected
- **锚定**: 判决必须引用证据行号 + Q-matrix 答案

### Step 8: Record Findings `[条件执行]`
- **门禁**: judge_verdict.json 存在且 verdict=CONFIRMED
- **动作**: `record-finding.py` 录入（anchor 校验 file:line 在 index + severity 规范化 + function 自动回填）
- **抑制项**: 写 `dismissed.json`（每条带 reason：counter-evidence 摘要）

---

## 4. 引擎强制链（平台无关，bash 调用）

| 阶段 | 工具 | 作用 |
|------|------|------|
| 分区 | `scripts/partition-signals.py` | per-rule 信号分组 + 有界 batch |
| 录入 | `scripts/record-finding.py` | anchor + severity + function 回填 |
| 验证 | `scripts/verification-gate.py` | gate-audit.json（confirmed/needs_review）|
| 覆盖 | `scripts/coverage-gate.py` | batch-suppression 拦截（BLOCKED）|
| 渲染 | `scripts/render-report.py --ci` | confirmed 才计入 CI，真退出码 |
| 度量 | `scripts/verify-recall.py` | recall/precision（informational）|

---

## 5. 平台调度原语（差异隔离于此）

三平台**基线相同**（§2 串行内联）。仅以下原语差异，各平台命令模板声明：

### Claude Code
- **基线**: 串行内联（同 §2），主上下文逐 (rule,batch) 处理。
- **可选增强**: 对 batch 用 `Agent` 工具启子代理（真上下文隔离），子代理跑 Steps 4-8 后返回 findings。**非必需**——引擎强制已保证纪律，Agent 仅提升隔离质量。并发不超过平台限制。
- 工具: `Read`（rule.md/源码）、`Bash`（引擎脚本）。

### OpenCode
- **基线**: 串行内联（同 §2）。**无后台任务**（TUI 约束），逐 (rule,batch) 串行执行。
- 工具: `read`/`bash`（平台等价物）。

### Gemini CLI
- **基线**: 串行内联（同 §2）。
- 格式: TOML 命令模板，逻辑同 §2-§3。

> **一致性保证**: 三平台都跑 §2 契约 + §3 pipeline + §4 强制链。差异仅 §5 调度原语。命令模板只声明原语 + 引用本协议，不复制 pipeline。

---

## 6. 与旧版的区别

| 维度 | 旧版 | 本协议 |
|------|------|--------|
| 调度 | 全 rule 一锅端 / 平台各异踩坑 | 统一串行内联 per-rule + 引擎强制 |
| 信号 | LLM 自行从源码找 | 引擎预过滤 partition 计划 |
| 纪律 | Markdown "不可跳过"（LLM 可忽略）| 引擎强制（coverage/verification-gate）|
| 平台 | 各拷一份 pipeline（漂移）| 单一真理源（本文件）+ 薄平台适配 |
